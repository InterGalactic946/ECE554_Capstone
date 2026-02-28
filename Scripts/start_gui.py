import os
import re
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
from pathlib import Path

import config
from generate_starter import ensure_extension, render_design_template

"""
This script provides a hierarchical block-diagram GUI for starter RTL generation.

The GUI supports:
- Top-level module as an outer scope rectangle.
- Internal block instances drawn within the current scope.
- Interactive arrow-based connections between blocks.
- Direction inferred from arrow direction (source -> destination).
- Bus width specified per connection.
- Scope navigation:
    - Enter child scope by opening a selected block.
    - Move up scope to parent module.

Code generation behavior:
- One module file per scope/module in designs/.
- Connections to pseudo-block "TOP" become module ports.
- Block-to-block connections become internal signals.
- Internal signal type defaults to logic but can be set to wire/reg.
- Missing child modules can be generated as starter files automatically.
"""


# ============================================================================
# Data Model
# ============================================================================
class ScopeNode:
    """
    Represents one module scope in the hierarchical diagram tree.

    Attributes:
        module_name (str): Module name represented by this scope.
        parent (ScopeNode | None): Parent scope node.
        children (dict[str, ScopeNode]): Child scopes keyed by child instance name.
        blocks (list[dict]): Block instances in this scope.
        connections (list[dict]): Directed connections in this scope.
    """

    def __init__(self, module_name, parent=None):
        self.module_name = module_name
        self.parent = parent
        self.children = {}
        self.blocks = []
        self.connections = []


# ============================================================================
# GUI Application
# ============================================================================
class DiagramApp:
    """
    Main Tkinter application for hierarchical block-diagram editing and generation.
    """

    def __init__(self, root):
        self.root = root
        self.root.title("SystemVerilog Hierarchical Block Diagram Generator")
        self.root.geometry("1400x860")

        # Runtime state.
        self.project_dirs = config.get_top_level_dirs()
        self.root_scope = None
        self.current_scope = None
        self.selected_block_id = None
        self.connect_source_block_id = None
        self.connection_drag = {"active": False, "src_endpoint": None, "preview_line": None}
        self.block_item_map = {}
        self.edge_item_map = []
        self.drag_state = {"block_id": None, "last_x": 0, "last_y": 0}

        self._build_layout()
        self._initialize_defaults()

    # ------------------------------------------------------------------------
    # Layout and Initialization
    # ------------------------------------------------------------------------
    def _build_layout(self):
        """
        Build main window layout with controls and drawing canvas.
        """
        main_frame = ttk.Frame(self.root, padding=8)
        main_frame.pack(fill=tk.BOTH, expand=True)

        # Left control panel.
        control_frame = ttk.Frame(main_frame, width=420)
        control_frame.pack(side=tk.LEFT, fill=tk.Y)

        # Right diagram panel.
        diagram_frame = ttk.Frame(main_frame)
        diagram_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        self._build_controls(control_frame)
        self._build_canvas(diagram_frame)

    def _build_controls(self, parent):
        """
        Build left-side controls.
        """
        # Project and generation configuration group.
        cfg_group = ttk.LabelFrame(parent, text="Project Settings", padding=8)
        cfg_group.pack(fill=tk.X, pady=4)

        ttk.Label(cfg_group, text="Project Directory").pack(anchor=tk.W)
        self.project_var = tk.StringVar(value=os.path.basename(self.project_dirs[0]) if self.project_dirs else "")
        self.project_combo = ttk.Combobox(
            cfg_group,
            textvariable=self.project_var,
            values=[os.path.basename(path) for path in self.project_dirs],
            state="readonly"
        )
        self.project_combo.pack(fill=tk.X, pady=2)

        ttk.Label(cfg_group, text="Top Module Name").pack(anchor=tk.W)
        self.top_module_var = tk.StringVar(value="TopDesign")
        ttk.Entry(cfg_group, textvariable=self.top_module_var).pack(fill=tk.X, pady=2)

        ttk.Label(cfg_group, text="Top File Name").pack(anchor=tk.W)
        self.top_file_var = tk.StringVar(value="TopDesign.v")
        ttk.Entry(cfg_group, textvariable=self.top_file_var).pack(fill=tk.X, pady=2)

        ttk.Label(cfg_group, text="Top Description").pack(anchor=tk.W)
        self.top_desc_var = tk.StringVar(value="implements the top-level datapath and control integration.")
        ttk.Entry(cfg_group, textvariable=self.top_desc_var).pack(fill=tk.X, pady=2)

        ttk.Label(cfg_group, text="Internal Signal Type").pack(anchor=tk.W)
        self.net_type_var = tk.StringVar(value="logic")
        ttk.Combobox(cfg_group, textvariable=self.net_type_var, values=["logic", "wire", "reg"], state="readonly").pack(fill=tk.X, pady=2)

        self.create_missing_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            cfg_group,
            text="Create missing child module starters",
            variable=self.create_missing_var
        ).pack(anchor=tk.W, pady=2)

        self.overwrite_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            cfg_group,
            text="Overwrite existing generated files",
            variable=self.overwrite_var
        ).pack(anchor=tk.W, pady=2)

        # Scope navigation group.
        scope_group = ttk.LabelFrame(parent, text="Scope Navigation", padding=8)
        scope_group.pack(fill=tk.X, pady=4)

        self.scope_path_var = tk.StringVar(value="")
        ttk.Label(scope_group, textvariable=self.scope_path_var).pack(anchor=tk.W, pady=2)

        nav_row = ttk.Frame(scope_group)
        nav_row.pack(fill=tk.X, pady=2)
        ttk.Button(nav_row, text="Up Scope", command=self.go_up_scope).pack(side=tk.LEFT, padx=2)
        ttk.Button(nav_row, text="Enter Selected Block", command=self.enter_selected_scope).pack(side=tk.LEFT, padx=2)
        ttk.Button(nav_row, text="Reset to Top", command=self.reset_to_top_scope).pack(side=tk.LEFT, padx=2)

        # Diagram edit group.
        edit_group = ttk.LabelFrame(parent, text="Diagram Editing", padding=8)
        edit_group.pack(fill=tk.X, pady=4)

        ttk.Label(edit_group, text="Instance Name").pack(anchor=tk.W)
        self.instance_var = tk.StringVar(value="u_block0")
        ttk.Entry(edit_group, textvariable=self.instance_var).pack(fill=tk.X, pady=2)

        ttk.Label(edit_group, text="Module Name").pack(anchor=tk.W)
        self.module_var = tk.StringVar(value="MyBlock")
        ttk.Entry(edit_group, textvariable=self.module_var).pack(fill=tk.X, pady=2)

        block_btn_row = ttk.Frame(edit_group)
        block_btn_row.pack(fill=tk.X, pady=2)
        ttk.Button(block_btn_row, text="Add Block", command=self.add_block).pack(side=tk.LEFT, padx=2)
        ttk.Button(block_btn_row, text="Delete Selected Block", command=self.delete_selected_block).pack(side=tk.LEFT, padx=2)

        conn_group = ttk.LabelFrame(parent, text="Connections", padding=8)
        conn_group.pack(fill=tk.X, pady=4)

        ttk.Label(conn_group, text="Drag to connect: Right-drag (or Shift+drag) from source block to destination block/TOP").pack(anchor=tk.W, pady=2)

        port_row = ttk.Frame(conn_group)
        port_row.pack(fill=tk.X, pady=2)
        ttk.Label(port_row, text="Src Port").pack(side=tk.LEFT, padx=2)
        self.conn_src_port_var = tk.StringVar(value="out")
        ttk.Entry(port_row, textvariable=self.conn_src_port_var, width=10).pack(side=tk.LEFT, padx=2)
        ttk.Label(port_row, text="Dst Port").pack(side=tk.LEFT, padx=2)
        self.conn_dst_port_var = tk.StringVar(value="in")
        ttk.Entry(port_row, textvariable=self.conn_dst_port_var, width=10).pack(side=tk.LEFT, padx=2)
        ttk.Label(port_row, text="Width").pack(side=tk.LEFT, padx=2)
        self.conn_width_var = tk.StringVar(value="")
        ttk.Entry(port_row, textvariable=self.conn_width_var, width=10).pack(side=tk.LEFT, padx=2)

        ttk.Button(conn_group, text="Start Connection (from selected)", command=self.begin_connection).pack(fill=tk.X, pady=2)
        ttk.Button(conn_group, text="Connect from TOP -> selected", command=self.connect_top_to_selected).pack(fill=tk.X, pady=2)
        ttk.Button(conn_group, text="Connect from selected -> TOP", command=self.connect_selected_to_top).pack(fill=tk.X, pady=2)
        ttk.Button(conn_group, text="Clear All Connections in Scope", command=self.clear_scope_connections).pack(fill=tk.X, pady=2)

        # Generation controls.
        gen_group = ttk.LabelFrame(parent, text="Generation", padding=8)
        gen_group.pack(fill=tk.X, pady=4)
        ttk.Button(gen_group, text="Generate HDL From Diagram", command=self.generate_hdl).pack(fill=tk.X, pady=2)

        # Status output.
        status_group = ttk.LabelFrame(parent, text="Status", padding=8)
        status_group.pack(fill=tk.BOTH, expand=True, pady=4)
        self.status_text = tk.Text(status_group, height=18, wrap=tk.WORD)
        self.status_text.pack(fill=tk.BOTH, expand=True)

    def _build_canvas(self, parent):
        """
        Build canvas used for block diagram drawing and interaction.
        """
        self.canvas = tk.Canvas(parent, bg="#f7f7f7")
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # Mouse bindings for selection and drag.
        self.canvas.bind("<Button-1>", self.on_canvas_click)
        self.canvas.bind("<B1-Motion>", self.on_canvas_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_canvas_release)
        self.canvas.bind("<ButtonPress-3>", self.on_connection_drag_start)
        self.canvas.bind("<B3-Motion>", self.on_connection_drag_motion)
        self.canvas.bind("<ButtonRelease-3>", self.on_connection_drag_release)

        # Shift + left drag is also enabled for touchpad users.
        self.canvas.bind("<Shift-ButtonPress-1>", self.on_connection_drag_start)
        self.canvas.bind("<Shift-B1-Motion>", self.on_connection_drag_motion)
        self.canvas.bind("<Shift-ButtonRelease-1>", self.on_connection_drag_release)

    def _initialize_defaults(self):
        """
        Initialize root scope and initial rendering.
        """
        top_module = self._sanitize_identifier(self.top_module_var.get().strip() or "TopDesign")
        self.root_scope = ScopeNode(top_module)
        self.current_scope = self.root_scope
        self._update_scope_path_label()
        self.redraw_canvas()

    # ------------------------------------------------------------------------
    # Canvas Interaction
    # ------------------------------------------------------------------------
    def redraw_canvas(self):
        """
        Redraw the entire canvas for current scope.
        """
        self.canvas.delete("all")
        self.block_item_map.clear()
        self.edge_item_map.clear()

        # Draw outer scope rectangle.
        width = max(self.canvas.winfo_width(), 400)
        height = max(self.canvas.winfo_height(), 300)
        self.canvas.create_rectangle(20, 20, width - 20, height - 20, outline="#1f3b4d", width=2)
        self.canvas.create_text(40, 30, text=f"Scope: {self.current_scope.module_name}", anchor=tk.W, fill="#1f3b4d", font=("TkDefaultFont", 10, "bold"))

        # Draw pseudo TOP node for scope boundary connections.
        top_cx, top_cy = width // 2, 65
        self.canvas.create_oval(top_cx - 30, top_cy - 15, top_cx + 30, top_cy + 15, fill="#e9f5ff", outline="#1f3b4d", width=1)
        self.canvas.create_text(top_cx, top_cy, text="TOP", fill="#1f3b4d")

        # Draw blocks.
        for block in self.current_scope.blocks:
            x, y = block["x"], block["y"]
            rect_id = self.canvas.create_rectangle(x, y, x + 160, y + 70, fill="#ffffff", outline="#4a4a4a", width=2)
            text_id = self.canvas.create_text(x + 80, y + 22, text=block["instance"], font=("TkDefaultFont", 9, "bold"))
            mod_id = self.canvas.create_text(x + 80, y + 46, text=f"({block['module']})", fill="#333333")

            self.block_item_map[rect_id] = block
            self.block_item_map[text_id] = block
            self.block_item_map[mod_id] = block

            # Highlight selected block.
            if self.selected_block_id and block["id"] == self.selected_block_id:
                self.canvas.create_rectangle(x - 3, y - 3, x + 163, y + 73, outline="#0078d7", width=2)

        # Draw connections.
        for connection in self.current_scope.connections:
            self._draw_connection(connection, top_cx, top_cy)

        # Draw live preview line if user is currently drag-connecting.
        if self.connection_drag["active"] and self.connection_drag["preview_line"] is not None:
            self.canvas.tag_raise(self.connection_drag["preview_line"])

    def _draw_connection(self, connection, top_cx, top_cy):
        """
        Draw one connection arrow on canvas.
        """
        src_center = self._get_node_center(connection["src_block"], top_cx, top_cy)
        dst_center = self._get_node_center(connection["dst_block"], top_cx, top_cy)
        if not src_center or not dst_center:
            return

        arrow_id = self.canvas.create_line(
            src_center[0], src_center[1], dst_center[0], dst_center[1],
            arrow=tk.LAST, width=2, fill="#2f2f2f"
        )

        # Label includes width and signal name.
        mid_x = (src_center[0] + dst_center[0]) / 2
        mid_y = (src_center[1] + dst_center[1]) / 2
        label = f"{connection['signal']} [{connection['width']}]"
        label_id = self.canvas.create_text(mid_x, mid_y - 10, text=label, fill="#5a2b00")
        self.edge_item_map.append((arrow_id, label_id, connection))

    def _get_node_center(self, block_name, top_cx, top_cy):
        """
        Resolve center coordinates for block instance or TOP pseudo-node.
        """
        if block_name == "TOP":
            return top_cx, top_cy

        for block in self.current_scope.blocks:
            if block["instance"] == block_name:
                return block["x"] + 80, block["y"] + 35
        return None

    def on_canvas_click(self, event):
        """
        Handle canvas click for block selection and connection completion.
        """
        clicked_item = self.canvas.find_closest(event.x, event.y)
        if not clicked_item:
            return

        item_id = clicked_item[0]
        block = self.block_item_map.get(item_id)

        # If connection mode is active, second click finalizes connection.
        if self.connect_source_block_id:
            if block:
                self._finalize_connection_to_block(block["id"])
            else:
                # Click near TOP pseudo-node to connect to TOP.
                if self._is_click_on_top(event.x, event.y):
                    self._finalize_connection_to_top()
            return

        # Normal selection behavior.
        if block:
            self.selected_block_id = block["id"]
            self.drag_state["block_id"] = block["id"]
            self.drag_state["last_x"] = event.x
            self.drag_state["last_y"] = event.y
        else:
            self.selected_block_id = None
            self.drag_state["block_id"] = None

        self.redraw_canvas()

    def on_canvas_drag(self, event):
        """
        Handle drag motion for selected block.
        """
        block_id = self.drag_state["block_id"]
        if not block_id:
            return

        block = self._find_block_by_id(block_id)
        if not block:
            return

        dx = event.x - self.drag_state["last_x"]
        dy = event.y - self.drag_state["last_y"]
        block["x"] += dx
        block["y"] += dy
        self.drag_state["last_x"] = event.x
        self.drag_state["last_y"] = event.y
        self.redraw_canvas()

    def on_canvas_release(self, _event):
        """
        Handle mouse release after dragging.
        """
        self.drag_state["block_id"] = None

    def on_connection_drag_start(self, event):
        """
        Start interactive drag-to-connect mode from source endpoint.
        """
        src_endpoint = self._resolve_endpoint_from_xy(event.x, event.y)
        if not src_endpoint:
            return

        # Start connection drag state.
        self.connection_drag["active"] = True
        self.connection_drag["src_endpoint"] = src_endpoint

        src_xy = self._resolve_endpoint_center(src_endpoint)
        if not src_xy:
            self.connection_drag["active"] = False
            self.connection_drag["src_endpoint"] = None
            return

        # Create temporary preview arrow line.
        if self.connection_drag["preview_line"] is not None:
            self.canvas.delete(self.connection_drag["preview_line"])
        self.connection_drag["preview_line"] = self.canvas.create_line(
            src_xy[0], src_xy[1], event.x, event.y,
            arrow=tk.LAST, dash=(5, 3), width=2, fill="#0078d7"
        )

    def on_connection_drag_motion(self, event):
        """
        Update preview line while user drags to connect endpoints.
        """
        if not self.connection_drag["active"]:
            return

        src_endpoint = self.connection_drag["src_endpoint"]
        src_xy = self._resolve_endpoint_center(src_endpoint)
        if not src_xy:
            return

        if self.connection_drag["preview_line"] is not None:
            self.canvas.coords(self.connection_drag["preview_line"], src_xy[0], src_xy[1], event.x, event.y)

    def on_connection_drag_release(self, event):
        """
        Finalize drag-to-connect operation when user releases on destination endpoint.
        """
        if not self.connection_drag["active"]:
            return

        src_endpoint = self.connection_drag["src_endpoint"]
        dst_endpoint = self._resolve_endpoint_from_xy(event.x, event.y)

        # Remove preview line.
        if self.connection_drag["preview_line"] is not None:
            self.canvas.delete(self.connection_drag["preview_line"])

        # Reset drag state.
        self.connection_drag["active"] = False
        self.connection_drag["src_endpoint"] = None
        self.connection_drag["preview_line"] = None

        # Validate destination endpoint.
        if not src_endpoint or not dst_endpoint:
            self._log_status("Connection cancelled: destination endpoint not selected.")
            return
        if src_endpoint == dst_endpoint:
            self._log_status("Connection cancelled: source and destination are the same.")
            return

        # Create connection using current quick-entry defaults.
        self._create_connection_from_defaults(src_endpoint, dst_endpoint)

    def _is_click_on_top(self, x, y):
        """
        Check if click location is near pseudo TOP node.
        """
        width = max(self.canvas.winfo_width(), 400)
        top_cx, top_cy = width // 2, 65
        return (x - top_cx) ** 2 + (y - top_cy) ** 2 <= 35 ** 2

    def _resolve_endpoint_from_xy(self, x, y):
        """
        Resolve endpoint identifier ("TOP" or block instance) from canvas coordinates.
        """
        if self._is_click_on_top(x, y):
            return "TOP"

        clicked_item = self.canvas.find_closest(x, y)
        if not clicked_item:
            return None

        block = self.block_item_map.get(clicked_item[0])
        if not block:
            return None

        return block["instance"]

    def _resolve_endpoint_center(self, endpoint_name):
        """
        Resolve endpoint center coordinate tuple for block instance or TOP.
        """
        width = max(self.canvas.winfo_width(), 400)
        top_cx, top_cy = width // 2, 65
        return self._get_node_center(endpoint_name, top_cx, top_cy)

    # ------------------------------------------------------------------------
    # Block and Connection Editing
    # ------------------------------------------------------------------------
    def add_block(self):
        """
        Add a new block instance to current scope.
        """
        instance_name = self._sanitize_identifier(self.instance_var.get().strip())
        module_name = self._sanitize_identifier(self.module_var.get().strip())

        if not instance_name or not module_name:
            messagebox.showerror("Invalid Input", "Instance name and module name are required.")
            return

        # Enforce unique instance names within scope.
        if any(block["instance"] == instance_name for block in self.current_scope.blocks):
            messagebox.showerror("Duplicate Instance", f"Instance '{instance_name}' already exists in this scope.")
            return

        # Create block near center with simple offset.
        next_id = len(self.current_scope.blocks) + 1
        block = {
            "id": f"b{next_id}_{instance_name}",
            "instance": instance_name,
            "module": module_name,
            "x": 120 + (next_id % 5) * 30,
            "y": 140 + (next_id % 4) * 20,
        }
        self.current_scope.blocks.append(block)
        self.selected_block_id = block["id"]
        self._log_status(f"Added block: {instance_name} ({module_name})")
        self.redraw_canvas()

    def delete_selected_block(self):
        """
        Delete currently selected block and related connections.
        """
        if not self.selected_block_id:
            messagebox.showinfo("No Selection", "Select a block first.")
            return

        block = self._find_block_by_id(self.selected_block_id)
        if not block:
            return

        instance_name = block["instance"]
        self.current_scope.blocks = [b for b in self.current_scope.blocks if b["id"] != self.selected_block_id]
        self.current_scope.connections = [
            connection
            for connection in self.current_scope.connections
            if connection["src_block"] != instance_name and connection["dst_block"] != instance_name
        ]

        # Remove child scope if it exists for this instance.
        if instance_name in self.current_scope.children:
            del self.current_scope.children[instance_name]

        self._log_status(f"Deleted block: {instance_name}")
        self.selected_block_id = None
        self.redraw_canvas()

    def begin_connection(self):
        """
        Begin connection mode from currently selected source block.
        """
        if not self.selected_block_id:
            messagebox.showinfo("No Selection", "Select source block first.")
            return

        self.connect_source_block_id = self.selected_block_id
        block = self._find_block_by_id(self.selected_block_id)
        self._log_status(f"Connection mode: source '{block['instance']}'. Click destination block or TOP.")

    def _finalize_connection_to_block(self, dst_block_id):
        """
        Finalize connection from source block to destination block.
        """
        src_block = self._find_block_by_id(self.connect_source_block_id)
        dst_block = self._find_block_by_id(dst_block_id)

        if not src_block or not dst_block:
            self.connect_source_block_id = None
            return

        if src_block["id"] == dst_block["id"]:
            messagebox.showerror("Invalid Connection", "Source and destination blocks must be different.")
            self.connect_source_block_id = None
            return

        self._create_connection_from_defaults(src_block["instance"], dst_block["instance"])
        self.connect_source_block_id = None

    def _finalize_connection_to_top(self):
        """
        Finalize connection from selected source block to TOP.
        """
        src_block = self._find_block_by_id(self.connect_source_block_id)
        if not src_block:
            self.connect_source_block_id = None
            return

        self._create_connection_from_defaults(src_block["instance"], "TOP")
        self.connect_source_block_id = None

    def connect_top_to_selected(self):
        """
        Create connection TOP -> selected block.
        """
        block = self._find_block_by_id(self.selected_block_id) if self.selected_block_id else None
        if not block:
            messagebox.showinfo("No Selection", "Select destination block first.")
            return
        self._create_connection_from_defaults("TOP", block["instance"])

    def connect_selected_to_top(self):
        """
        Create connection selected block -> TOP.
        """
        block = self._find_block_by_id(self.selected_block_id) if self.selected_block_id else None
        if not block:
            messagebox.showinfo("No Selection", "Select source block first.")
            return
        self._create_connection_from_defaults(block["instance"], "TOP")

    def _create_connection_from_defaults(self, src_block_name, dst_block_name):
        """
        Create connection using compact connection defaults from UI.
        """
        src_port = self._sanitize_identifier(self.conn_src_port_var.get().strip())
        dst_port = self._sanitize_identifier(self.conn_dst_port_var.get().strip())
        width = self._normalize_width(self.conn_width_var.get().strip())

        # Validate required port names.
        if not src_port or not dst_port:
            messagebox.showerror("Missing Port Names", "Set source and destination port names in the Connections panel.")
            return

        # Auto-generate signal name from endpoints.
        signal_name = self._sanitize_identifier(f"{src_block_name}_{src_port}__{dst_block_name}_{dst_port}")

        connection = {
            "src_block": src_block_name,
            "src_port": self._sanitize_identifier(src_port),
            "dst_block": dst_block_name,
            "dst_port": self._sanitize_identifier(dst_port),
            "signal": signal_name,
            "width": width,
        }
        self.current_scope.connections.append(connection)
        self._log_status(f"Connected {src_block_name}.{src_port} -> {dst_block_name}.{dst_port} [{width}]")
        self.redraw_canvas()

    def clear_scope_connections(self):
        """
        Remove all connections in current scope.
        """
        self.current_scope.connections = []
        self._log_status("Cleared all connections in current scope.")
        self.redraw_canvas()

    # ------------------------------------------------------------------------
    # Scope Navigation
    # ------------------------------------------------------------------------
    def enter_selected_scope(self):
        """
        Enter child scope of selected block instance.
        """
        block = self._find_block_by_id(self.selected_block_id) if self.selected_block_id else None
        if not block:
            messagebox.showinfo("No Selection", "Select a block to enter its internal scope.")
            return

        instance_name = block["instance"]
        module_name = block["module"]

        # Create child scope lazily if not present.
        if instance_name not in self.current_scope.children:
            self.current_scope.children[instance_name] = ScopeNode(module_name=module_name, parent=self.current_scope)

        self.current_scope = self.current_scope.children[instance_name]
        self.selected_block_id = None
        self._update_scope_path_label()
        self._log_status(f"Entered scope: {self.current_scope.module_name}")
        self.redraw_canvas()

    def go_up_scope(self):
        """
        Move from current scope to parent scope.
        """
        if self.current_scope.parent is None:
            return
        self.current_scope = self.current_scope.parent
        self.selected_block_id = None
        self._update_scope_path_label()
        self._log_status(f"Moved up to scope: {self.current_scope.module_name}")
        self.redraw_canvas()

    def reset_to_top_scope(self):
        """
        Jump directly back to top-level scope.
        """
        self.current_scope = self.root_scope
        self.selected_block_id = None
        self._update_scope_path_label()
        self._log_status(f"Reset scope to top: {self.current_scope.module_name}")
        self.redraw_canvas()

    def _update_scope_path_label(self):
        """
        Update scope breadcrumb text.
        """
        path_nodes = []
        node = self.current_scope
        while node is not None:
            path_nodes.append(node.module_name)
            node = node.parent
        path_text = " / ".join(reversed(path_nodes))
        self.scope_path_var.set(f"Current Scope: {path_text}")

    # ------------------------------------------------------------------------
    # HDL Generation
    # ------------------------------------------------------------------------
    def generate_hdl(self):
        """
        Generate HDL files from hierarchical diagram.
        """
        if not self.project_dirs:
            messagebox.showerror("No Project", "No valid project directories found.")
            return

        project_path = self._resolve_selected_project_path()
        if not project_path:
            messagebox.showerror("Invalid Project", "Select a valid project directory.")
            return

        top_module = self._sanitize_identifier(self.top_module_var.get().strip() or "TopDesign")
        top_file = ensure_extension(self.top_file_var.get().strip() or f"{top_module}.v", "design")
        top_description = self.top_desc_var.get().strip() or "implements top-level integration logic."
        net_type = self.net_type_var.get().strip() if self.net_type_var.get().strip() else "logic"

        # Update root scope module name with user-provided top name.
        self.root_scope.module_name = top_module

        designs_dir = Path(project_path) / "designs"
        designs_dir.mkdir(parents=True, exist_ok=True)

        module_texts = {}
        self._collect_module_texts(self.root_scope, module_texts, net_type)

        created_files = []
        for module_name, module_text in module_texts.items():
            file_name = top_file if module_name == top_module else ensure_extension(module_name, "design")
            output_path = designs_dir / file_name

            if output_path.exists() and not self.overwrite_var.get():
                self._log_status(f"Skipped existing file (overwrite disabled): {output_path}")
                continue

            output_path.write_text(module_text, encoding="utf-8")
            created_files.append(str(output_path))

        # Optionally create starters for referenced child modules without scope.
        if self.create_missing_var.get():
            created_missing = self._create_missing_module_starters(designs_dir, module_texts)
            created_files.extend(created_missing)

        if created_files:
            self._log_status("Generated files:")
            for file_path in created_files:
                self._log_status(f"  - {file_path}")
            messagebox.showinfo("Generation Complete", f"Generated {len(created_files)} file(s).")
        else:
            messagebox.showinfo("No Changes", "No files were generated (possibly due to overwrite settings).")

    def _collect_module_texts(self, scope_node, module_texts, net_type):
        """
        Recursively generate module text for scope node and child scopes.
        """
        module_name = scope_node.module_name
        description = "implements module behavior from hierarchical block diagram."

        # Infer module ports from TOP-connected connections.
        ports = self._infer_ports_from_scope_connections(scope_node)

        # Create template with placeholder.
        template = render_design_template(
            file_name=ensure_extension(module_name, "design"),
            module_name=module_name,
            description=description,
            ports=ports
        )

        # Build internal declarations and instantiations.
        logic_lines = self._build_logic_lines(scope_node, net_type)
        module_text = template.replace("  // Add module internals here.", "\n".join(logic_lines))
        module_texts[module_name] = module_text

        # Recurse into child scopes.
        for child_scope in scope_node.children.values():
            self._collect_module_texts(child_scope, module_texts, net_type)

    def _infer_ports_from_scope_connections(self, scope_node):
        """
        Infer module port declarations from connections touching TOP in this scope.
        """
        port_map = {}

        for connection in scope_node.connections:
            src_block = connection["src_block"]
            dst_block = connection["dst_block"]
            src_port = connection["src_port"]
            dst_port = connection["dst_port"]
            width = connection["width"]

            if src_block == "TOP":
                # TOP -> block means module input.
                port_name = src_port
                direction = "input"
            elif dst_block == "TOP":
                # block -> TOP means module output.
                port_name = dst_port
                direction = "output"
            else:
                continue

            if port_name in port_map:
                if port_map[port_name]["direction"] != direction:
                    port_map[port_name]["direction"] = "inout"
                if not port_map[port_name]["width"] and width:
                    port_map[port_name]["width"] = width
            else:
                port_map[port_name] = {
                    "direction": direction,
                    "type": "logic",
                    "width": width,
                    "name": port_name,
                    "desc": f"Auto-generated from diagram connection ({direction}).",
                }

        return [port_map[name] for name in sorted(port_map.keys())]

    def _build_logic_lines(self, scope_node, net_type):
        """
        Build internal signal declarations and block instantiations for one scope.
        """
        lines = []

        # Determine internal signals (non-TOP to non-TOP).
        internal_signals = {}
        for connection in scope_node.connections:
            if connection["src_block"] != "TOP" and connection["dst_block"] != "TOP":
                internal_signals[connection["signal"]] = connection["width"]

        if internal_signals:
            lines.append("  ///////////////////////////////////")
            lines.append("  // Auto-generated internal signals //")
            lines.append("  ///////////////////////////////////")
            for signal_name in sorted(internal_signals.keys()):
                width = self._normalize_width(internal_signals[signal_name])
                width_part = f"[{width}] " if width else ""
                lines.append(f"  {net_type} {width_part}{signal_name};")
            lines.append("")

        # Build per-instance port mapping.
        port_maps = {block["instance"]: {} for block in scope_node.blocks}
        for connection in scope_node.connections:
            signal_name = connection["signal"]
            if connection["src_block"] != "TOP":
                port_maps[connection["src_block"]][connection["src_port"]] = signal_name
            if connection["dst_block"] != "TOP":
                port_maps[connection["dst_block"]][connection["dst_port"]] = signal_name

        # Emit instantiations.
        lines.append("  /////////////////////////////////////////")
        lines.append("  // Auto-generated block instantiations //")
        lines.append("  /////////////////////////////////////////")
        for block in scope_node.blocks:
            instance = block["instance"]
            module = block["module"]
            mappings = port_maps.get(instance, {})

            lines.append(f"  {module} {instance} (")
            port_names = sorted(mappings.keys())
            for idx, port_name in enumerate(port_names):
                comma = "," if idx < len(port_names) - 1 else ""
                lines.append(f"    .{port_name}({mappings[port_name]}){comma}")
            lines.append("  );")
            lines.append("")

        if len(lines) == 0:
            lines.append("  // No internal logic generated for this module yet.")

        return lines

    def _create_missing_module_starters(self, designs_dir, module_texts):
        """
        Create starter files for referenced modules not already generated/existing.
        """
        created_paths = []
        referenced_modules = set()

        # Gather referenced module names from all scopes.
        self._collect_referenced_modules(self.root_scope, referenced_modules)

        for module_name in sorted(referenced_modules):
            if module_name in module_texts:
                continue

            file_name = ensure_extension(module_name, "design")
            output_path = designs_dir / file_name
            if output_path.exists():
                continue

            starter_text = render_design_template(
                file_name=file_name,
                module_name=module_name,
                description="implements child module behavior from diagram hierarchy.",
                ports=[]
            )
            output_path.write_text(starter_text, encoding="utf-8")
            created_paths.append(str(output_path))

        return created_paths

    def _collect_referenced_modules(self, scope_node, referenced_set):
        """
        Recursively collect child module references from scope tree.
        """
        for block in scope_node.blocks:
            referenced_set.add(block["module"])
        for child_scope in scope_node.children.values():
            self._collect_referenced_modules(child_scope, referenced_set)

    # ------------------------------------------------------------------------
    # Helper Functions
    # ------------------------------------------------------------------------
    def _resolve_selected_project_path(self):
        """
        Resolve full project path from selected combobox label.
        """
        selected_name = self.project_var.get().strip()
        for path in self.project_dirs:
            if os.path.basename(path) == selected_name:
                return path
        return None

    def _find_block_by_id(self, block_id):
        """
        Find block object by block id in current scope.
        """
        for block in self.current_scope.blocks:
            if block["id"] == block_id:
                return block
        return None

    def _sanitize_identifier(self, name):
        """
        Convert text to safe identifier.
        """
        sanitized = re.sub(r"[^A-Za-z0-9_]", "_", str(name).strip())
        if not sanitized:
            return ""
        if sanitized[0].isdigit():
            sanitized = f"n_{sanitized}"
        return sanitized

    def _normalize_width(self, width_text):
        """
        Normalize width text format.
        """
        width = str(width_text).strip().replace("[", "").replace("]", "")
        return width

    def _log_status(self, message):
        """
        Append status message to status pane.
        """
        self.status_text.insert(tk.END, message + "\n")
        self.status_text.see(tk.END)


def main():
    """
    Entry point for GUI application.
    """
    root = tk.Tk()
    app = DiagramApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
