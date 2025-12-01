#!/bin/bash

# Example Module Template
# Copy this template to create new modules for your setup
#
# To create a new module:
# 1. Copy this directory: cp -r modules/example-module modules/myapp
# 2. Edit module.sh and update the metadata and package lists
# 3. (Optional) Add default configs in modules/myapp/defaults/.config/myapp/
# 4. Add module name to config.toml under [modules] enabled list
# 5. Run: ./setup.sh --modules myapp

# Module metadata
MODULE_NAME="example"
MODULE_DESCRIPTION="Example application module"
MODULE_REQUIRES=("base")  # List of module dependencies (modules that must be installed first)

# Package lists
# Official packages from Arch repositories (installed via pacman)
OFFICIAL_PACKAGES=(
    "package1"
    "package2"
)

# AUR packages (installed via paru)
AUR_PACKAGES=(
    "aur-package1"
)

# System services to enable (via systemctl)
SERVICES=(
    # "example.service"
)

# User services to enable (via systemctl --user)
USER_SERVICES=(
    # "example-user.service"
)

# ====================================
# Optional hooks - define only if needed
# ====================================

# Custom installation logic (optional)
# This runs after packages are installed but before configuration
module_install() {
    log_info "Installing $MODULE_NAME..."

    # Add custom installation steps here
    # Examples:
    # - Download additional files
    # - Build from source
    # - Create directories
    # - Set permissions
}

# Custom configuration (optional)
# This runs during the configuration phase
module_configure() {
    log_info "Configuring $MODULE_NAME..."

    # Add custom configuration steps here
    # Examples:
    # - Modify configuration files
    # - Set environment variables
    # - Create symlinks
    # - Initialize databases
}

# Post-install hooks (optional)
# This runs after everything else is complete
module_post_install() {
    log_info "Running post-install for $MODULE_NAME..."

    # Add post-install tasks here
    # Examples:
    # - Display usage instructions
    # - Verify installation
    # - Run first-time setup
    # - Add user to groups

    log_success "$MODULE_NAME installed successfully!"
}

# ====================================
# Notes for module developers:
# ====================================
#
# - All three hooks (module_install, module_configure, module_post_install) are optional
# - If you don't need custom logic, you can delete the unused hook functions
# - The framework will automatically handle package installation and service enablement
# - Use the logging functions: log_info, log_warn, log_error, log_success
# - Check if running in dry-run mode: if [[ "${DRY_RUN:-false}" == "true" ]]; then
# - Access config values: get_config "section.key" "default_value"
#
# Default configurations:
# - Place default config files in: modules/myapp/defaults/.config/myapp/
# - Use XDG directory structure (mirrors ~/.config/)
# - These will be used as fallback if user's dotfile repo doesn't have the config
#
# Module execution order:
# 1. Check module dependencies (MODULE_REQUIRES)
# 2. Install OFFICIAL_PACKAGES
# 3. Install AUR_PACKAGES
# 4. Run module_install() hook
# 5. Apply dotfiles or defaults
# 6. Run module_configure() hook
# 7. Enable SERVICES and USER_SERVICES
# 8. Run module_post_install() hook
