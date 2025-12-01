#!/bin/bash

# Hyprland module - Wayland compositor
# Installs Hyprland and its dependencies

# Module metadata
MODULE_NAME="hyprland"
MODULE_DESCRIPTION="Hyprland Wayland compositor"
MODULE_REQUIRES=("base")  # Depends on base module

# Required packages
OFFICIAL_PACKAGES=(
    "hyprland"
    "xdg-desktop-portal-hyprland"
    "qt5-wayland"
    "qt6-wayland"
    "polkit-kde-agent"
    "kitty"  # Default terminal emulator
)

AUR_PACKAGES=()

# Services to enable (none - Hyprland is user-level)
SERVICES=()
USER_SERVICES=()

# Module installation hook
module_install() {
    log_info "Installing Hyprland..."
    # Installation handled by package manager
}

# Module configuration hook
module_configure() {
    log_info "Configuring Hyprland..."

    # Create config directory if it doesn't exist
    mkdir -p "$HOME/.config/hyprland"

    # Note: Actual config will be applied via dotfiles or defaults
}

# Post-install hook
module_post_install() {
    log_success "Hyprland installed successfully"
    log_info "To start Hyprland, run: Hyprland"
    log_info "Or configure your display manager to use Hyprland"
}
