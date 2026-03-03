# **Acoustic Camera (Digital Logic Design) Capstone Project**

## **Overview**

The **Acoustic Camera Project** builds an FPGA-based acoustic camera that localizes sound sources with a 64-element MEMS microphone array and overlays a real-time intensity heatmap onto a live USB camera feed. It is aimed at applications like indoor gas-leak detection, where many leaks emit ultrasonic sound that humans cannot hear but the system can detect and visualize.

The complete pipeline captures synchronized multi-channel audio, runs parallel DFT/frequency filtering, computes phase and time-difference cues for localization, and generates an acoustic intensity map. A hardware video engine then composites that map onto incoming camera frames so users can directly see where sound energy is concentrated.

A custom out-of-order RISC-V processor serves as the system control plane: it configures accelerators, applies user-selected frequency/amplitude settings, manages dataflow between subsystems, and coordinates runtime operation. This split between programmable RISC-V control and dedicated RTL accelerators provides both flexibility and the throughput needed for real-time 64-channel acoustic imaging.

---

## **Project Structure (Current)**

```text
/ECE5554_Capstone
├── RISC-V/                    # Directory containing files for a 5-stage in-order RISC-V CPU with dynamic branch prediction and caches
│   ├── designs/               # Directory containing pre-synthesis design files
│   ├── outputs/               # Directory containing top level generated test output files (optional)
│   ├── packages/              # Directory containing package files for the design or testbenches (optional)
│   └── tests/                 # Directory containing all related testbench files used for testing
├── Scripts/                   # Directory containing scripts for automating testing tasks
├── TestPrograms/              # Directory containing assembly test files to load into the CPU
├── Makefile                   # Makefile for automating tasks
```

---

## **Dependencies**

- **Python 3.x**: Required to run the `execute_tasks.py` script.
- **Make**: For running the Makefile commands.
- **Verilog Simulator**: QuestaSim (vsim) which is capable for running Verilog tests.

---

## **Setup**

1. Clone the repository to your local machine:
   ```bash
   git clone https://github.com/InterGalactic946/ECE554_Capstone.git
   cd ECE554_Capstone/
   ```

2. Ensure that Python 3 and Make are installed on your system:
   - Python 3: [Installation Guide](https://www.python.org/downloads/)
   - Make: [Installation Guide](https://www.gnu.org/software/make/)

3. Install required Python dependencies (if needed):
   ```bash
   pip install <dependencies>
   ```

4. Consider running the `generate_starter.py` script via the Makefile to create initial design and testbench files:
   ```bash
   make start
   ```

5. For running GUI based simulations, ensure that you have a compatible X11 server or graphical environment set up, eg. XQuartz for macOS or MobaXterm for Windows
   to connect to the CAE machines where simulations will be run. Refer to the Environment Setup Guide in the project drive for more details.

---

# **Makefile for Simulation, Starters, Logs, and CI**

This Makefile is designed to streamline the process of running simulations, generating starter code, viewing logs, and running CI sweeps. Below are the available targets and their respective usage instructions.

---

## **Table of Contents**
1. [Run Simulations](#run-simulations)
2. [Generate Starters](#generate-starters)
3. [View Logs](#view-logs)
4. [Run CI-Sweep](#run-ci-sweep)
5. [Clean Directory](#clean-directory)

---

## **Run Simulations**
Executes testbenches in different modes (CMD, GUI, save waveforms) in a selected directory.

### Usage:
```bash
make run
make run <mode> <args>
```

### Modes:
- `v` - View waveforms in GUI mode
- `g` - Run in GUI mode
- `s` - Save waveforms
- `c` - Run in CMD mode

### Args:
- `a`  - All tests
- `as` - Assemble a test file

### Examples:
1. Run all tests in CMD mode:
   ```bash
   make run
   ```
2. Run all tests and save waveforms:
   ```bash
   make run s a
   ```
3. Run a specific test in GUI mode:
   ```bash
   make run g
   ```
4. Run a specific test after assembly in CMD mode:
   ```bash
   make run c as
   ```

---

## **Generate Starters**
Generates starter RTL and/or testbench files with minimal prompts (project, module name, optional description/ports).

### Usage:
```bash
make start
make start d
make start t
```

### Modes:
- `make start`   - Generate both DUT and testbench starter files
- `make start d` - Generate DUT starter file only
- `make start t` - Generate testbench starter file only

### Examples:
1. Generate both DUT and testbench starters:
   ```bash
   make start
   ```
2. Generate only a DUT starter:
   ```bash
   make start d
   ```
3. Generate only a testbench starter:
   ```bash
   make start t
   ```

---

## **View Logs**
Displays logs for top level outputs, compilation, or test transcripts from a selected directory.

### Usage:
```bash
make log <log_type>
```
### Log Types:
1. **Top Level Logs (`o`)**
   - Example:
      ```bash
      make log o
      ```
2. **Compilation Logs (`c`)**
   - Example:
      ```bash
      make log c
      ```
3. **Test Transcripts (`t`)**
   - Example:
      ```bash
      make log t
      ```

---

## **Other Useful Commands**
Commands to "kill" vsim on numerous spawned instances and check design files.

### Usage:
```bash
make kill
make check
```

### Examples:
1. This will kill all currently spawned instances of vsim to give a fresh start:
   ```bash
   make kill
   ```
2. This will check all design files of a selected directory to be compliant for synthesis:
   ```bash
   make check
   ```

---

## **Run CI-Sweep**
Runs a comprehensive CI sweep that includes running all tests, viewing logs, and collecting files in one command.

### Usage:
```bash
make ci
```

---

## **Clean Directory**
Removes generated files to clean up the workspace in all directories.

### Usage:
```bash
make clean
```

---

## **Notes**
- Ensure you have all required dependencies installed (e.g. Python, Make, etc.).
- For merging code, please follow the Hardware Development Guide outlined in the project drive before submitting pull requests (PRs).
- For troubleshooting or additional details, refer to individual target sections.

---

## **Acknowledgments**
Special thanks to contributors and open-source tools that made this project possible.
