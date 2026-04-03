import os
import re
import sys
import config
import subprocess
from log_utils import check_logs

"""
This module provides utility functions for running simulations using ModelSim/QuestaSim.
It includes functions to find signals in the design hierarchy, generate waveform commands,
and run simulations in different modes (command-line, GUI).
"""


def find_signals(signal_names, test_name):
    """
    Find the full hierarchy paths for the given signal names.

    This function uses the ModelSim/QuestaSim `vsim` command to search for signals in the design hierarchy.
    If a full path is provided for a signal, it is directly added to the result.
    Otherwise, the function searches for signals matching the provided name and resolves their full paths.

    Args:
        signal_names (list of str): List of signal names to search for. Full paths or partial names are accepted.
        test_name (str): The test name used to determine the required signals.

    Returns:
        list of str: A list of full hierarchy paths for the provided signals. If a signal cannot be resolved,
                     it is not included in the returned list.

    Raises:
        subprocess.CalledProcessError: If the `vsim` command fails during execution.
    """
    # List to store resolved signal paths.
    signal_paths = []

    for signal in signal_names:
        # If the signal name already includes a full path, add it directly to the list.
        if "/" in signal:
            signal_paths.append(signal)
            continue

        try:
            # Run the vsim command to search for signals matching the provided name.
            result = subprocess.run(
                f"vsim -c ./tests/WORK/{test_name}.{test_name} -do 'find signals /{test_name}/{signal}* -recursive; quit -f;'",
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

            # Flag to indicate if the signal was found.
            found_signal = False 

            # Process the vsim output to extract signal paths.
            for part in result.stdout.split():
                # Skip irrelevant lines and comments in the vsim output.
                if part.startswith("#") or not part.strip() or part.strip() in ["//", "-access/-debug"]:
                    continue

                # Check if the output line contains a valid path
                if "/" in part:
                    # Match the last component of the path with the signal name
                    if part.strip().split("/")[-1] == signal and not found_signal:
                        signal_paths.append(part.strip())
                        found_signal = True  # Avoid duplicate entries for the same signal.
        except subprocess.CalledProcessError as e:
            # Handle errors from the vsim command and provide feedback.
            print(f"{test_name}: Error finding signal {signal}: {e.stderr.decode('utf-8')}")
            sys.exit(1)

    return signal_paths


def get_wave_command(test_name, args):
    """
    Generate or retrieve the waveform command for a given testbench.

    Args:
        test_name (str): The name of the testbench, used to locate or generate signal wave commands.
        args (argparse.Namespace): Command-line arguments, including flags to modify behavior.

    Returns:
        str: A single-line string of waveform commands for the selected signals.

    Description:
        - Checks if a waveform command file already exists for the testbench.
        - Prompts the user to confirm using the existing commands or to provide new signals.
        - Locates full signal paths and generates a `wave_command.txt` file if necessary.
        - Returns the waveform command string for simulation.
    """
    # Define the wave command file path.
    wave_command_file = os.path.join(config.WAVE_CMD_DIR, f"{test_name}_wave_command.txt")

    # Check if the wave command file exists.
    if os.path.exists(wave_command_file):
        # Read the existing wave command from the file.
        with open(wave_command_file, "r") as file:
            add_wave_command = file.read().strip()

        if not args.all:
            print(f"{test_name}: Wave command file already exists.")
            user_choice = input("Would you like to use the existing signals? (y/n): ").strip().lower()

            if user_choice == "y":
                return add_wave_command
        else:
            return add_wave_command

    # Prompt the user for new signals if no file exists or they choose to modify.
    print(f"{test_name}: Please enter the signals to add (comma-separated):")
    user_input = input("Signals: ")

    # Parse the user input into a list of signals.
    signals_to_use = [signal.strip() for signal in user_input.split(",") if signal.strip()]
    
    # If user enters no signals, proceed without add-wave commands.
    if not signals_to_use:
        if not args.all:
            print(f"{test_name}: No signals entered. Proceeding without add-wave commands.")
        return ""

    # Find full hierarchy paths for the selected signals.
    signal_paths = find_signals(signals_to_use, test_name)

    if not signal_paths:
        print(f"{test_name}: No signals found. Exiting...")
        sys.exit(1)

    # Generate a single-line waveform command.
    add_wave_command = " ".join([f"add wave {signal};" for signal in signal_paths])

    # Save the command to a file.
    with open(wave_command_file, "w") as file:
        file.write(add_wave_command)

    return add_wave_command


def get_gui_command(test_name, log_file, args):
    """
    Generate the simulation command for GUI-based waveform viewing.

    Args:
        test_name (str): The name of the testbench, used to locate waveform files.
        log_file (str): Path to the log file for saving simulation output.
        args (argparse.Namespace): Command-line arguments, including simulation mode.

    Returns:
        str: The complete simulation command string for GUI-based waveform generation.

    Description:
        - Constructs a GUI simulation command with flags to generate waveforms.
        - Retrieves or generates waveform commands for signals.
        - Adds options to save waveform formats and logs.
        - Adjusts command to quit after simulation based on the mode.
    """
    # Define paths for waveform files.
    wave_file = os.path.join(config.WAVES_DIR, f"{test_name}.wlf")
    wave_format_file = os.path.join(config.WAVES_DIR, f"{test_name}.do")

    # Get the waveform commands for signal addition.
    add_wave_command = get_wave_command(test_name, args)

    # Construct the simulation command based on post-synthesis.
    sim_command = (
        f"vsim -wlf {wave_file} ./tests/WORK/{test_name}.{test_name} -logfile {log_file} -voptargs='+acc' "
        f"-do '{add_wave_command} run -all; write format wave -window .main_pane.wave.interior.cs.body.pw.wf {wave_format_file}; log -flush /*;'"
    )

    if args.post_synth:
        sim_command = (
            f"vsim -wlf {wave_file} ./tests/WORK/{test_name}.{test_name} -logfile {log_file} -t ns "
            f"-Lf {config.CELL_LIBRARY_PATH} -voptargs='+acc' -do '{add_wave_command} run -all; "
            f"write format wave -window .main_pane.wave.interior.cs.body.pw.wf {wave_format_file}; "
            f"log -flush /*;'"
        )

    # Ensure the simulation quits after completion for certain modes.
    if args.mode in (0, 1):
        sim_command = sim_command[:-1] + " quit -f;'"

    return sim_command


def save_wave_cmds(test_name, log_file):
    """
    After GUI run (mode 2), extract add-wave commands from transcript,
    union with existing wave command file, and save.
    
    Args:
        test_name (str): The name of the testbench, used to locate waveform files.
        log_file (str): Path to the log file for saving simulation output.

    Returns:
        None:
    """
    wave_command_file = os.path.join(config.WAVE_CMD_DIR, f"{test_name}_wave_command.txt")

    # If transcript doesn't exist, nothing to do.
    if not os.path.exists(log_file):
        return None

    # Process the file.
    with open(log_file, "r") as f:
        content = f.read()

    # 1) Extract add wave commands from transcript (including multiline "\" cases).
    transcript_cmds = []
    lines = content.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        i += 1

        if line.startswith("#"):
            line = line[1:].strip()

        if not line:
            continue

        m = re.search(r"(add\s+wave\b.*)", line, flags=re.IGNORECASE)
        if not m:
            continue

        cmd = m.group(1).strip()

        # Keep only first command segment before next ';' commands like run -all.
        if ";" in cmd:
            cmd = cmd.split(";", 1)[0].strip()

        # Join continuation lines.
        while cmd.endswith("\\") and i < len(lines):
            cmd = cmd[:-1].strip()
            nxt = lines[i].strip()
            i += 1
            if nxt.startswith("#"):
                nxt = nxt[1:].strip()
            cmd = f"{cmd} {nxt}".strip()

        # Normalize to project style: add wave <signal>;
        parts = cmd.split()
        signal = ""
        for tok in reversed(parts):
            if "/" in tok:
                signal = tok
                break
        if not signal:
            continue
        if signal.lower().startswith("sim:/"):
            signal = signal[4:]

        transcript_cmds.append(f"add wave {signal};")

    # De-duplicate transcript commands by signal, preserving order.
    seen = set()
    transcript_unique = []
    for cmd in transcript_cmds:
        key = re.sub(r"^\s*add\s+wave\s+", "", cmd, flags=re.IGNORECASE).rstrip(";").strip().lower()
        if key and key not in seen:
            seen.add(key)
            transcript_unique.append(cmd)

    # 2) Read existing commands if file exists.
    existing_unique = []
    if os.path.exists(wave_command_file):
        with open(wave_command_file, "r") as f:
            existing_content = f.read()

        existing_raw = re.findall(r"(add\s+wave\b[^;]*;)", existing_content, flags=re.IGNORECASE)
        for raw in existing_raw:
            parts = raw.strip().rstrip(";").split()
            signal = ""
            for tok in reversed(parts):
                if "/" in tok:
                    signal = tok
                    break
            if not signal:
                continue
            if signal.lower().startswith("sim:/"):
                signal = signal[4:]

            normalized = f"add wave {signal};"
            key = signal.lower()
            if key not in seen:
                seen.add(key)
                existing_unique.append(normalized)

    # 3) Union with transcript preferred first.
    final_cmds = transcript_unique + existing_unique

    # If transcript had nothing and existing file had nothing, do nothing.
    if not final_cmds:
        return None

    # Write the new wave command file.
    with open(wave_command_file, "w") as f:
        f.write(" ".join(final_cmds))

    return None


def run_simulation(test_name, log_file, args):
    """
    Run the simulation for a specific testbench based on the selected mode.

    Args:
        test_name (str): The name of the testbench, excluding the `.v` extension.
        log_file (str): Path to the log file for saving simulation output.
        args (argparse.Namespace): Command-line arguments, including the simulation mode.

    Returns:
        str: The result of the simulation ("success", "error", "warning", or "unknown").

    Description:
        - Mode 0: Command-line simulation without GUI.
        - Mode 1: GUI simulation with waveform saving.
        - Mode 2: Full GUI mode for debugging.
        - Constructs the appropriate simulation command and executes it.
        - Logs simulation output and returns the status based on log file checks.
    """
    def form_sim_libs():
        """
        Form the simulation libraries argument for the vsim command by checking the SIM_LIBRARY_PATH directory.
        
        Returns:
            str: A string containing the -L arguments for each valid library found in the SIM_LIBRARY_PATH directory.
        """
        sim_libs_arg = ""
        if os.path.exists(config.SIM_LIBRARY_PATH):
            for item in os.listdir(config.SIM_LIBRARY_PATH):
                # Get the library path.
                item_path = os.path.join(config.SIM_LIBRARY_PATH, item)
                
                # If it's a directory, assume it's a compiled library and add it to the sim libs argument.
                if os.path.isdir(item_path):
                    sim_libs_arg += f"-L {item_path} "
        
        # Return the formatted argument string for the simulation command.
        return sim_libs_arg.strip()
    
    # Define paths for the wave file.
    wave_file = os.path.join(config.WAVES_DIR, f"{test_name}.wlf")
        
    if args.mode == 0:
        if not args.all:
            print(f"{test_name}: Running in command-line mode...")
        sim_command = f"vsim -c ./tests/WORK/{test_name}.{test_name} -wlf {wave_file} -logfile {log_file} -do 'run -all; log -flush /*; quit -f;'"

        # Modify the command for post synthesis.
        if args.post_synth or test_name.endswith("ps_tb"):
            sim_command = f"vsim -c ./tests/WORK/{test_name}.{test_name} -wlf {wave_file} -logfile {log_file} -t ns " \
                    f"-Lf {config.CELL_LIBRARY_PATH} -do 'run -all; log -flush /*; quit -f;'"
                    
        # Modify the command for IP simulation.
        if args.ip:
            sim_command = f"vsim -c ./tests/WORK/{test_name}.{test_name} -wlf {wave_file} -logfile {log_file} -t ns "\
                    f"{form_sim_libs()} -do 'run -all; log  -flush /*; quit -f;'"       
    else:
        if args.mode == 1:
            if not args.all:
                print(f"{test_name}: Saving waveforms and logging to file...")
        elif args.mode == 2:
            if not args.all:
                print(f"{test_name}: Running in GUI mode...")

        sim_command = get_gui_command(test_name, log_file, args)

    # Execute the simulation command.
    with open(log_file, 'w') as log_fh:
        try:
            subprocess.run(sim_command, shell=True, stdout=log_fh, stderr=subprocess.PIPE, check=True)
        except subprocess.CalledProcessError as e:
            if args.all:
                print(f"{test_name}: Running test failed with error {e.returncode}. Run 'make log t' for details. {e.stderr.decode('utf-8')}")
            else:
                # Print log file contents in case of an error when running a single test.
                with open(log_file, 'r') as log_fh:
                    print(f"\n===== Running {test_name} failed with the following errors =====\n")
                    print(log_fh.read())
            sys.exit(1)
    
    # Rename simulation files if applicable.
    if config.TEST_FILE is not None:
        rename_sim_files()
    
    # Save the waves added for future use.
    if args.mode == 2:
        save_wave_cmds(test_name, log_file)        

    return check_logs(log_file, "t")


def rename_sim_files():
    """
    Renames the 'verilogsim.trace' and 'verilogsim.log' files by appending the base name 
    of the input file.

    Returns:
        None: Renames the files in place.
    """
    # Define paths for the simuation files.
    trace_file = os.path.join(config.OUTPUTS_DIR, f"verilogsim.trace")
    log_file = os.path.join(config.OUTPUTS_DIR, f"verilogsim.log")

    # Create new file names by appending the base name.
    new_trace_file = os.path.join(config.OUTPUTS_DIR, f"{config.TEST_FILE}_verilogsim.trace.txt")
    new_log_file = os.path.join(config.OUTPUTS_DIR, f"{config.TEST_FILE}_verilogsim.log.txt")

    # Rename the trace file if it exists.
    if os.path.exists(trace_file):
        os.rename(trace_file, new_trace_file)

    # Rename the log file if it exists.
    if os.path.exists(log_file):
        os.rename(log_file, new_log_file)


def run_test(test_name, args):
    """
    Run a specific testbench by compiling and executing the simulation.

    Args:
        test_name (str): The name of the testbench, excluding the `.v` extension.
        args (argparse.Namespace): Command-line arguments, including simulation mode.

    Returns:
        None: Prints the test result status to the console.

    Description:
        - Executes the simulation using `run_simulation`.
        - Handles various results ("success", "error", "warning", "unknown").
        - For failures, provides debugging options and logs output.
    """
    log_file = os.path.join(config.TRANSCRIPT_DIR, f"{test_name}_transcript.log")

    # Run the simulation and get the result.
    result = run_simulation(test_name, log_file, args)

    # Output the test result based on the status.
    if result == "success":
        print(f"{test_name}: YAHOO!! All tests passed.")
    elif result == "error":
        if args.mode == 0:
            if args.all:
                print(f"{test_name}: Test failed. Run 'make log t' for details. Saving waveforms for later debug...")
            else:
                # Print log file contents in case of an error when running a single test.
                with open(log_file, 'r') as log_fh:
                    print(f"\n===== Running {test_name} failed with the following errors =====\n")
                    print(log_fh.read())
                    print(f"{test_name}: Saving waveforms for later debug...")

            debug_command = get_gui_command(test_name, log_file, args)
            with open(log_file, 'w') as log_fh:
                try:
                    subprocess.run(debug_command, shell=True, stdout=log_fh, stderr=subprocess.PIPE, check=True)
                except subprocess.CalledProcessError as e:
                    if args.all:
                        print(f"{test_name}: Running test failed with error {e.returncode}. Run 'make log t' for details. {e.stderr.decode('utf-8')}")
                    else:
                        # Print log file contents in case of an error when running a single test.
                        with open(log_file, 'r') as log_fh:
                            print(f"\n===== Running {test_name} failed with the following errors =====\n")
                            print(log_fh.read())
                    sys.exit(1)
        elif args.mode == 1:
            print(f"{test_name}: Test failed. Run 'make log t' for details.")
    elif result == "warning":
        print(f"{test_name}: Test completed with warnings. Run 'make log t' for details.")
    elif result == "unknown":
        print(f"{test_name}: Unknown status. Run 'make log t' for details.")


def view_waveforms(test_name, args):
    """
    View previously saved waveforms for a specific testbench.

    Args:
        test_name (str): The name of the testbench, excluding the `.v` extension.
                         Used to locate the corresponding waveform and simulation files.
        args (argparse.Namespace): Command-line arguments containing the `all` flag to 
                                    determine if messages should be printed for individual tests.

    Returns:
        None: This function does not return a value but executes a simulator command to 
              view the saved waveforms for the specified testbench.

    Description:
        - Changes the current directory to the waveform directory (`WAVES_DIR`).
        - Opens a transcript file specific to the testbench to log output.
        - Constructs and executes a simulator command to load the saved waveform (`.wlf`)
          and associated script (`.do` file).
        - Handles errors gracefully if the simulation command fails, providing feedback
          to the user and exiting with an appropriate error code.
    """
    # Change to the waveforms directory to access saved waveform files.
    os.chdir(config.WAVES_DIR)

    # View the saved waveforms by invoking the simulator.
    with open(f"{test_name}_transcript", 'w') as transcript:
        if not args.all:
            print(f"{test_name}: Viewing saved waveforms...")
        sim_command = f"vsim -view {test_name}.wlf -do {test_name}.do;"
        try:
            subprocess.run(
                sim_command,
                shell=True,
                stdout=transcript,
                stderr=subprocess.PIPE,
                check=True
            )
        except subprocess.CalledProcessError as e:
            # Print error details and exit if the command fails.
            if args.all:
                print(f"{test_name}: Viewing waveforms failed with error {e.returncode}. {e.stderr.decode('utf-8')}")
            else:
                # Print log file contents in case of an error when running a single test.
                with open(f"{test_name}_transcript", 'r') as transcript:
                    print(f"\n===== Viewing waveforms for {test_name} failed with the following errors =====\n")
                    print(transcript.read())
            sys.exit(1)