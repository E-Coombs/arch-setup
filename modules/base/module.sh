#!/bin/bash

# Base module - Essential system utilities
# This module provides the foundation for building AUR packages and managing dotfiles

# Module metadata
MODULE_NAME="base"
MODULE_DESCRIPTION="Base system utilities and build tools"
MODULE_REQUIRES=()  # No dependencies

# Required packages
OFFICIAL_PACKAGES=(
    "base-devel"
    "git"
    "wget"
    "curl"
    "stow"
    "vim"
    "networkmanager"
)

AUR_PACKAGES=()

# Services to enable
SERVICES=("NetworkManager")
USER_SERVICES=()

# Module installation hook (optional)
module_install() {
    log_info "Installing base system utilities..."
    # No custom installation steps needed for base
}

# Module configuration hook (optional)
module_configure() {
    log_info "Configuring base system..."
    # No custom configuration needed for base
}

# Post-install hook (optional)
module_post_install() {
    log_info "Base module post-install..."
    # Verify git is working
    if command -v git &>/dev/null; then
        log_success "Git is installed and ready"
    fi
}
