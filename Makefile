##################################################
# Makefile for handling check, run, log, and clean targets with arguments.
# This Makefile supports the following goals:
# - check: Checks if Verilog design files are compliant.
# - synthesis: Synthesizes design to Synopsys 32-nm Cell Library.
# - kill: Closes all vsim instances started from the script.
# - start: Launches hierarchical block-diagram GUI starter generator.
# - run: Executes tests with specified arguments.
# - log: Displays logs based on the provided log mode.
# - clean: Cleans up generated files in the specified directory.
# - ci: Runs CI test sweep across all valid project directories.
#
# Usage:
# - make check                  - Checks if Verilog design files are compliant.
# - make kill           	    - Closes all started vsim instances from the script.
# - make synthesis              - Synthesizes design to Synopsys 32-nm Cell Library.
# - make start                  - Launches hierarchical block-diagram GUI starter generator.
# - make run <mode> (as) (ps|a)    - Assemble and run tests in a specified directory with a selected mode (optionally all tests in the directory).
# - make log <log_type> (c|a|p|x) - Display logs for a specified directory and log type.
# - make clean                  - Clean up generated files in a specified directory.
# - make ci                     - Run CI sweep (run tests in all directories + summarize results).
#
# Example:
# - make check  - Checks all .v design files that are not testbenches for compliancy.
# - make run v  - Views waveforms in a specified directory.
# - make log c  - Displays compilation logs for a specific directory.
# - make clean  - Cleans up generated files in a specific directory.
##################################################

# Default target: Shows usage instructions when no target is specified.
# This target will be executed if no other target is provided.
# It helps users understand how to use the Makefile.
default:
	@echo "Usage instructions for the Makefile:"
	@echo "  make check 	                  - Checks all .v design files for compliancy within a selected directory."
	@echo "  make kill 	                  - Closes all started vsim instances from the script."
	@echo "  make synthesis                  - Synthesizes design to Synopsys 32-nm Cell Library."
	@echo "  make run <mode> [as] [ps] (a)   - Run tests in a specified directory with a selected mode (c,s,g,v) and optionally assembles files."
	@echo "  make log <log_type>             - Display logs for a specified directory and log type."
	@echo "  make clean <clean_type>         - Clean up generated files in a specified directory."
	@echo "  make ci                         - Run CI sweep (all directories) and summarize pass/fail."

# Handle different goals (run, log, clean) by parsing arguments passed to make.
ifeq ($(firstword $(MAKECMDGOALS)), run)
  runargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
  # Prevent make from treating arguments as file targets for 'run'.
  $(eval $(runargs):;@true)
else ifeq ($(firstword $(MAKECMDGOALS)), log)
  logargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
  # Prevent make from treating arguments as file targets for 'log'.
  $(eval $(logargs):;@true)
else ifeq ($(firstword $(MAKECMDGOALS)), clean)
  cleanargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
  # Prevent make from treating arguments as file targets for 'cleanargs'.
  $(eval $(cleanargs):;@true)
endif

# Declare phony targets.
.PHONY: default check synthesis kill run log clean ci $(runargs) $(logargs) $(cleanargs)


##################################################
# Target: check
# This target checks Verilog design files in a specified directory.
# Usage:
#   make check
##################################################
check:
	@ cd Scripts && python3 execute_tasks.py -c


##################################################
# Target: kill
# This target closes all started vsim instances.
# Usage:
#   make kill
##################################################
kill:
	@echo "Closing all started vsim instances..."
	@ pkill vish -9


##################################################
# Target: synthesis
# This target performs RTL-to-Gate synthesis using Synopsys Design Compiler.
# It generates a .vg file (Verilog netlist) and a .sdc file (timing constraints).
# The synthesis process will only run if the .dc script changes or if any .sv files are modified.
# Usage:
#   make synthesis - Executes synthesis if the .vg
#                    file is missing or out of date.
##################################################
synthesis: 	
	@cd Scripts && python3 execute_tasks.py -s


##################################################
# Target: run
# This target runs tests with the specified arguments:
# - <mode>: Test mode (default or one of `v`, `g`, `s`, `c`).
# - <as>: Optional flag for assembling an input file.
# - <ps>: Optional flag for running post-synthesis tests.
# - <a>: Optional flag for additional arguments (e.g., 'a' to run all tests in a specific mode).
# Usage:
#   make run <mode> [as] [ps] (a)
##################################################
run:
	@if [ "$(words $(runargs))" -eq 0 ]; then \
		# If no arguments are passed, run with the '-a' flag (all) \
		cd Scripts && python3 execute_tasks.py -a; \
	else \
		# Parse the mode (first argument) and flags (remaining arguments) \
		mode="$(word 1, $(runargs))"; \
		flags="$(wordlist 2,99,$(runargs))"; \
		\
		# Determine mode code (0: c, 1: s, 2: g, 3: v) \
		case "$$mode" in \
			c) mode_code=0 ;; \
			s) mode_code=1 ;; \
			g) mode_code=2 ;; \
			v) mode_code=3 ;; \
			*) \
				echo "Error: Invalid arguments for 'run' target. Usage:"; \
				echo "  make run v|g|s|c [as] [ps] (a)"; \
				exit 1; \
				;; \
		esac; \
		\
		# Validation: 'ps' and 'a' cannot be used together \
		if echo "$$flags" | grep -qw "ps" && echo "$$flags" | grep -qw "a"; then \
			echo "Invalid combination: 'ps' cannot be used with 'a'"; \
			exit 1; \
		fi; \
		\
		# Validation: for 'v' mode, 'ps' and 'as' are not allowed \
		if [ "$$mode" = "v" ]; then \
			if echo "$$flags" | grep -qw "ps" || echo "$$flags" | grep -qw "as"; then \
				echo "Invalid for 'v' mode: cannot use 'ps' or 'as'"; \
				exit 1; \
			fi; \
		fi; \
		\
		# Build the Python command to run based on valid flags \
		cmd="cd Scripts && python3 execute_tasks.py -m $$mode_code"; \
		for f in $$flags; do \
			cmd="$$cmd -$$f"; \
		done; \
		\
		# Execute the command \
		eval "$$cmd"; \
	fi;


##################################################
# Target: log
# This target displays logs based on the provided log mode:
# - <log_type>: Type of log (either `o` for top-level outputs, `c` for compilation logs, or `t` for transcript logs).
# Usage:
#   make log <log_type>
##################################################
log:
	@if [ $(words $(logargs)) -ge 1 ]; then \
		case "$(word 1, $(logargs))" in \
			c) cd Scripts && python3 execute_tasks.py -l c ;; \
			t) cd Scripts && python3 execute_tasks.py -l t ;; \
			o) cd Scripts && python3 execute_tasks.py -l o ;; \
			*) \
				echo "Error: Invalid log type. Usage:"; \
				echo "  make log <o|c|t>"; \
				exit 1 ;; \
		esac; \
	else \
		echo "Error: Missing or invalid arguments for 'log' target. Usage:"; \
		echo "  make log <o|c|t>"; \
		exit 1; \
	fi;


##################################################
# Target: clean
# This target cleans up generated files based on the provided clean type:
# - <clean_type>: Type of cleanup (either `c` for a choice of directory or none for all directories).
# Usage:
#   make clean <clean_type>
##################################################
clean:
	@if [ "$(words $(cleanargs))" -eq 0 ]; then \
		cd Scripts && python3 execute_tasks.py -cl -a; \
	elif [ "$(words $(cleanargs))" -ge 1 ]; then \
		case "$(word 1, $(cleanargs))" in \
			c) cd Scripts && python3 execute_tasks.py -cl ;; \
			*) \
				echo "Error: Invalid clean type. Usage:"; \
				echo "  make clean        # Clean all"; \
				echo "  make clean c      # Clean current"; \
				exit 1 ;; \
		esac; \
	fi;


##################################################
# Target: ci
# This target runs CI test sweep across all valid
# top-level project directories.
# Usage:
#   make ci
##################################################
ci:
	@cd Scripts && python3 execute_tasks.py -ci
