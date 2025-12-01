#!/bin/bash

# package.sh - Package management functions for pacman and paru
# Handles installation of official and AUR packages with idempotency

# Source core functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

# Install official packages via pacman (idempotent)
install_official_packages() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    # Filter out already installed packages
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_info "All official packages already installed"
        return 0
    fi

    log_info "Installing official packages: ${to_install[*]}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install: ${to_install[*]}"
        return 0
    fi

    if sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
        log_success "Official packages installed successfully"
        return 0
    else
        log_error "Failed to install some official packages"
        return 1
    fi
}

# Ensure paru is installed
ensure_paru() {
    if command -v paru &>/dev/null; then
        log_info "Paru is already installed"
        return 0
    fi

    log_info "Paru not found, installing from AUR..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install paru from AUR"
        return 0
    fi

    # Ensure base-devel is installed (required for building AUR packages)
    if ! is_installed "base-devel"; then
        log_info "Installing base-devel (required for AUR builds)..."
        sudo pacman -S --needed --noconfirm base-devel || {
            log_error "Failed to install base-devel"
            return 1
        }
    fi

    # Ensure git is installed
    if ! command -v git &>/dev/null; then
        ensure_git || return 1
    fi

    # Clone and build paru
    local build_dir="/tmp/paru-build-$$"
    mkdir -p "$build_dir"

    log_info "Cloning paru repository..."
    if ! git clone https://aur.archlinux.org/paru.git "$build_dir"; then
        log_error "Failed to clone paru repository"
        rm -rf "$build_dir"
        return 1
    fi

    cd "$build_dir" || return 1

    log_info "Building paru..."
    if makepkg -si --noconfirm; then
        log_success "Paru installed successfully"
        cd - > /dev/null
        rm -rf "$build_dir"
        return 0
    else
        log_error "Failed to build paru"
        cd - > /dev/null
        rm -rf "$build_dir"
        return 1
    fi
}

# Install AUR packages via paru (idempotent)
install_aur_packages() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    # Ensure paru is installed
    ensure_paru || return 1

    # Filter out already installed packages
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_info "All AUR packages already installed"
        return 0
    fi

    log_info "Installing AUR packages: ${to_install[*]}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would install AUR packages: ${to_install[*]}"
        return 0
    fi

    # Install with retry logic
    local max_retries=2
    local retry=0

    while [[ $retry -le $max_retries ]]; do
        if [[ $retry -gt 0 ]]; then
            log_warn "Retry attempt $retry/$max_retries..."
            sleep 2
        fi

        if paru -S --needed --noconfirm "${to_install[@]}"; then
            log_success "AUR packages installed successfully"
            return 0
        fi

        ((retry++))
    done

    log_error "Failed to install AUR packages after $max_retries retries"
    return 1
}

# Update system packages (optional)
update_system() {
    log_info "Updating system packages..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would update system packages"
        return 0
    fi

    if sudo pacman -Syu --noconfirm; then
        log_success "System updated successfully"
        return 0
    else
        log_warn "System update completed with warnings"
        return 0  # Don't fail on update warnings
    fi
}

# Refresh package databases
refresh_databases() {
    log_info "Refreshing package databases..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would refresh package databases"
        return 0
    fi

    if sudo pacman -Sy; then
        log_success "Package databases refreshed"
        return 0
    else
        log_error "Failed to refresh package databases"
        return 1
    fi
}
