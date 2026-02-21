#!/usr/bin/env bash
# SAP VIM Dev Blog - Deploy Script
# Builds Astro site and deploys to Hostinger VPS or locally

set -euo pipefail

# === Configuration ===
REMOTE_HOST="${REMOTE_HOST:?REMOTE_HOST env var required}"
REMOTE_USER="${REMOTE_USER:?REMOTE_USER env var required}"
REMOTE_PATH="${REMOTE_PATH:?REMOTE_PATH env var required}"
LOCAL_BUILD="./dist"

# === Detect Mode ===
is_local_mode() {
    [[ "$REMOTE_HOST" == "localhost" ]] || [[ "$REMOTE_HOST" == "127.0.0.1" ]]
}

# === Dependencies ===
check_deps() {
    local missing=0
    
    if ! command -v rsync &>/dev/null; then
        echo "ERROR: rsync is required but not installed"
        missing=1
    fi
    
    if ! is_local_mode && ! command -v ssh &>/dev/null; then
        echo "ERROR: ssh is required but not installed"
        missing=1
    fi
    
    if (( missing )); then
        exit 1
    fi
}

# === Build ===
build_project() {
    echo "=== Building Astro Site ==="
    npm run build
    
    if [[ ! -d "$LOCAL_BUILD" ]]; then
        echo "ERROR: Build failed - dist directory not found"
        exit 1
    fi
    
    echo "Build complete: $LOCAL_BUILD"
}

# === Local Deploy ===
deploy_local() {
    echo "=== Local Deploy Mode ==="
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        echo "=== DRY RUN MODE - No changes will be made ==="
    fi
    
    # Create local directory
    if [[ ! -d "$REMOTE_PATH" ]]; then
        echo "Creating local directory: $REMOTE_PATH"
        mkdir -p "$REMOTE_PATH"
    else
        echo "Local directory exists: $REMOTE_PATH"
    fi
    
    local rsync_flags=(
        -avz
        --delete
        --exclude='.git'
        --exclude='node_modules'
        --exclude='.DS_Store'
    )
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        rsync_flags+=(--dry-run)
    fi
    
    echo "Syncing: $LOCAL_BUILD/ → $REMOTE_PATH/"
    rsync "${rsync_flags[@]}" "$LOCAL_BUILD/" "$REMOTE_PATH/"
}

# === Remote Deploy ===
deploy_remote() {
    echo "=== Remote Deploy Mode ==="
    echo "Host: $REMOTE_HOST"
    
    # Check remote directory
    echo "=== Checking remote directory ==="
    
    if ssh "$REMOTE_USER@$REMOTE_HOST" "test -d $REMOTE_PATH" 2>/dev/null; then
        echo "Remote directory exists: $REMOTE_PATH"
    else
        echo "Creating remote directory: $REMOTE_PATH"
        ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_PATH"
    fi
    
    local rsync_flags=(
        -avz
        --delete
        --exclude='.git'
        --exclude='node_modules'
        --exclude='.DS_Store'
    )
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        rsync_flags+=(--dry-run)
        echo "=== DRY RUN MODE - No changes will be made ==="
    fi
    
    echo "Syncing: $LOCAL_BUILD/ → $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"
    rsync "${rsync_flags[@]}" \
        "$LOCAL_BUILD/" \
        "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"
}

# === Main ===
main() {
    local mode
    if is_local_mode; then
        mode="LOCAL"
    else
        mode="REMOTE"
    fi
    
    echo "=========================================="
    echo "Deploying SAP VIM Dev Blog"
    echo "Mode: $mode"
    echo "Path: $REMOTE_PATH"
    echo "=========================================="
    echo ""
    
    check_deps
    build_project
    
    if is_local_mode; then
        deploy_local
    else
        deploy_remote
    fi
    
    echo ""
    echo "=========================================="
    echo "✓ Deploy Complete!"
    echo "=========================================="
}

main "$@"
