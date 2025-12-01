#!/bin/bash

# core.sh - Core utility functions for arch-setup
# Provides logging, TOML parsing, and common utilities

# Prevent multiple sourcing
if [[ -n "${_CORE_SH_LOADED:-}" ]]; then
    return 0
fi
_CORE_SH_LOADED=1

# Global variables
declare -A CONFIG
LOG_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Initialize logging
init_logging() {
    local log_dir="${1:-$HOME/.local/share/arch-setup/logs}"

    # Create log directory if it doesn't exist
    mkdir -p "$log_dir" 2>/dev/null || {
        log_warn "Could not create log directory: $log_dir, logging to stdout only"
        return 1
    }

    # Create log file with timestamp
    LOG_FILE="$log_dir/setup-$(date +%Y%m%d-%H%M%S).log"
    touch "$LOG_FILE" 2>/dev/null || {
        log_warn "Could not create log file: $LOG_FILE, logging to stdout only"
        LOG_FILE=""
        return 1
    }

    log_info "Logging initialized: $LOG_FILE"
    return 0
}

# Logging functions with dual output (stdout + file)
log_info() {
    local msg="[INFO] $*"
    echo -e "\033[0;32m$msg\033[0m"
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
    fi
}

log_warn() {
    local msg="[WARN] $*"
    echo -e "\033[0;33m$msg\033[0m" >&2
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
    fi
}

log_error() {
    local msg="[ERROR] $*"
    echo -e "\033[0;31m$msg\033[0m" >&2
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
    fi
}

log_success() {
    local msg="[SUCCESS] $*"
    echo -e "\033[1;32m$msg\033[0m"
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
    fi
}

# Confirmation prompt for phase gates
confirm_prompt() {
    local message="$1"
    local default="${2:-n}"

    # Skip if running with --no-confirm
    if [[ "${NO_CONFIRM:-false}" == "true" ]]; then
        log_info "Auto-confirming: $message"
        return 0
    fi

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi

    while true; do
        read -p "$prompt" -n 1 -r
        echo

        if [[ -z "$REPLY" ]]; then
            [[ "$default" == "y" ]] && return 0 || return 1
        fi

        case "$REPLY" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# Check if a package is installed
is_installed() {
    local package="$1"
    pacman -Qi "$package" &>/dev/null
}

# Backup a file before modification
backup_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$file" "$backup" || {
        log_error "Failed to backup $file"
        return 1
    }

    log_info "Backed up $file to $backup"
    return 0
}

# Simple TOML parser
parse_toml() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "TOML file not found: $file"
        return 1
    fi

    local section=""
    local line_num=0

    # Temporarily disable exit on error for the read loop
    set +e
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Parse section headers [section]
        if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        # Parse key-value pairs
        if [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Trim whitespace from key
            key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            # Remove surrounding quotes from value
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # Handle arrays [item1, item2, ...]
            if [[ "$value" =~ ^\[(.*)\]$ ]]; then
                value="${BASH_REMATCH[1]}"
                # Remove quotes from array items and trim spaces
                value=$(echo "$value" | sed 's/"//g' | sed "s/'//g" | sed 's/,/ /g' | tr -s ' ')
            fi

            # Store in associative array
            if [[ -n "$section" ]]; then
                CONFIG["${section}.${key}"]="$value"
            else
                CONFIG["${key}"]="$value"
            fi
        fi
    done < "$file"
    set -e

    return 0
}

# Get config value with optional default
get_config() {
    local key="$1"
    local default="${2:-}"

    if [[ -n "${CONFIG[$key]:-}" ]]; then
        echo "${CONFIG[$key]}"
    else
        echo "$default"
    fi
}

# Ensure git is installed
ensure_git() {
    if command -v git &>/dev/null; then
        log_info "Git is already installed"
        return 0
    fi

    log_info "Git not found, installing..."

    if sudo pacman -S --needed --noconfirm git; then
        log_success "Git installed successfully"
        return 0
    else
        log_error "Failed to install git"
        return 1
    fi
}

# Check if running on Arch Linux
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is designed for Arch Linux only"
        return 1
    fi
    return 0
}

# Check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."

    if ping -c 1 archlinux.org &>/dev/null; then
        log_success "Internet connection OK"
        return 0
    else
        log_error "No internet connection detected"
        return 1
    fi
}

# Validate URL format
validate_url() {
    local url="$1"

    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        log_error "Invalid URL format (must start with http:// or https://): $url"
        return 1
    fi
}

# Print a separator line
print_separator() {
    echo "========================================"
}

# Print section header
print_header() {
    local title="$1"
    echo
    print_separator
    echo "$title"
    print_separator
    echo
}
