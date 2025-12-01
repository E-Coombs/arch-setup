#!/bin/bash

# dotfiles.sh - Dotfile management using GNU stow
# Handles cloning, updating, and symlinking dotfiles

# Source core functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

# Clone dotfiles repository
clone_dotfiles() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-main}"

    if [[ -z "$repo_url" ]]; then
        log_warn "No dotfile repository configured, skipping clone"
        return 1
    fi

    # Validate URL
    validate_url "$repo_url" || return 1

    if [[ -d "$target_dir/.git" ]]; then
        log_info "Dotfiles repository already exists at $target_dir"
        return 0
    fi

    log_info "Cloning dotfiles from $repo_url to $target_dir..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would clone dotfiles from $repo_url"
        return 0
    fi

    # Create parent directory
    mkdir -p "$(dirname "$target_dir")" || {
        log_error "Failed to create parent directory for dotfiles"
        return 1
    }

    # Clone repository
    if git clone -b "$branch" "$repo_url" "$target_dir"; then
        log_success "Dotfiles cloned successfully"
        return 0
    else
        log_error "Failed to clone dotfiles repository"
        return 1
    fi
}

# Update dotfiles repository
update_dotfiles() {
    local target_dir="$1"
    local branch="${2:-main}"

    if [[ ! -d "$target_dir/.git" ]]; then
        log_warn "Dotfiles directory is not a git repository: $target_dir"
        return 1
    fi

    log_info "Updating dotfiles from remote..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would update dotfiles"
        return 0
    fi

    cd "$target_dir" || return 1

    # Fetch latest changes
    if ! git fetch origin; then
        log_error "Failed to fetch dotfiles updates"
        cd - > /dev/null
        return 1
    fi

    # Check if there are updates
    local LOCAL=$(git rev-parse @)
    local REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "$LOCAL")

    if [[ "$LOCAL" == "$REMOTE" ]]; then
        log_info "Dotfiles are already up to date"
        cd - > /dev/null
        return 0
    fi

    # Pull changes
    if git pull origin "$branch"; then
        log_success "Dotfiles updated successfully"
        cd - > /dev/null
        return 0
    else
        log_error "Failed to pull dotfiles updates"
        cd - > /dev/null
        return 1
    fi
}

# Link dotfiles using GNU stow
link_dotfiles() {
    local dotfiles_dir="$1"
    local target_dir="${2:-$HOME}"

    if [[ ! -d "$dotfiles_dir" ]]; then
        log_error "Dotfiles directory not found: $dotfiles_dir"
        return 1
    fi

    # Ensure stow is installed
    if ! command -v stow &>/dev/null; then
        log_error "GNU stow is not installed. Please install it first."
        return 1
    fi

    log_info "Linking dotfiles from $dotfiles_dir to $target_dir..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would link dotfiles using stow"
        return 0
    fi

    cd "$dotfiles_dir" || return 1

    # Run stow with conflict detection
    if stow -v -d "$dotfiles_dir" -t "$target_dir" . 2>&1 | tee /tmp/stow-output.log; then
        log_success "Dotfiles linked successfully"
        cd - > /dev/null
        return 0
    else
        # Check for conflicts
        if grep -q "existing target is" /tmp/stow-output.log; then
            log_error "Stow conflicts detected. Existing files are in the way."
            log_info "Conflicting files:"
            grep "existing target is" /tmp/stow-output.log
            log_info "Please resolve conflicts manually or backup existing files"
        else
            log_error "Failed to link dotfiles with stow"
        fi
        cd - > /dev/null
        return 1
    fi
}

# Apply default configs from module
apply_defaults() {
    local module_defaults_dir="$1"
    local target_dir="${2:-$HOME}"

    if [[ ! -d "$module_defaults_dir" ]]; then
        log_warn "No default configs found in: $module_defaults_dir"
        return 1
    fi

    log_info "Applying default configs from $module_defaults_dir..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would apply default configs"
        return 0
    fi

    # Copy configs preserving structure
    if cp -rn "$module_defaults_dir/." "$target_dir/"; then
        log_success "Default configs applied"
        return 0
    else
        log_warn "Some default configs may already exist (skipped)"
        return 0  # Don't fail if files exist
    fi
}

# Check if dotfiles repo contains a specific config
has_config() {
    local dotfiles_dir="$1"
    local config_path="$2"

    if [[ -e "$dotfiles_dir/$config_path" ]]; then
        return 0
    else
        return 1
    fi
}

# Manage dotfiles for a module
manage_module_dotfiles() {
    local module_name="$1"
    local module_dir="$2"
    local dotfiles_dir="$3"

    local defaults_dir="$module_dir/defaults"

    # Check if module has default configs
    if [[ ! -d "$defaults_dir" ]]; then
        log_info "No default configs for module: $module_name"
        return 0
    fi

    # If dotfiles repo exists and has this config, skip defaults
    if [[ -d "$dotfiles_dir" ]]; then
        # Check if dotfiles repo has configs for this module
        # This is a simple check - modules can customize this logic
        log_info "Dotfiles repository exists, preferring repo configs over defaults"
        return 0
    fi

    # Apply module defaults
    log_info "Applying default configs for module: $module_name"
    apply_defaults "$defaults_dir" "$HOME"
}
