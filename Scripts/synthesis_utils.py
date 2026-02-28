import os
import sys
import config
import subprocess
from log_utils import check_logs
from file_utils import choose_from_list

"""
This module provides utility functions for synthesis using Synopsys Design Compiler.
It includes functions to list available .dc files, prompt the user for selection,
and run the synthesis process. The module also checks if synthesis is needed based on file modification times.
"""


def get_dc_script():
    """List all .dc files in the Scripts directory and let user select one (unless only one exists)."""
    dc_files = [f for f in os.listdir(config.SCRIPTS_DIR) if f.endswith('.dc')]
    if not dc_files:
        print("No .dc files found in Scripts directory.")
        sys.exit(1)

    # If only one script, return it immediately
    if len(dc_files) == 1:
        return os.path.join(config.SCRIPTS_DIR, dc_files[0])

    print("Select a .dc script to use for synthesis:")
    for i, fname in enumerate(dc_files, 1):
        print(f"{i}) {fname}")

    # Prompt the user to select a log file.
    dc_script = choose_from_list(
        files=dc_files,
        prompt=f"Enter the number of the .dc script to use (1-{len(dc_files)}): ",
        pre_prompt=f"Select a .dc script to use for synthesis:"
    )

    return os.path.join(config.SCRIPTS_DIR, dc_script)


def should_run_synthesis(dc_script):
    """
    Determine whether synthesis needs to be re-run based on file modification times.

    Synthesis is triggered if:
    - The output .vg file does not exist.
    - The selected .dc synthesis script is newer than the existing .vg file.
    - Any .sv or .v design file in the DESIGNS_DIR is newer than the .vg file.

    Args:
        dc_script (str): Path to the selected .dc script.

    Returns:
    - tuple (True, dc_script, base_name) if synthesis is needed.
    """
    # Derive the expected .vg file name based on the selected .dc script
    base_name = os.path.splitext(os.path.basename(dc_script))[0]
    vg_file = os.path.join(config.DESIGNS_DIR, f"{base_name}.vg")

    # If the .vg file does not exist, synthesis is required
    if not os.path.exists(vg_file):
        return True, dc_script,  base_name

    # Get modification times
    vg_mtime = os.path.getmtime(vg_file)
    dc_mtime = os.path.getmtime(dc_script)

    # Re-run synthesis if the .dc script is newer than the .vg
    if dc_mtime > vg_mtime:
        return True, dc_script,  base_name

    # Check if any .sv or .v file in DESIGNS_DIR is newer than the .vg
    for root, _, files in os.walk(config.DESIGNS_DIR):
        for f in files:
            if f.endswith((".sv", ".v")):
                full_path = os.path.join(root, f)
                if os.path.getmtime(full_path) > vg_mtime:
                    return True, base_name

    # If nothing is newer, no need to synthesize
    print("make: 'synthesis' is up to date.")
    return False, None, None


def synthesize():
    """
    Run synthesis on the design files in the current directory using the Synopsys Design Compiler.
    This function sets up the necessary environment variables, runs the synthesis command,  
    and checks for errors in the synthesis log file.
    
    Returns:
        None: This function does not return any value. It only performs synthesis and checks logs.
    """
    # Check if synthesis is needed and get the base name of the .vg file.
    result, dc_script, base_name = should_run_synthesis(get_dc_script())

    # If synthesis is not needed, exit the function.
    if not result:
        return

    # Change the directory to the synthesis folder.
    os.chdir(config.SYNTHESIS_DIR)

    # Path to the synthesis log file.
    log_file = os.path.join(config.OUTPUTS_DIR, f"{base_name}_synthesis.log")

    # Command to run synthesis using Synopsys Design Compiler.
    synthesis_command = f'echo "source {dc_script}; report_register -level_sensitive; check_design; exit;" | dc_shell -no_gui > {log_file} 2>&1'

    try:
        print(f"Synthesizing {base_name} to Synopsys 32-nm Cell Library...")

        # Run the synthesis command and capture output.
        subprocess.run(
            synthesis_command,
            shell=True,                                # Execute in a shell
            stdout=subprocess.PIPE,                    # Capture standard output
            stderr=subprocess.PIPE,                    # Capture standard error
            check=True                                 # Raise exception on non-zero exit code
        )
    except subprocess.CalledProcessError as e:
        print(f"\n===== Synthesis failed with error {e.returncode} =====")
        # Decode and format the error message from stderr
        error_message = e.stderr.decode('utf-8').replace("\n", " ").strip()
        print(f"{error_message}")
        sys.exit(1)

    # Check the synthesis log for errors or warnings.
    result = check_logs(log_file, "c")
    if result == "error":
        print("Synthesis completed with errors. Run 'make log o' for details.")
        sys.exit(1)
    elif result == "warning":
        print("Synthesis completed with warnings. Run 'make log o' for details.")
    else:
        print("Synthesis completed successfully. Run 'make log o' for details.")