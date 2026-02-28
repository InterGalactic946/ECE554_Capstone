import os
import sys

"""
This module provides utility functions for file handling and user interaction.
"""


def print_mode_message(args):
    """
    Prints an appropriate message based on the mode.

    Ensures messages are printed only once, especially when the `-a` (all tests) flag is used
    and tests are run in parallel.

    Args:
        args (argparse.Namespace): Parsed command-line arguments.

    Returns:
        None
    """
    try:
        mode_labels = ["command-line", "saving", "GUI"]

        # Handle messages for all tests (-a flag).
        if args.all:
            if args.mode != 3:
                print(f"Running all tests in {mode_labels[args.mode]} mode...")
            else:
                print("Viewing waveforms for all tests...")
    except Exception as e:
        print(f"Printing message failed with error: {e}")
        sys.exit(1)


def choose_from_list(files, prompt="Select a file to continue (enter number):", pre_prompt="Available Files:"):
    """
    Lists the files (showing only basenames) and prompts the user to select one.

    Args:
        files (list): List of file names or full file paths.
        prompt (str): The prompt message for user input.
        pre_prompt (str): The message to display before listing the files.

    Returns:
        str: The original file path selected by the user.
    """
    if not files:
        print("No files found. Exiting...")
        sys.exit(1)

    # Display pre-prompt
    print(pre_prompt)

    # List the available files showing only the base names
    for idx, file in enumerate(files, start=1):
        print(f"{idx}. {os.path.basename(file)}")

    # Loop to get valid input from user
    while True:
        try:
            choice = int(input(prompt)) - 1
            if 0 <= choice < len(files):
                break  # Valid choice, exit loop
            else:
                print(f"Invalid input. Please enter a number between 1 and {len(files)}.")
        except ValueError:
            print("Invalid input. Please enter a valid number.")

    # Return the original file path selected by the user
    return files[choice]