#!/bin/bash

# service.sh - Systemd service management functions
# Handles enabling and starting system and user services

# Source core functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

# Check if a system service is enabled
is_service_enabled() {
    local service="$1"
    systemctl is-enabled "$service" &>/dev/null
}

# Check if a system service is active/running
is_service_active() {
    local service="$1"
    systemctl is-active "$service" &>/dev/null
}

# Enable a system service (idempotent)
enable_service() {
    local service="$1"
    local start_now="${2:-false}"

    if is_service_enabled "$service"; then
        log_info "Service already enabled: $service"
    else
        log_info "Enabling service: $service"

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] Would enable service: $service"
        else
            if sudo systemctl enable "$service"; then
                log_success "Service enabled: $service"
            else
                log_error "Failed to enable service: $service"
                return 1
            fi
        fi
    fi

    # Optionally start the service now
    if [[ "$start_now" == "true" ]]; then
        start_service "$service"
    fi

    return 0
}

# Start a system service if not running
start_service() {
    local service="$1"

    if is_service_active "$service"; then
        log_info "Service already running: $service"
        return 0
    fi

    log_info "Starting service: $service"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would start service: $service"
        return 0
    fi

    if sudo systemctl start "$service"; then
        log_success "Service started: $service"
        return 0
    else
        log_warn "Failed to start service: $service (may not be installed yet)"
        return 0  # Don't fail - service might not be ready
    fi
}

# Check if a user service is enabled
is_user_service_enabled() {
    local service="$1"
    systemctl --user is-enabled "$service" &>/dev/null
}

# Check if a user service is active/running
is_user_service_active() {
    local service="$1"
    systemctl --user is-active "$service" &>/dev/null
}

# Enable a user service (idempotent)
enable_user_service() {
    local service="$1"
    local start_now="${2:-false}"

    if is_user_service_enabled "$service"; then
        log_info "User service already enabled: $service"
    else
        log_info "Enabling user service: $service"

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] Would enable user service: $service"
        else
            if systemctl --user enable "$service"; then
                log_success "User service enabled: $service"
            else
                log_error "Failed to enable user service: $service"
                return 1
            fi
        fi
    fi

    # Optionally start the service now
    if [[ "$start_now" == "true" ]]; then
        start_user_service "$service"
    fi

    return 0
}

# Start a user service if not running
start_user_service() {
    local service="$1"

    if is_user_service_active "$service"; then
        log_info "User service already running: $service"
        return 0
    fi

    log_info "Starting user service: $service"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would start user service: $service"
        return 0
    fi

    if systemctl --user start "$service"; then
        log_success "User service started: $service"
        return 0
    else
        log_warn "Failed to start user service: $service (may not be installed yet)"
        return 0  # Don't fail - service might not be ready
    fi
}

# Enable multiple system services
enable_services() {
    local services=("$@")
    local failed=0

    for service in "${services[@]}"; do
        enable_service "$service" || ((failed++))
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed service(s) failed to enable"
        return 1
    fi

    return 0
}

# Enable multiple user services
enable_user_services() {
    local services=("$@")
    local failed=0

    for service in "${services[@]}"; do
        enable_user_service "$service" || ((failed++))
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed user service(s) failed to enable"
        return 1
    fi

    return 0
}
