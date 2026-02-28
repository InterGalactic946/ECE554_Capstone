import os
import sys
import config
import concurrent.futures
from file_utils import choose_from_list
from run_utils import run_test, view_waveforms
from compile_utils import compile_files

"""
This module provides utility functions for executing testbenches in a simulation environment.
It includes functions to execute tests, run them in parallel, and print messages based on the mode of execution.
"""


def find_testbench(args):
    """
    Search for testbench files in the specified directory.

    This function scans the testbench directory for `.(s)v` files with the `_tb.(s)v` suffix.
    - If `args.post_synth` is True, only files ending with `_ps_tb.v` or `_ps_tb.sv` are considered.
    - If no testbench files are found, it raises an error or exits.
    - If `find_all` is True, returns all testbench files (excluding the `.(s)v` extension).
    - If only one testbench file is found, returns its name (excluding the `.(s)v` extension).
    - If multiple testbench files are found, and `find_all` is False, prompts the user to choose one.

    Args:
        args: Argument object containing flags like post_synth.

    Returns:
        list: A list of testbench names (excluding the `.sv` or `.v` extension).

    Raises:
        FileNotFoundError: If no testbench files matching the criteria are found.
    """
    # Determine testbench suffix based on post-synth flag.
    suffixes = ("_ps_tb.sv", "_ps_tb.v") if args.post_synth else ("_tb.sv", "_tb.v")

    # Collect all testbench files matching the suffix.
    testbench_names = [
        filename for filename in os.listdir(config.TESTS_DIR) if filename.endswith(suffixes)
    ]

    # If no post-synthesis testbenches are found, exit cleanly.
    if args.post_synth and not testbench_names:
        raise FileNotFoundError("No post-synthesis testbenches found in this directory.")

    # If no testbench files are found, raise an error.
    if not testbench_names:
        raise FileNotFoundError("No testbench files found in this directory.")

    # If `args.all` is True, return all testbench names without `.sv` or `.v` extension.
    if args.all:
        return [tb.rsplit('.', 1)[0] for tb in testbench_names]

    # If only one testbench file is found, return its name without the extension.
    if len(testbench_names) == 1:
        return [testbench_names[0].rsplit('.', 1)[0]]

    # If multiple testbenches are found, prompt the user to choose one.
    testbench_name = choose_from_list(
        files=testbench_names,
        prompt=f"Enter the number corresponding to your choice (1-{len(testbench_names)}): ",
        pre_prompt=f"Multiple testbench files found. Please choose one: "
    )

    # Return the selected testbench name without the extension.
    return [testbench_name.rsplit('.', 1)[0]]


def execute_test(test_name, args):
    """
    Executes a single test by first ensuring that all dependencies are compiled and then running the test.

    Args:
        test_name (str): The name of the testbench to execute (without the .v extension).
        args (argparse.Namespace): The parsed command-line arguments containing execution details.
        
    The function performs the following steps:
    1. Resolves the full file path for the testbench file.
    2. Finds all the dependencies required for compiling the testbench.
    3. Compiles the required files if necessary.
    4. Executes the testbench with the provided arguments.
    """    
    # Compile the necessary files (if needed) for the testbench.
    compile_files(test_name, args)

    # Run the actual test using the provided arguments.
    run_test(test_name, args)


def execute_tests(test_names, args):
    """
    Runs the testbenches in parallel using a ThreadPoolExecutor.
    
    Args:
        test_names (list): A list of testbench names to be executed.
        args (argparse.Namespace): The parsed command-line arguments containing execution details.
        
    This function uses a ThreadPoolExecutor to execute testbenches in parallel. It submits
    each test to the executor and waits for all the tests to complete.
    """
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = []
        for test_name in test_names:
            # The job to be submitted to the executor.
            job = None

            # Check the mode and submit the appropriate job.
            if args.mode == 3:
                # Submit task for viewing waveforms.
                job = executor.submit(view_waveforms, test_name, args)
            else:                                
                # Submit task for executing the test.
                job = executor.submit(execute_test, test_name, args)

            # Submit each job (either execute or view waveforms).
            futures.append(job)

        # Wait for all tests to complete and handle exceptions.
        for future in concurrent.futures.as_completed(futures):
            try:
                result = future.result()  # Get the result (if any)
            except Exception as e:
                # Handle errors during test execution
                print(f"Error during test execution: {e}")
                sys.exit(1)
