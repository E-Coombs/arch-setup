#!/bin/bash

# Arch Setup - Modular installation script for Arch Linux
# https://github.com/username/arch-setup

set -eo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/package.sh"
source "$SCRIPT_DIR/lib/dotfiles.sh"
source "$SCRIPT_DIR/lib/service.sh"

# Global flags
DRY_RUN=false
NO_CONFIRM=false
SKIP_DOTFILES=false
FORCE=false
VERBOSE=false
MODULES_FILTER=""

# Show usage
show_help() {
    cat << EOF
Arch Setup - Modular installation framework for Arch Linux

Usage: ./setup.sh [OPTIONS]

Options:
    --dry-run               Show what would be done without making changes
    --modules MODULE1,MODULE2   Install only specified modules (comma-separated)
    --skip-dotfiles         Skip dotfile cloning and symlinking
    --no-confirm            Skip all confirmation prompts (automatic yes)
    --force                 Force reinstall even if packages are already installed
    --verbose               Enable verbose logging output
    --help                  Display this help message

Examples:
    ./setup.sh                          # Full installation
    ./setup.sh --dry-run                # Preview what would be installed
    ./setup.sh --modules base,hyprland  # Install only specific modules
    ./setup.sh --no-confirm             # Non-interactive mode

For more information, see README.md
EOF
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                export DRY_RUN
                shift
                ;;
            --modules)
                MODULES_FILTER="$2"
                shift 2
                ;;
            --skip-dotfiles)
                SKIP_DOTFILES=true
                shift
                ;;
            --no-confirm)
                NO_CONFIRM=true
                export NO_CONFIRM
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Load module file
load_module() {
    local module_name="$1"
    local module_file="$SCRIPT_DIR/modules/$module_name/module.sh"

    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module_name"
        return 1
    fi

    # Source the module file
    source "$module_file"
}

# Process a single module
process_module() {
    local module_name="$1"

    print_header "Processing module: $module_name"

    # Load module
    load_module "$module_name" || return 1

    # Check dependencies
    if [[ ${#MODULE_REQUIRES[@]} -gt 0 ]]; then
        log_info "Module requires: ${MODULE_REQUIRES[*]}"
        for dep in "${MODULE_REQUIRES[@]}"; do
            if [[ ! " ${PROCESSED_MODULES[*]} " =~ " ${dep} " ]]; then
                log_info "Processing dependency: $dep"
                process_module "$dep"
            fi
        done
    fi

    # Install official packages
    if [[ ${#OFFICIAL_PACKAGES[@]} -gt 0 ]]; then
        log_info "Installing official packages for $module_name..."
        install_official_packages "${OFFICIAL_PACKAGES[@]}" || {
            log_error "Failed to install official packages for $module_name"
            return 1
        }
    fi

    # Install AUR packages
    if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
        log_info "Installing AUR packages for $module_name..."
        install_aur_packages "${AUR_PACKAGES[@]}" || {
            log_warn "Failed to install some AUR packages for $module_name"
        }
    fi

    # Run module install hook if defined
    if declare -f module_install >/dev/null; then
        module_install || log_warn "Module install hook failed for $module_name"
    fi

    # Apply dotfiles or defaults
    local dotfiles_dir=$(get_config "dotfiles.target_dir" "")
    dotfiles_dir="${dotfiles_dir//\$HOME/$HOME}"

    if [[ -d "$SCRIPT_DIR/modules/$module_name/defaults" ]]; then
        if [[ -d "$dotfiles_dir" ]] && [[ "$SKIP_DOTFILES" != "true" ]]; then
            log_info "Using dotfiles from $dotfiles_dir (skipping module defaults)"
        else
            log_info "Applying default configs for $module_name..."
            apply_defaults "$SCRIPT_DIR/modules/$module_name/defaults" "$HOME"
        fi
    fi

    # Run module configure hook if defined
    if declare -f module_configure >/dev/null; then
        module_configure || log_warn "Module configure hook failed for $module_name"
    fi

    # Enable services
    if [[ ${#SERVICES[@]} -gt 0 ]] && [[ "$(get_config 'services.auto_enable' 'true')" == "true" ]]; then
        log_info "Enabling services for $module_name..."
        enable_services "${SERVICES[@]}" || log_warn "Some services failed to enable"
    fi

    # Enable user services
    if [[ ${#USER_SERVICES[@]} -gt 0 ]] && [[ "$(get_config 'services.auto_enable' 'true')" == "true" ]]; then
        log_info "Enabling user services for $module_name..."
        enable_user_services "${USER_SERVICES[@]}" || log_warn "Some user services failed to enable"
    fi

    # Run post-install hook if defined
    if declare -f module_post_install >/dev/null; then
        module_post_install || log_warn "Module post-install hook failed for $module_name"
    fi

    # Mark as processed
    PROCESSED_MODULES+=("$module_name")

    # Clear module variables for next module
    unset MODULE_NAME MODULE_DESCRIPTION MODULE_REQUIRES
    unset OFFICIAL_PACKAGES AUR_PACKAGES SERVICES USER_SERVICES
    unset -f module_install module_configure module_post_install 2>/dev/null

    log_success "Module $module_name completed"
}

# Main execution
main() {
    # Parse arguments
    parse_args "$@"

    # Print banner
    print_header "Arch Linux Setup Framework"
    log_info "Starting setup process..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
    fi

    # ============================================
    # Phase 1: Initialization
    # ============================================
    print_header "Phase 1: Initialization"

    # Setup logging
    local log_dir=$(get_config "logging.log_dir" "$HOME/.local/share/arch-setup/logs")
    log_dir="${log_dir//\$HOME/$HOME}"

    if [[ "$(get_config 'logging.log_to_file' 'true')" == "true" ]]; then
        init_logging "$log_dir"
    fi

    # Check if running on Arch
    check_arch || exit 1

    # Ensure git is installed
    ensure_git || exit 1

    # Load configuration
    local config_file="$SCRIPT_DIR/config/config.toml"
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi

    log_info "Loading configuration from $config_file..."
    parse_toml "$config_file"

    # Check internet connection
    check_internet || exit 1

    # Confirm to proceed
    if ! confirm_prompt "Proceed with setup?" "y"; then
        log_info "Setup cancelled by user"
        exit 0
    fi

    # ============================================
    # Phase 2: Package Installation
    # ============================================
    print_header "Phase 2: Package Installation"

    # Refresh package databases
    refresh_databases || exit 1

    # Determine which modules to install
    declare -a modules_to_install
    if [[ -n "$MODULES_FILTER" ]]; then
        IFS=',' read -ra modules_to_install <<< "$MODULES_FILTER"
        log_info "Installing filtered modules: ${modules_to_install[*]}"
    else
        local enabled_modules=$(get_config "modules.enabled" "base")
        read -ra modules_to_install <<< "$enabled_modules"
        log_info "Installing enabled modules: ${modules_to_install[*]}"
    fi

    # Track processed modules to avoid duplicates
    declare -a PROCESSED_MODULES=()

    # Process each module
    for module in "${modules_to_install[@]}"; do
        if [[ ! " ${PROCESSED_MODULES[*]} " =~ " ${module} " ]]; then
            process_module "$module" || {
                log_error "Failed to process module: $module"
                exit 1
            }
        fi
    done

    # Confirm before AUR packages
    if ! confirm_prompt "Package installation complete. Proceed with configuration?" "y"; then
        log_info "Setup stopped after package installation"
        exit 0
    fi

    # ============================================
    # Phase 3: Configuration
    # ============================================
    print_header "Phase 3: Configuration"

    # Handle dotfiles
    if [[ "$SKIP_DOTFILES" != "true" ]]; then
        local dotfiles_repo=$(get_config "dotfiles.repo" "")
        local dotfiles_branch=$(get_config "dotfiles.branch" "main")
        local dotfiles_dir=$(get_config "dotfiles.target_dir" "$HOME/.dotfiles")
        dotfiles_dir="${dotfiles_dir//\$HOME/$HOME}"

        if [[ -n "$dotfiles_repo" ]]; then
            if [[ -d "$dotfiles_dir/.git" ]]; then
                log_info "Dotfiles repository exists, updating..."
                update_dotfiles "$dotfiles_dir" "$dotfiles_branch" || log_warn "Failed to update dotfiles"
            else
                log_info "Cloning dotfiles repository..."
                clone_dotfiles "$dotfiles_repo" "$dotfiles_dir" "$dotfiles_branch" || log_warn "Failed to clone dotfiles"
            fi

            # Link dotfiles with stow
            if [[ -d "$dotfiles_dir" ]]; then
                log_info "Linking dotfiles..."
                link_dotfiles "$dotfiles_dir" "$HOME" || log_warn "Failed to link dotfiles"
            fi
        else
            log_info "No dotfiles repository configured, using module defaults"
        fi
    else
        log_info "Skipping dotfile management (--skip-dotfiles flag)"
    fi

    # ============================================
    # Phase 4: Completion
    # ============================================
    print_header "Setup Complete!"

    log_success "All modules installed successfully"
    log_info "Installed modules: ${PROCESSED_MODULES[*]}"

    if [[ -n "$LOG_FILE" ]]; then
        log_info "Log file: $LOG_FILE"
    fi

    echo
    log_info "Next steps:"
    log_info "  - Review your configurations in ~/.config/"
    log_info "  - Customize your dotfiles repository"
    log_info "  - Add more modules by copying modules/example-module/"
    log_info "  - Reboot or start your window manager"
    echo

    print_separator
}

# Run main function
main "$@"
