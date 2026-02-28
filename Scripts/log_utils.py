import os
import sys
import config
from file_utils import choose_from_list

"""
This module provides utility functions for handling log files related to simulation and compilation processes.
It includes functions to list available log files, display their contents, and check for errors or warnings.
"""


def list_log_files(log_dir):
    """
    List the available log files for a given type of log.

    This function checks the specified log directory (either transcript or compilation) 
    and returns a list of log files with the ".log" or ".txt" extension.

    Args:
        log_dir (str): The directory to search for log files.

    Returns:
        list: A list of available log files matching the specified type. If no logs are found, an empty list is returned.
    """
    # Return an empty list if the directory doesn't exist.
    if not os.path.exists(log_dir):
        return []

    # List all files in the log directory that end with ".log".
    return [
        os.path.join(log_dir, file)
        for file in os.listdir(log_dir)
        if file.endswith(".log") or file.endswith(".txt")
    ]


def display_log(log_type):
    """
    Display the contents of a log file based on the specified type.

    If there is exactly one log file available, the function will display that file automatically.
    If multiple log files are available, the user will be prompted to select one.

    Args:
        log_type (str): The type of log to retrieve files for. Can be 't' for transcript, 'c' for compilation, or 'o' for top level output logs.

    Raises:
        FileNotFoundError: If no log files are available in the specified directory.
    """
    # Determine the appropriate log directory based on the log type.
    if log_type == "t":
        log_dir = config.TRANSCRIPT_DIR  # Set the directory for transcript logs.
    elif log_type == "c":        
        log_dir = config.COMPILATION_DIR # Set the directory for compilation logs.
    elif log_type == "o":
        log_dir = config.OUTPUTS_DIR     # Set the directory for top level output logs.

    # Get a list of available logs for the specified log type.
    available_logs = list_log_files(log_dir)

    # If no logs are found, inform the user and exit.
    if not available_logs:
        if log_type == "t":
            print(f"No transcript log files found in {log_dir}.")
        elif log_type == "c":
            print(f"No compilation log files found in {log_dir}.")
        elif log_type == "o":
            print(f"No top level output log files found in {log_dir}.")
        return

    # If there is only one log file, display it directly without prompting for selection.
    if len(available_logs) == 1:
        log_file = os.path.join(log_dir, available_logs[0])
        with open(log_file, "r") as file:
            print(f"=== Displaying {os.path.basename(available_logs[0])} ===")
            print(file.read())
        return

    # Prompt the user to select a log file.
    selected_log = choose_from_list(
        files=available_logs,
        prompt=f"Enter the number of the log file to display (1-{len(available_logs)}): ",
        pre_prompt=f"Available {log_type.upper()} logs:"
    )

    # Open and display the selected log file's content.
    with open(selected_log, "r") as file:
        print(f"=== Displaying {os.path.basename(selected_log)} ===")
        print(file.read())

    # Exit the program after displaying the log file.
    sys.exit(0)


def check_logs(logfile, mode):
    """
    Check the status of a log file based on the specified mode.

    Args:
        logfile (str): Path to the log file that contains simulation or compilation output.
        mode (str): Mode of checking. Use:
            - "t" for checking simulation transcript logs.
            - "c" for checking compilation logs.

    Returns:
        str: The result of the log check, which could be one of the following:
            - "success": No issues found.
            - "error": Issues detected in the log.
            - "warning": Warnings found in the log.
            - "unknown": Status could not be determined (specific to transcript logs).

    Description:
        - Based on the mode, the function delegates to either `check_transcript` for simulation logs
          or `check_compilation` for compilation logs.
        - It analyzes the content of the log file to detect errors, warnings, or successes.
    """
    
    def check_compilation(log_file):
        """
        Check the compilation log for errors or warnings.

        Args:
            log_file (str): Path to the compilation log file.

        Returns:
            str: Returns one of the following:
                - "error": If any errors are found.
                - "warning": If warnings are present.
                - "success": If no issues are found in the compilation log.
                
        Description:
            - Reads the content of the compilation log file to check for "Error:" or "Warning:" keywords.
            - Returns the status based on the presence of these keywords.
        """
        # Open and read the content of the log file
        with open(log_file, "r") as file:
            content = file.read()

            # Check for the presence of "Error:" or "Warning:" keywords
            if "Error:" in content:
                return "error"
            elif "Warning:" in content:
                return "warning"
            else:
                return "success"

    def check_transcript(log_file):
        """
        Check the simulation transcript for success or failure.

        Args:
            log_file (str): Path to the simulation transcript log file.

        Returns:
            str: Returns one of the following:
                - "success": If the test passed successfully.
                - "error": If an error occurred during the simulation.
                - "warning": If there were warnings in the simulation.
                - "unknown": If the status could not be determined from the transcript.
                
        Description:
            - Reads the simulation transcript log file to look for specific success or failure keywords.
            - Checks for the presence of "ERROR" (for failure), "YAHOO!! All tests passed." (for success),
              or "Warning:" (for warnings).
        """
        # Open and read the content of the transcript log file
        with open(log_file, "r") as file:
            content = file.read()

            # Check for specific success or failure strings in the transcript
            if any(word in content for word in ["ERROR", "FAIL"]):
                return "error"
            elif any(word in content for word in ["YAHOO!!", "YIPPEE"]):
                return "success"
            elif "Warning:" in content:
                return "warning"
            else:
                return "unknown"

    # Direct to the appropriate check function based on the mode
    if mode == "t":
        return check_transcript(logfile)
    elif mode == "c":
        return check_compilation(logfile)