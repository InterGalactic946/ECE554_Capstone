import os
import sys
import subprocess
import config
from file_utils import choose_from_list

"""
This module provides utility functions for assembling WISC-S25 assembly files.
It includes functions to list available assembly files, prompt the user for selection,
and run the assembler script to generate a memory image.
"""


def assemble():
    """
    Lists all WISC-S25 assembly files in the TestPrograms directory, prompts the user to select one, 
    and then runs `perl ./Scripts/assembler.pl <infile> > TESTS_DIR/instructions.img` to assemble it.

    The function ensures the TESTS_DIR exists, provides an interactive selection for the user, 
    and executes the assembler script with error handling.

    Raises:
        SystemExit: If no assembly files are found or if the assembly process fails.
    """
    # Set the input file as the test file chosen
    global TEST_FILE

    # Retrieve all valid assembly files in the directory
    asm_files = [f for f in os.listdir(config.TEST_PROGRAMS_DIR) if f.endswith(".s") or f.endswith(".list")]

    # Prompt the user to select an assembly file
    selected_file = choose_from_list(pre_prompt="Available WISC-S25 Assembly Files:", files=asm_files, prompt=f"Select a file to assemble (1-{len(asm_files)}): ")

    # Construct the full path for the input file and output files
    infile = os.path.join(config.TEST_PROGRAMS_DIR, selected_file)
    assembler_out = os.path.join(config.TESTS_DIR, "instructions.img")
    outfile = os.path.join(config.TESTS_DIR, "loadfile_all.img")

    # Construct the command to run the assembler and store image to temporary file
    command = f"perl {config.SCRIPTS_DIR}/assembler.pl {infile} > {assembler_out}"

    # Execute the assembler command with error handling
    try:
        result = subprocess.run(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"\n===== Error assembling file {os.path.basename(infile)} =====")
        error_message = e.stderr.decode('utf-8').replace("\n", " ").strip()
        print(f"{error_message}")
        sys.exit(1)  # Exit the script with an error code

    # Parse the assembler output and generate the full memory image
    with open(assembler_out, 'r') as f:
        assembled_lines = [line.strip()[:4] for line in f.readlines()]

    # Generate full memory image (65536 lines)
    full_memory = assembled_lines + ["0000"] * (65536 - len(assembled_lines))

    # Write to the final output file
    with open(outfile, "w") as f:
        f.write('\n'.join(full_memory) + '\n')

    # Remove the instructions.img file after use
    os.remove(assembler_out)

    # Set the global TEST_FILE.
    config.TEST_FILE = os.path.splitext(os.path.basename(infile))[0]