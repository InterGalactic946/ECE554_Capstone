import sys
import config
import argparse
import log_utils
from pathlib import Path
from assembler_utils import assemble
from synthesis_utils import synthesize
from cleanup_utils import clean_project
from file_utils import print_mode_message
from check_utils import check_design_files
from compile_utils import build_dependency_graph
from execute_utils import execute_tests, find_testbench
from ci_tasks import run_ci_sweep

"""
This script serves as the main entry point for running various tasks related to the WISC-S25 project.
It includes functions for parsing command-line arguments, setting up directories,
and executing tests in a simulation environment.
It provides options for cleaning up generated files, running synthesis,
checking design files, and displaying logs.
"""


def parse_arguments():
    """
    Parse and validate command-line arguments for running a testbench.

    This function defines the arguments available for the script, validates them, 
    and ensures that the appropriate flags are used based on the desired functionality. 
    The function also provides clear error handling for missing or incompatible arguments.

    Returns:
        argparse.Namespace: A namespace object containing the parsed arguments.

    Raises:
        SystemExit: If required arguments are missing or incompatible, the function will exit with an error message.
    """
    parser = argparse.ArgumentParser(description="Run various tasks for the WISC-S25 project.")

    # Positional argument for cleaning up generated files.
    parser.add_argument(
        "-cl", "--clean", action="store_true", help="Clean up generated files in the selected directory."
    )

    # Optional argument for specifying the mode of running tests.
    parser.add_argument(
        "-m", "--mode", type=int, choices=[0, 1, 2, 3], default=0,
        help="Test execution mode: 0=Command-line, 1=Save waves, 2=GUI, 3=View saved waves."
    )

    # Flag to indicate whether to run all tasks in the directory.
    parser.add_argument("-a", "--all", action="store_true", help="Run a specifc task for all files in a single directory.")

    # Flag to assemble a file and output the image file in the tests directory.
    parser.add_argument("-as", "--asm", action="store_true", help="Assemble a file and output the image file in the test directory.")

    # Flag to run synthesis.
    parser.add_argument("-s", "--synth", action="store_true", help="Run synthesis in the selected directory.")

    # Flag to run the post synthesis test.
    parser.add_argument("-ps", "--post_synth", action="store_true", help="Run the post synthesis testbench in the directory.")

    # Option to check all verilog files within a directory.
    parser.add_argument("-c", "--check", action="store_true", help="Check all Verilog design files in the directory.")

    # Option to select which type of log to display.
    parser.add_argument("-l", "--logs", type=str, choices=["o", "t", "c"], help="Display logs: 'o' for top level logs, 't' for transcript, 'c' for compilation.")

    # Option to run CI sweep across all discovered project directories.
    parser.add_argument("-ci", "--ci", action="store_true", help="Run CI sweep across all valid project directories.")

    # Parse and return the arguments.
    return parser.parse_args()


def main():
    """
    Main entry point for the script.

    Parses command-line arguments, sets up the environment, and coordinates execution of tasks 
    like cleanup, synthesis, design checks, and test execution for the WISC-S25 project. 
    Handles errors and provides a user-friendly CLI for task selection. Intended for standalone use.
    """
    # Parse command-line arguments.
    args = parse_arguments()
    
    try:
        # Handle CI sweep mode separately (no directory prompt).
        if args.ci:
            sys.exit(run_ci_sweep())

        # Set up the directories based on the chosen directory.
        config.setup_directories(config.choose_directory(args))
        
        # Handle log file display and exit, otherwise check design files, or synthesize design, or run tests / view waves.
        if args.clean:
            clean_project(args.all)
        elif args.logs:
            log_utils.display_log(args.logs)
        elif args.check:
            check_design_files()
        elif args.synth:
            synthesize()
        else:
            # Assemble the selected input file.
            if args.asm:
                assemble()

            # Retrieve testbenches to be run
            test_names = find_testbench(args)

            # Display the appropriate message based on mode.
            print_mode_message(args)
            
            # Build the dependency graph if it doesn't exist yet.            
            if not config.DEPENDENCY_GRAPH.is_file():
                build_dependency_graph()             

            # Run the tests in parallel.
            execute_tests(test_names, args)
    except FileNotFoundError as e:
        # Handle missing file errors
        print(e)
        sys.exit(1)

if __name__ == "__main__":
    main()