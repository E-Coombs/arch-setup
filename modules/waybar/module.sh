#!/bin/bash

# Waybar module - Status bar for Wayland
# Provides a customizable status bar for Hyprland

# Module metadata
MODULE_NAME="waybar"
MODULE_DESCRIPTION="Wayland status bar"
MODULE_REQUIRES=("base" "hyprland")  # Depends on base and hyprland

# Required packages
OFFICIAL_PACKAGES=(
    "waybar"
    "otf-font-awesome"  # Icons for waybar
)

AUR_PACKAGES=()

# Services (none - started by Hyprland)
SERVICES=()
USER_SERVICES=()

# Module installation hook
module_install() {
    log_info "Installing Waybar..."
    # Installation handled by package manager
}

# Module configuration hook
module_configure() {
    log_info "Configuring Waybar..."

    # Create config directory if it doesn't exist
    mkdir -p "$HOME/.config/waybar"

    # Note: Actual config will be applied via dotfiles or defaults
}

# Post-install hook
module_post_install() {
    log_success "Waybar installed successfully"
    log_info "Waybar will be started automatically by Hyprland"
}
