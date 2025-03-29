#!/bin/bash

# Logging module
# Handles all logging functionality with different levels and formatting

# Log levels (0=DEBUG, 1=INFO, 2=WARN, 3=ERROR)
LOG_LEVEL=${LOG_LEVEL:-1}  # Default to INFO level

# Logging functions
log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if we should log this level
    if [ $level -ge $LOG_LEVEL ]; then
        case $level in
            0)  # DEBUG
                echo -e "[$timestamp] \033[1;35mDEBUG\033[0m: $message"
                ;;
            1)  # INFO
                echo -e "[$timestamp] \033[1;34mINFO\033[0m:  $message"
                ;;
            2)  # WARN
                echo -e "[$timestamp] \033[1;33mWARN\033[0m:  $message" >&2
                ;;
            3)  # ERROR
                echo -e "[$timestamp] \033[1;31mERROR\033[0m: $message" >&2
                ;;
        esac
    fi
}

# Convenience functions
debug() { log 0 "$@"; }
info() { log 1 "$@"; }
warn() { log 2 "$@"; }
error() { log 3 "$@"; }

# Set log level
set_log_level() {
    local level=$1
    case $level in
        "DEBUG") LOG_LEVEL=0 ;;
        "INFO")  LOG_LEVEL=1 ;;
        "WARN")  LOG_LEVEL=2 ;;
        "ERROR") LOG_LEVEL=3 ;;
        *)
            error "Invalid log level: $level"
            exit 1
            ;;
    esac
    info "Log level set to $level"
}

# Log command execution
log_command() {
    local command=$1
    debug "Executing: $command"
    eval "$command"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Command failed with exit code $exit_code: $command"
    fi
    return $exit_code
}
