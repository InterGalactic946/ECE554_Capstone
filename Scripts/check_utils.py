import os
import sys
import config
import subprocess


"""
This module provides utility functions for checking Verilog design files using the Vcheck tool.
It includes a function to check design files in the current directory, excluding testbench files.
It runs the 'java Vcheck <design_file.v>' command on each file and reports any errors.
It also provides a function to check the design files in the specified directory.
"""


def check_design_files():
    """
    Checks Verilog design files in the current directory, excluding testbench files (_tb.v).
    Runs the 'java Vcheck <design_file.v>' command on each file and reports any errors.

    This function:
    - Scans the current directory for Verilog design files (.v).
    - Excludes testbench files (_tb.v).
    - Runs the Vcheck tool on each file and captures the output.
    - Prints error messages for any design files that fail the check.
    - Prints a success message if all design files are compliant.
    
    Returns:
        None
    """
    # Change the directory to the designs folder.
    os.chdir(config.DESIGNS_DIR)

    # Get absolute paths of all Verilog files (excluding testbench files).
    verilog_files = [os.path.abspath(f) for f in os.listdir()]
    
    # List to store files that fail the check.
    failed_files = []

    # Iterate over each design file and run the Vcheck command.
    for vfile in verilog_files:
        try:
            # Run 'java Vcheck <design_file.v>' with the specified classpath
            result = subprocess.run(
                f"java -cp {config.SCRIPTS_DIR} Vcheck {vfile}",  # Command to execute
                shell=True,                                # Execute in a shell
                stdout=subprocess.PIPE,                    # Capture standard output
                stderr=subprocess.PIPE,                    # Capture standard error
                check=True                                 # Raise exception on non-zero exit code
            )
            
            # Decode the output (result.stdout is in bytes)
            output = result.stdout.decode('utf-8').strip()  # Convert to string and remove leading/trailing whitespace
            
            # If the output does NOT start with "End of file", it indicates a failure
            if not output.startswith("End of file"):
                failed_files.append((vfile, output))  # Store failed file and error message
        
        except subprocess.CalledProcessError as e:
            # Handle the exception if the command fails
            print(f"===== Error running Vcheck on {os.path.basename(vfile)} =====")
            # Decode and clean the error message from stderr.
            error_message = e.stderr.decode('utf-8').replace("\n", " ").strip()  # Remove internal newlines
            print(f"{error_message}")
            sys.exit(1)  # Exit if there's an error running Vcheck

    # Print results
    if failed_files:
        # If there are failing files, print their errors
        print("The following design files are not compliant:\n")
        for vfile, error in failed_files:
            print(f"Check failed for {os.path.basename(vfile)}:\n{error}\n")
    else:
        # If no files failed, print success message.
        if len(verilog_files) != 0:
            print("YAHOO!! All Verilog design files are compliant.")
        else:
        # Exit gracefully, if no Verilog design files found.
            print(f"No Verilog design files found in {os.path.basename(config.DESIGNS_DIR)}. Exiting...")