import os
import sys
import shutil
import config
import concurrent.futures


"""
This module provides a function to clean up generated files from the project directory.
It removes synthesis, output, and simulation files to reset the project state.
The cleanup can be performed for all top-level project directories or just the current test directory.
The cleanup process is done in parallel using threading for efficiency.
If `all` is True, cleanup is performed concurrently across all discovered top-level project directories.
If `all` is False, only the current TEST_DIR is cleaned.
"""

def clean_project(all):
    """
    Clean up generated files from the project directory, optionally in parallel.

    This function deletes synthesis, output, and simulation files to reset the project state.

    If `all` is True, cleanup is performed concurrently across all discovered top-level project directories.

    Otherwise, only the current TEST_DIR is cleaned.

    Arguments:
        all (bool): If True, cleans all project directories in parallel. If False, only cleans TEST_DIR.
    
    Returns:
        None
    """
    if all:
        print("Cleaning up generated files in all top-level directories...")
        try:
            # Dynamically discover all valid project directories to clean.
            top_level_dirs = config.get_top_level_dirs()

            # Exit gracefully if no valid project directories were found.
            if not top_level_dirs:
                print("No valid project directories found to clean.")
                return

            # Use thread pool to clean directories concurrently
            with concurrent.futures.ThreadPoolExecutor() as executor:
                executor.map(_clean_paths_in_dir, top_level_dirs)
        except OSError as e:
            # Exit if any directory fails to clean
            print(f"Error during cleanup: {e}")
            sys.exit(1)
    else:
        # Clean only the current test directory.
        print(f"Cleaning up generated files in {os.path.basename(config.TEST_DIR)}...")
        _clean_paths_in_dir(config.TEST_DIR)

    print("Cleanup complete.")


def _clean_paths_in_dir(base_dir):
    """
    Helper function to remove generated files from a given base directory.
    Cleans synthesis, test VCD, outputs, and work directories/files.

    Args:
        base_dir (str): The base directory to clean up.

    Raises:
        OSError: If there is an error while removing files or directories.

    Returns:
        None
    """
    paths_to_remove = [
        os.path.join(base_dir, 'synthesis'),                           # Synthesis output directory
        os.path.join(base_dir, 'transcript'),                          # Transcript log file
        os.path.join(base_dir, 'dump.fsdb'),                           # FSDB waveform dump file
        os.path.join(base_dir, 'vsim_stacktrace.vstf'),                # Stack trace file from simulation
        os.path.join(base_dir, 'dump.vcd'),                            # VCD waveform dump file
        os.path.join(base_dir, 'tests', 'output'),                     # Directory containing output logs and traces
        os.path.join(base_dir, 'tests', 'output', 'verilogsim.log'),   # Simulation log file
        os.path.join(base_dir, 'tests', 'output', 'verilogsim.trace'), # Simulation trace file
        os.path.join(base_dir, 'tests', 'WORK'),                       # Work directory used by simulator
    ]

    # Remove the build directories and files.
    shutil.rmtree(os.path.join(base_dir, 'build'), ignore_errors=True)

    for path in paths_to_remove:
        if os.path.exists(path):
            try:
                if os.path.isdir(path):
                    shutil.rmtree(path)  # Remove entire directory and its contents
                else:
                    os.remove(path)     # Remove single file
            except Exception as e:
                # Raise an OSError with context if removal fails
                raise OSError(f"[{os.path.basename(base_dir)}] Failed to remove {path}: {e}") from e
