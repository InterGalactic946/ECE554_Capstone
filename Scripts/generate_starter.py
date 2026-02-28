import os
import sys
import argparse
from pathlib import Path
import config
from file_utils import choose_from_list

"""
This script generates starter Verilog/SystemVerilog files for either:
1. Design modules
2. Testbench modules

The generated files are intended to match the existing project style:
- Header comment banners
- Clear section comments
- Consistent instance naming (e.g., iDUT)
- Clean, ready-to-edit starter structure

The script prompts the user for:
- Project directory (discovered dynamically from ROOT_DIR)
- Starter type (design or testbench)
- Module name
- File name
- Description
- Input/Output/Inout ports (direction, type, width, name, and optional comment)
"""


# ==========================================================
# Argument and selection helper functions
# ==========================================================
def parse_arguments():
    """
    Parse command-line arguments for starter generation.

    This parser allows optional pre-seeding of starter metadata.
    If any values are omitted, interactive prompts will be used.

    Returns:
        argparse.Namespace: Parsed arguments containing starter settings.
    """
    parser = argparse.ArgumentParser(description="Generate starter design/testbench files.")

    # Optional argument to choose the type of starter file.
    parser.add_argument(
        "-k", "--kind",
        choices=["Design", "Testbench", "design", "testbench", "tb"],
        help="Starter type: 'Design' for RTL module, 'Testbench' for testbench."
    )

    # Optional argument for output file name.
    parser.add_argument(
        "-f", "--file",
        type=str,
        help="Output file name (for example: ALU.v, ALU_tb.sv)."
    )

    # Optional argument for module name.
    parser.add_argument(
        "-m", "--module",
        type=str,
        help="Module name for the generated starter."
    )

    # Optional argument for description text in file header.
    parser.add_argument(
        "-d", "--description",
        type=str,
        help="Short description shown in the header comments."
    )

    # Parse and return arguments.
    return parser.parse_args()


def choose_project_directory():
    """
    Prompt the user to choose one discovered top-level project directory.

    A valid directory must satisfy config.REQUIRED_SUBDIRS.

    Returns:
        str: Absolute path of selected project directory.

    Raises:
        FileNotFoundError: If no valid project directories are available.
    """
    # Discover all valid project directories.
    top_level_dirs = config.get_top_level_dirs()

    # Exit gracefully if no valid directories are found.
    if not top_level_dirs:
        raise FileNotFoundError(
            f"No valid project directories found in '{config.ROOT_DIR}'. "
            f"Expected each directory to contain: {', '.join(config.REQUIRED_SUBDIRS)}."
        )

    # Prompt user to choose target directory.
    selected_dir = choose_from_list(
        files=top_level_dirs,
        pre_prompt="Available directories to generate starter files:",
        prompt=f"Enter the number of the directory to choose: (1-{len(top_level_dirs)}): "
    )

    # Return the selected directory path.
    return selected_dir


def choose_starter_kind(args):
    """
    Determine the starter type from argument input or interactive prompt.

    Args:
        args (argparse.Namespace): Parsed command-line arguments.

    Returns:
        str: Selected starter kind ("design" or "testbench").
    """
    # If starter type is already passed by argument, normalize and use it directly.
    if args.kind:
        kind_text = args.kind.strip().lower()
        if kind_text in ["design"]:
            return "design"
        return "testbench"

    # Otherwise prompt user to select starter type.
    starter_label = choose_from_list(
        files=["Design", "Testbench"],
        pre_prompt="Available starter types:",
        prompt="Enter the number of the starter type to generate: (1-2): "
    )

    # Map display label to internal starter type.
    starter_kind = "design" if starter_label == "Design" else "testbench"

    # Return the selected starter type.
    return starter_kind


def get_non_empty_input(prompt_message, default_value=None):
    """
    Prompt user for input and ensure a non-empty value unless default exists.

    Args:
        prompt_message (str): Prompt string shown to the user.
        default_value (str | None): Optional default value when Enter is pressed.

    Returns:
        str: User-entered value or default value.
    """
    while True:
        value = input(prompt_message).strip()

        # Accept explicit non-empty input.
        if value:
            return value

        # Accept default value if provided.
        if default_value is not None:
            return default_value

        # Continue prompting when no input and no default.
        print("Input cannot be empty. Please try again.")


def ask_yes_no(prompt_message, default_yes=True):
    """
    Prompt user for yes/no confirmation.

    Args:
        prompt_message (str): Message displayed to user.
        default_yes (bool): Default response for empty input.

    Returns:
        bool: True for yes, False for no.
    """
    default_hint = "Y/n" if default_yes else "y/N"

    while True:
        value = input(f"{prompt_message} ({default_hint}): ").strip().lower()

        # Return default decision on empty input.
        if value == "":
            return default_yes

        # Validate explicit yes/no values.
        if value in ["y", "yes"]:
            return True
        if value in ["n", "no"]:
            return False

        # Prompt again for invalid input.
        print("Invalid input. Please enter 'y' or 'n'.")


# ==========================================================
# Port and template rendering helper functions
# ==========================================================
def parse_port_line(port_line):
    """
    Parse a single compact port specification line.

    Expected format:
        direction,type,width,name,comment

    Notes:
    - width can be left blank for scalar signals.
    - comment is optional.
    - type defaults to logic when omitted.

    Args:
        port_line (str): Raw user-entered line.

    Returns:
        dict: Normalized port metadata dictionary.

    Raises:
        ValueError: If required fields are invalid or missing.
    """
    # Split on commas and trim whitespace around each field.
    fields = [field.strip() for field in port_line.split(",")]

    # Validate minimum required fields.
    if len(fields) < 4:
        raise ValueError("Each port must include at least: direction,type,width,name")

    # Assign parsed field values.
    direction = fields[0].lower()
    data_type = fields[1] if fields[1] else "logic"
    width = fields[2].replace("[", "").replace("]", "")
    name = fields[3]
    desc = fields[4] if len(fields) > 4 else ""

    # Validate direction.
    if direction not in ["input", "output", "inout"]:
        raise ValueError("Direction must be input/output/inout")

    # Validate signal name.
    if not name:
        raise ValueError("Signal name cannot be empty")

    # Return normalized parsed port metadata.
    return {
        "direction": direction,
        "type": data_type,
        "width": width,
        "name": name,
        "desc": desc,
    }


def collect_ports():
    """
    Prompt user to collect DUT port definitions.

    For each port, this function captures:
    - Direction (input/output/inout)
    - Data type (default wire)
    - Width (optional, e.g., 15:0)
    - Signal name
    - Optional short description

    Returns:
        list[dict]: Port metadata list in declaration order.
    """
    # Store all ports in insertion order.
    ports = []

    # Print usage guidance for compact port entry.
    print("\nEnter module ports (DUT perspective).")
    print("Enter one port per line using this format:")
    print("  direction,type,width,name,comment")
    print("Examples:")
    print("  input,logic,15:0,A,First ALU operand")
    print("  output,logic,,done,Completion signal")
    print("Press Enter on an empty line when done.\n")

    # Continue collecting ports until an empty line is entered.
    while True:
        port_line = input(f"Port #{len(ports) + 1}: ").strip()

        # Empty line indicates completion.
        if port_line == "":
            break

        # Parse and validate entered line.
        try:
            ports.append(parse_port_line(port_line))
        except ValueError as error:
            print(f"Invalid port entry: {error}")
            print("Please re-enter the port using: direction,type,width,name,comment")

    # Return all collected ports in entered order.
    return ports


def make_header_banner(file_name, module_name, description):
    """
    Create file header comment lines with project-style banner formatting.

    Args:
        file_name (str): Output file name.
        module_name (str): Module name shown in the title line.
        description (str): Description text shown in banner body.

    Returns:
        list[str]: Header banner lines.
    """
    # Build a standardized description sentence to mirror existing project file headers.
    description_sentence = f"This module {description.strip()}"

    # Split description into up to three lines for readability within banner width.
    desc_line_1 = description_sentence[:52]
    desc_line_2 = description_sentence[52:104]
    desc_line_3 = description_sentence[104:156]

    lines = [
        "///////////////////////////////////////////////////////////",
        f"// {file_name}: {module_name} Module".ljust(58) + "//",
        "//".ljust(58) + "//",
        f"// {desc_line_1}".ljust(58) + "//",
    ]

    if desc_line_2:
        lines.append(f"// {desc_line_2}".ljust(58) + "//")
    if desc_line_3:
        lines.append(f"// {desc_line_3}".ljust(58) + "//")

    lines.append("///////////////////////////////////////////////////////////")
    return lines


def render_design_template(file_name, module_name, description, ports):
    """
    Generate design starter source text.

    Args:
        file_name (str): Output file name.
        module_name (str): RTL module name.
        description (str): Description used in header banner.
        ports (list[dict]): Module port metadata.

    Returns:
        str: Complete starter source content for a design module.
    """
    # Start with default nettype directive and header banner.
    lines = ["`default_nettype none // Set the default as none to avoid errors", ""]
    lines.extend(make_header_banner(file_name, module_name, description))

    # Build module declaration with or without ports.
    if ports:
        lines.append(f"module {module_name} (")
        for idx, port in enumerate(ports):
            comma = "," if idx < len(ports) - 1 else ""
            width = f"[{port['width']}] " if port["width"] else ""
            comment = f" // {port['desc']}" if port["desc"] else ""
            lines.append(f"    {port['direction']} {port['type']} {width}{port['name']}{comma}{comment}")
        lines.append(");")
    else:
        lines.append(f"module {module_name}();")

    # Add starter sections matching the project's comment style.
    lines.extend(
        [
            "",
            "  ///////////////////////////////////",
            "  // Declare any internal signals //",
            "  /////////////////////////////////",
            "",
            "  ////////////////////////////////////////////////////////",
            "  // Implement the module logic as structural/dataflow //",
            "  //////////////////////////////////////////////////////",
            "",
            "  // Add module internals here.",
            "",
            "endmodule",
            "",
            "`default_nettype wire // Reset default behavior at the end",
        ]
    )

    # Return final source text.
    return "\n".join(lines) + "\n"


def render_testbench_template(file_name, module_name, description, ports):
    """
    Generate testbench starter source text.

    Args:
        file_name (str): Output file name.
        module_name (str): DUT module name.
        description (str): Description used in header banner.
        ports (list[dict]): DUT port metadata.

    Returns:
        str: Complete starter source content for a testbench module.
    """
    # Testbench module name follows existing naming convention.
    testbench_name = f"{module_name}_tb"

    # Build header and module declaration.
    lines = []
    lines.extend(make_header_banner(file_name, testbench_name, description))
    lines.append(f"module {testbench_name}();")
    lines.append("")

    # Add package import placeholders and stimulus declaration section.
    lines.extend(
        [
            "  // Import task packages here if needed.",
            "  // import Monitor_tasks::*;",
            "  // import Verification_tasks::*;",
            "",
            "  ///////////////////////////",
            "  // Stimulus of type logic //",
            "  /////////////////////////",
        ]
    )

    # Declare testbench signals from DUT ports.
    if ports:
        for port in ports:
            width = f"[{port['width']}] " if port["width"] else ""
            comment = f" // {port['desc']}" if port["desc"] else ""
            lines.append(f"  logic {width}{port['name']};{comment}")
    else:
        lines.append("  // logic clk, rst_n;")

    # Add DUT instantiation block using iDUT naming.
    lines.extend(
        [
            "",
            "  //////////////////////",
            "  // Instantiate DUT //",
            "  ////////////////////",
            f"  {module_name} iDUT (",
        ]
    )

    if ports:
        for idx, port in enumerate(ports):
            comma = "," if idx < len(ports) - 1 else ""
            lines.append(f"    .{port['name']}({port['name']}){comma}")

    lines.append("  );")
    lines.append("")

    # Add common starter scaffold for clocking and stimulus.
    lines.extend(
        [
            "",
            "  // Test procedure to apply stimulus and check responses.",
            "  initial begin",
            "    // Initialize all inputs here.",
            "    // Apply directed/random test stimulus here.",
            "    // Add checks, assertions, and end-of-test criteria here.",
            "    // Compare DUT outputs with expected values here.",
            "",
            "    $display(\"Starter testbench completed. Add your checks here.\");",
            "    $stop();",
            "  end",
            "",
            
            "  ///////////////////////////////////////////////",
            "  // Optional clock generation for synchronous DUT //",
            "  ///////////////////////////////////////////////",
            "  // always",
            "  //   #5 clk = ~clk;",
            "endmodule",
        ]
    )

    # Return final source text.
    return "\n".join(lines) + "\n"


def ensure_extension(file_name, starter_kind):
    """
    Ensure output file name has an extension.

    Defaults:
    - design -> .v
    - testbench -> .sv

    Args:
        file_name (str): User-provided file name.
        starter_kind (str): Starter type ('design' or 'testbench').

    Returns:
        str: File name with extension.
    """
    # Preserve existing extension if user already provided one.
    if Path(file_name).suffix:
        return file_name

    # Choose default extension by starter type.
    if starter_kind == "testbench":
        return f"{file_name}.sv"
    return f"{file_name}.v"


def choose_output_path(starter_kind, file_name):
    """
    Resolve output path for starter file based on starter type.

    Args:
        starter_kind (str): Starter type ('design' or 'testbench').
        file_name (str): Output file name.

    Returns:
        str: Full output path to generated file.
    """
    # Design starters are generated in designs/.
    if starter_kind == "design":
        return os.path.join(config.DESIGNS_DIR, file_name)

    # Testbench starters are generated in tests/.
    return os.path.join(config.TESTS_DIR, file_name)


def write_starter_file(output_path, content):
    """
    Write generated starter source to target file with overwrite confirmation.

    Args:
        output_path (str): Full output path.
        content (str): Source content to write.

    Returns:
        None
    """
    # Confirm before overwriting existing files.
    if os.path.exists(output_path):
        overwrite = ask_yes_no(
            f"{os.path.basename(output_path)} already exists. Overwrite?",
            default_yes=False
        )
        if not overwrite:
            print("Generation canceled. File was not overwritten.")
            return

    # Write starter file content.
    with open(output_path, "w", encoding="utf-8") as file_handle:
        file_handle.write(content)

    # Inform user of successful generation.
    print(f"Starter file generated: {output_path}")


# ==========================================================
# Main entry point
# ==========================================================
def main():
    """
    Main entry point for starter generation workflow.

    Workflow:
    1. Parse args
    2. Select project directory
    3. Setup project-specific directories in config
    4. Collect starter metadata (type, module/file/description, ports)
    5. Generate source text
    6. Write output file

    Returns:
        None
    """
    # Parse command-line arguments.
    args = parse_arguments()

    try:
        # Select and setup target project directory.
        selected_dir = choose_project_directory()
        config.setup_directories(selected_dir)

        # Determine starter kind (design/testbench).
        starter_kind = choose_starter_kind(args)

        # Collect module name.
        default_module = args.module if args.module else "MyModule"
        module_name = get_non_empty_input("Enter module name: ", default_module)

        # Collect output file name and ensure extension.
        default_file = args.file if args.file else (f"{module_name}_tb" if starter_kind == "testbench" else module_name)
        file_name = ensure_extension(get_non_empty_input("Enter file name: ", default_file), starter_kind)

        # Collect short description for header comments.
        default_description = args.description if args.description else "Add a short description for this module."
        description = get_non_empty_input("Enter short description: ", default_description)

        # Collect DUT port definitions.
        ports = collect_ports()

        # Determine output path.
        output_path = choose_output_path(starter_kind, file_name)

        # Generate starter source text.
        if starter_kind == "design":
            content = render_design_template(file_name, module_name, description, ports)
        else:
            content = render_testbench_template(file_name, module_name, description, ports)

        # Write generated file.
        write_starter_file(output_path, content)
    except FileNotFoundError as error:
        # Handle missing directory errors gracefully.
        print(error)
        sys.exit(1)


if __name__ == "__main__":
    main()
