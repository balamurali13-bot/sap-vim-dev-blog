#!/usr/bin/env bash
# SAP VIM Dev Blog - Publish Workflow
# Supports: NEW_POST, NEW_SNIPPET commands

set -euo pipefail

# === Configuration ===
BLOG_DIR="src/content/blog"
AUTHORS_DIR="src/content/authors"
CONFIG_FILE="src/content/config.ts"
DIST_DIR="./dist"
DEPLOY_PATH="/var/www/sapvim.blog"

# Valid categories from schema
VALID_CATEGORIES=(
    "abap-snippets"
    "vim-enhancements"
    "workflow"
    "fi-mm"
    "troubleshooting"
    "performance"
    "best-practices"
)

# === Helpers ===
log() { echo "[INFO] $*"; }
error() { echo "[ERROR] $*" >&2; }
warn() { echo "[WARN] $*" >&2; }

# === Validation ===
validate_author() {
    local author="$1"
    if [[ ! -f "$AUTHORS_DIR/${author}.md" ]]; then
        error "Author '$author' not found in $AUTHORS_DIR/"
        error "Available authors:"
        ls "$AUTHORS_DIR/" | sed 's/\.md$//' | sed 's/^/  - /'
        return 1
    fi
}

validate_category() {
    local category="$1"
    local valid=0
    for cat in "${VALID_CATEGORIES[@]}"; do
        if [[ "$category" == "$cat" ]]; then
            valid=1
            break
        fi
    done
    if (( ! valid )); then
        error "Invalid category: '$category'"
        error "Valid categories: ${VALID_CATEGORIES[*]}"
        return 1
    fi
}

validate_schema() {
    local title="$1"
    local description="$2"
    local author="$3"
    local category="$4"
    local status="$5"
    
    # Required fields
    [[ -n "$title" ]] || { error "title is required"; return 1; }
    [[ -n "$description" ]] || { error "description is required"; return 1; }
    [[ -n "$author" ]] || { error "author is required"; return 1; }
    [[ -n "$category" ]] || { error "category is required"; return 1; }
    
    # Validate author
    validate_author "$author" || return 1
    
    # Validate category
    validate_category "$category" || return 1
    
    # Validate status
    if [[ "$status" != "draft" && "$status" != "published" ]]; then
        error "status must be 'draft' or 'published', got: '$status'"
        return 1
    fi
    
    return 0
}

# === Generate Slug ===
generate_slug() {
    local title="$1"
    echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | sed 's/-\+/-/g' | sed 's/^-\+//;s/-\+$//'
}

# === Generate Filename ===
generate_filename() {
    local title="$1"
    local slug
    slug=$(generate_slug "$title")
    local timestamp
    timestamp=$(date +%Y-%m-%d)
    echo "${timestamp}-${slug}.mdx"
}

# === Create Post ===
create_post() {
    local title="$1"
    local description="$2"
    local author="$3"
    local category="$4"
    local status="${5:-draft}"
    local tags="${6:-}"
    local featured="${7:-false}"
    
    log "Creating post: $title"
    
    # Validate
    validate_schema "$title" "$description" "$author" "$category" "$status" || return 1
    
    # Generate filename
    local filename
    filename=$(generate_filename "$title")
    local filepath="$BLOG_DIR/$filename"
    
    # Check if exists
    if [[ -f "$filepath" ]]; then
        error "Post already exists: $filepath"
        return 1
    fi
    
    # Build tags array
    local tags_yaml=""
    if [[ -n "$tags" ]]; then
        tags_yaml="tags: [$tags]"
    fi
    
    # Create post
    cat > "$filepath" << EOF
---
title: "$title"
description: "$description"
pubDate: $(date +%Y-%m-%d)
author: $author
category: $category
$tags_yaml
status: $status
featured: $featured
---

# $title

Write your content here...
EOF

    log "Created: $filepath"
    
    # Show file
    echo ""
    echo "=== Created Post ==="
    echo "File: $filepath"
    echo "Title: $title"
    echo "Author: $author"
    echo "Category: $category"
    echo "Status: $status"
    echo ""
    
    # Deploy if published
    if [[ "$status" == "published" ]]; then
        log "Status is published - building and deploying..."
        build_and_deploy || return 1
    else
        log "Status is draft - saved but not deployed"
        log "To publish, edit the file and set status: published"
    fi
    
    return 0
}

# === Build and Deploy ===
build_and_deploy() {
    log "Building project..."
    npm run build
    
    if [[ ! -d "$DIST_DIR" ]]; then
        error "Build failed - dist not found"
        return 1
    fi
    
    log "Deploying to $DEPLOY_PATH..."
    mkdir -p "$DEPLOY_PATH"
    rsync -avz --delete "$DIST_DIR/" "$DEPLOY_PATH/"
    
    echo ""
    echo "=========================================="
    echo "✓ Deployed successfully!"
    echo "URL: https://sapvim.blog"
    echo "=========================================="
}

# === Main ===
main() {
    local command="$1"
    shift
    
    case "$command" in
        NEW_POST)
            local title="$1"
            local description="$2"
            local author="$3"
            local category="$4"
            local status="${5:-draft}"
            local tags="${6:-}"
            local featured="${7:-false}"
            
            create_post "$title" "$description" "$author" "$category" "$status" "$tags" "$featured"
            ;;
        NEW_SNIPPET)
            local title="$1"
            local description="$2"
            local author="$3"
            local category="abap-snippets"
            local status="${4:-draft}"
            local tags="snippet,$5"
            local featured="${6:-false}"
            
            create_post "$title" "$description" "$author" "$category" "$status" "$tags" "$featured"
            ;;
        *)
            error "Unknown command: $command"
            error "Supported: NEW_POST, NEW_SNIPPET"
            exit 1
            ;;
    esac
}

main "$@"
