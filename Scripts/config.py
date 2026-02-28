import os
from pathlib import Path
from file_utils import choose_from_list

"""
This script sets up the configuration for a project by defining various constants and variables.
It includes paths for different directories such as root, scripts, phases, extra credit, test programs,
and output directories. It also defines a function to set the test directory and other related paths.
Additionally, it sets up the environment for running test programs and handling output files.
"""

# Constants for directory paths.
ROOT_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = os.path.join(ROOT_DIR, "Scripts")
TEST_PROGRAMS_DIR = os.path.join(ROOT_DIR, "TestPrograms")

# Required subdirectories to classify a root-level directory as a valid project directory.
REQUIRED_SUBDIRS = ("designs", "tests")

# Dynamic variables to be set later.
TEST_DIR = None
BUILD_DIR = None
DEPENDENCY_GRAPH = None
CELL_LIBRARY_PATH = None
TESTS_DIR = None
DESIGNS_DIR = None
PACKAGES_DIR = None
TEST_FILE = None
OUTPUTS_DIR = None

WAVE_CMD_DIR = None
OUTPUT_DIR = None
WAVES_DIR = None
LOGS_DIR = None
TRANSCRIPT_DIR = None
COMPILATION_DIR = None
SYNTHESIS_DIR = None
WORK_DIR = None


def get_top_level_dirs():
    """
    Discover all valid top-level project directories under ROOT_DIR.

    A directory is considered valid if:
    - It is an immediate child directory under ROOT_DIR.
    - It is not a hidden directory (name starting with '.').
    - It is not a utility folder like Scripts/ or TestPrograms/.
    - It contains all required project subdirectories listed in REQUIRED_SUBDIRS.

    Returns:
        list: A sorted list of absolute paths for valid project directories.
    """
    # List to collect valid top-level project directories.
    top_level_dirs = []

    # Iterate through immediate children in ROOT_DIR.
    for child in ROOT_DIR.iterdir():
        # Skip non-directories.
        if not child.is_dir():
            continue

        # Skip hidden directories and utility directories.
        if child.name.startswith(".") or child.name in ["Scripts", "TestPrograms"]:
            continue

        # Keep only directories that have required project subdirectories.
        if all((child / sub_dir).is_dir() for sub_dir in REQUIRED_SUBDIRS):
            top_level_dirs.append(str(child.resolve()))

    # Return directories in deterministic order for stable user prompts.
    return sorted(top_level_dirs, key=lambda path: os.path.basename(path).lower())


def choose_directory(args):
    """
    List valid directories in the current directory and prompt the user to choose one.

    Args:
        args (Namespace): Parsed command-line arguments for determining the context of directory usage.

    Returns:
        str: The selected subdirectory's path.
    """
    # Don't show the prompt if both --all and --clean flags are set.
    if args.all and args.clean:
        return None

    # Determine the prompt message based on the args flags
    if args.clean:
        prompt_message = "Available directories to clean: "
    elif args.check:
        prompt_message = "Enter the number of the directory to check Verilog design files: "
    elif args.logs == "c":
        prompt_message = "Enter the number of the directory to view compilation logs: "
    elif args.logs == "t":
        prompt_message = "Enter the number of the directory to view transcript logs: "
    elif args.logs == "o":
        prompt_message = "Enter the number of the directory to view top level logs: "
    elif args.mode == 3:
        prompt_message = "Enter the number of the directory to view waveforms: "
    elif args.synth:
        prompt_message = "Enter the number of the directory to run synthesis: "
    elif args.post_synth:
        prompt_message = "Enter the number of the directory to run post synthesis tests: "
    else:
        prompt_message = "Enter the number of the directory to run tests: "

    # Dynamically discover all valid top-level project directories.
    top_level_dirs = get_top_level_dirs()

    # Exit gracefully if no valid project directories were found.
    if not top_level_dirs:
        raise FileNotFoundError(
            f"No valid project directories found in '{ROOT_DIR}'. Expected each directory to contain: {', '.join(REQUIRED_SUBDIRS)}."
        )

    # Display the prompt message after the top-level directory is selected but before subdirectory selection.
    selected_top_dir = choose_from_list(
        pre_prompt=prompt_message,
        files=top_level_dirs,
        prompt=f"Enter the number of the directory to choose: (1-{len(top_level_dirs)}): "
    )

    # Return the selected directory path
    return selected_top_dir


def setup_directories(name):
    """
    Ensure necessary directories exist for output, logs, and waveforms, and set up the environment.

    This function creates all required directories, such as the output, logs, and waveform directories. 
    If the directories already exist, they are not recreated. The function also validates that the 
    specified test directory exists before proceeding.

    Args:
        name (str): The name of the testbench directory to set up, typically corresponding to a test.

    Raises:
        FileNotFoundError: If the specified test directory does not exist.
        OSError: If there is an error while creating the required directories.

    Returns:
        None: This function does not return any value. It only ensures that the directories are set up 
              and ready for use.
    """        
    if not name:
        return
    
    # Modifying the global directory variables declared above.
    global TEST_DIR, OUTPUTS_DIR, TESTS_DIR, CELL_LIBRARY_PATH, DESIGNS_DIR, PACKAGES_DIR, TEST_PROGRAMS_DIR, WAVE_CMD_DIR, OUTPUT_DIR, WAVES_DIR, LOGS_DIR, TRANSCRIPT_DIR, COMPILATION_DIR, SYNTHESIS_DIR, WORK_DIR, BUILD_DIR, DEPENDENCY_GRAPH
    
    # Set the path for the main test directory using the provided 'name'.
    TEST_DIR = os.path.join(ROOT_DIR, name)

    # Set the path for the outputs directory.
    OUTPUTS_DIR = os.path.join(TEST_DIR, "outputs")

    # Set the path for the directory containing design files.
    DESIGNS_DIR = os.path.join(TEST_DIR, "designs")

    # Set the path for the directory containing package files.
    PACKAGES_DIR = os.path.join(TEST_DIR, "packages")

    # Define the path for the synthesis directory.
    SYNTHESIS_DIR = os.path.join(TEST_DIR, "synthesis")

    # Set the path for the directory containing testbench files.
    TESTS_DIR = os.path.join(TEST_DIR, "tests")

    # Set the cell library path for post synthesis simulation.
    CELL_LIBRARY_PATH = os.path.join(TESTS_DIR, "SAED32_lib")

    # Verify that the provided test directory exists.
    if not os.path.exists(TEST_DIR):
        # If not, raise a FileNotFoundError.
        raise FileNotFoundError(f"Directory '{name}' does not exist.")

    # Define the paths for directories that depend on the test directory (TEST_DIR).
    WAVE_CMD_DIR = os.path.join(TESTS_DIR, "add_wave_commands")  # Directory for waveform command files.
    OUTPUT_DIR = os.path.join(TESTS_DIR, "output")       # Output directory for the test results.
    WAVES_DIR = os.path.join(OUTPUT_DIR, "waves")       # Directory for waveform files.
    LOGS_DIR = os.path.join(OUTPUT_DIR, "logs")         # Directory for log files.
    TRANSCRIPT_DIR = os.path.join(LOGS_DIR, "transcript")  # Directory for transcript logs.
    COMPILATION_DIR = os.path.join(LOGS_DIR, "compilation")  # Directory for compilation logs.
    WORK_DIR = os.path.join(TESTS_DIR, "WORK")           # Directory for temporary work files.
    BUILD_DIR = os.path.join(TEST_DIR, "build")          # Build directory for compilation files.

    # Ensure that all the necessary directories are created, if they do not exist.
    directories = [BUILD_DIR, WAVE_CMD_DIR, OUTPUT_DIR, WAVES_DIR, LOGS_DIR, TRANSCRIPT_DIR, COMPILATION_DIR, SYNTHESIS_DIR, WORK_DIR]
    for directory in directories:
        # 'mkdir' ensures that the directory and any necessary parent directories are created.
        # 'exist_ok=True' prevents an error if the directory already exists.
        Path(directory).mkdir(parents=True, exist_ok=True)
    
    # Dependency graph for the modules in the folder.
    DEPENDENCY_GRAPH = Path(BUILD_DIR) / "dependency_graph.json"    
  
    # Change the current working directory to the test directory to execute the tests.
    os.chdir(TEST_DIR)
