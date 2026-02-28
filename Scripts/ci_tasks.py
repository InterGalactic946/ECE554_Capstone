import os
import glob
import shutil
import config
import subprocess
from pathlib import Path


"""
This module provides CI utility functions for running tests across all valid
project directories using existing Makefile commands.

The flow is intentionally simple:
1. Discover valid project directories.
2. For each directory, run: make run c a
3. Save output log for that run in ci_logs/.
4. If failed, copy relevant logs into ci_logs/failed/<directory>/.
5. Run make clean c after each directory run.
6. Print pass/fail summary and return status code.
"""


def run_make(root_dir, make_args, selection_num, log_file):
    """
    Run one make command and inject selection number through stdin.

    Args:
        root_dir (str): Repository root directory.
        make_args (list[str]): Make arguments (for example: ["run", "c", "a"]).
        selection_num (int): 1-based directory selection number.
        log_file (str): Path to log file.

    Returns:
        int: Process return code.
    """
    # Build the make command.
    command = ["make", "-C", root_dir] + make_args

    # Provide directory selection for interactive prompt.
    selection_input = f"{selection_num}\n"

    # Execute command and append output to log file.
    with open(log_file, "a", encoding="utf-8") as file:
        result = subprocess.run(
            command,
            input=selection_input,
            text=True,
            stdout=file,
            stderr=subprocess.STDOUT
        )

    return result.returncode


def read_file(path):
    """
    Read file content safely.

    Args:
        path (str): File path.

    Returns:
        str: File content or empty string if unreadable.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as file:
            return file.read()
    except Exception:
        return ""


def copy_files(patterns, destination_dir, preferred_tokens=None):
    """
    Copy matching files into destination directory.

    If preferred_tokens are provided, files containing any preferred token are
    copied. If none match, the latest file is copied.

    Args:
        patterns (list[str]): Glob patterns.
        destination_dir (str): Destination directory.
        preferred_tokens (list[str] | None): Optional preferred tokens.

    Returns:
        int: Number of files copied.
    """
    # Collect all candidate files from provided patterns.
    candidates = []
    for pattern in patterns:
        candidates.extend(glob.glob(pattern))

    # Remove duplicates and sort deterministically.
    candidates = sorted(set(candidates))
    if not candidates:
        return 0

    # Copy preferred files first if requested.
    copied = 0
    preferred = []
    if preferred_tokens:
        for file_path in candidates:
            content = read_file(file_path)
            if any(token in content for token in preferred_tokens):
                preferred.append(file_path)

    if preferred:
        for file_path in preferred:
            shutil.copy2(file_path, destination_dir)
            copied += 1
        return copied

    # Fallback: copy latest file.
    latest = max(candidates, key=lambda file_path: os.path.getmtime(file_path))
    shutil.copy2(latest, destination_dir)
    return 1


def collect_failure_logs(project_dir, run_log_file, failed_dir):
    """
    Collect failure logs for one failed directory run.

    Args:
        project_dir (str): Project directory path.
        run_log_file (str): Make run output log file path.
        failed_dir (str): Destination failed-log directory.

    Returns:
        None
    """
    # Ensure destination exists. Do not copy run output log here because
    # it already exists in ci_logs/<directory>_run.log.
    Path(failed_dir).mkdir(parents=True, exist_ok=True)

    # Read run log to infer failure type.
    run_output = read_file(run_log_file)

    # Build log location patterns.
    compilation_patterns = [
        os.path.join(project_dir, "tests", "output", "logs", "compilation", "*.log"),
    ]
    transcript_patterns = [
        os.path.join(project_dir, "tests", "output", "logs", "transcript", "*.log"),
    ]

    # Decide which logs to copy based on failure message hints.
    comp_fail = (
        "make log c" in run_output
        or "Compilation failed" in run_output
        or "Compilation has errors" in run_output
    )
    runtime_fail = (
        "make log t" in run_output
        or "Test failed" in run_output
        or "ERROR" in run_output
        or "Running test failed" in run_output
    )

    if comp_fail:
        # Compilation failed: copy compilation logs.
        copy_files(compilation_patterns, failed_dir, preferred_tokens=["Error:"])
    elif runtime_fail:
        # Runtime failed: copy transcript logs.
        copy_files(transcript_patterns, failed_dir, preferred_tokens=["ERROR", "FAIL", "Unknown status"])
    else:
        # Unknown failure: copy both categories as fallback.
        copy_files(compilation_patterns, failed_dir, preferred_tokens=["Error:"])
        copy_files(transcript_patterns, failed_dir, preferred_tokens=["ERROR", "FAIL", "Unknown status"])


def run_ci_sweep():
    """
    Run CI sweep across all valid top-level project directories.

    This function intentionally uses Makefile commands directly so behavior
    exactly matches normal local usage.

    Returns:
        int: 0 if all directories pass, else 1.
    """
    # Discover valid project directories in prompt order.
    project_dirs = config.get_top_level_dirs()
    if not project_dirs:
        print(f"No valid project directories found under {config.ROOT_DIR}.")
        return 1

    # Prepare CI log directories.
    ci_log_dir = os.path.join(config.ROOT_DIR, "ci_logs")
    failed_log_dir = os.path.join(ci_log_dir, "failed")
    Path(ci_log_dir).mkdir(parents=True, exist_ok=True)
    Path(failed_log_dir).mkdir(parents=True, exist_ok=True)

    # Track summary counts.
    pass_count = 0
    fail_count = 0
    passed_dirs = []
    failed_dirs = []

    print(f"Discovered {len(project_dirs)} project directories.\n")

    # Run make commands for each directory selection.
    for idx, project_dir in enumerate(project_dirs, start=1):
        project_name = os.path.basename(project_dir)
        run_log_file = os.path.join(ci_log_dir, f"{project_name}_run.log")

        # Truncate run log file before each directory run.
        with open(run_log_file, "w", encoding="utf-8") as file:
            file.write("")

        print("============================================================")
        print(f"Running directory: {project_name} (selection {idx})")
        print("Command: make run c a")
        print(f"Log: {run_log_file}")
        print("============================================================")

        # Run tests for this directory.
        run_rc = run_make(
            root_dir=str(config.ROOT_DIR),
            make_args=["run", "c", "a"],
            selection_num=idx,
            log_file=run_log_file
        )

        if run_rc == 0:
            print(f"RESULT: PASS ({project_name})")
            pass_count += 1
            passed_dirs.append(project_name)
        else:
            print(f"RESULT: FAIL ({project_name})")
            fail_count += 1
            failed_dirs.append(project_name)
            collect_failure_logs(project_dir, run_log_file, os.path.join(failed_log_dir, project_name))

        # Always clean that same selected directory after run.
        clean_rc = run_make(
            root_dir=str(config.ROOT_DIR),
            make_args=["clean", "c"],
            selection_num=idx,
            log_file=run_log_file
        )
        if clean_rc != 0:
            print(f"WARNING: cleanup failed for {project_name}.")

        print("")

    # Print final summary.
    print("==================== CI SUMMARY ====================")
    print(f"Total directories: {len(project_dirs)}")
    print(f"Passed: {pass_count}")
    print(f"Failed: {fail_count}")
    print(f"Logs: {ci_log_dir}")
    print("====================================================")

    if passed_dirs:
        print("Passed directories:")
        for project_name in passed_dirs:
            print(f"  - {project_name}")

    if failed_dirs:
        print("Failed directories:")
        for project_name in failed_dirs:
            print(f"  - {project_name}")
        return 1

    return 0
