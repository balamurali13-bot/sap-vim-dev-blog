#!/usr/bin/env bash
# Telegram Publish Wrapper for SAP VIM Dev Blog
# Parses Telegram commands and calls scripts/publish.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# === Handle /listauthors ===
list_authors() {
    echo "Available Authors:"
    echo ""
    for f in "$PROJECT_DIR/src/content/authors"/*.md; do
        if [[ -f "$f" ]]; then
            local name role slug
            slug=$(basename "$f" .md)
            name=$(grep "^name:" "$f" | cut -d: -f2 | xargs)
            role=$(grep "^role:" "$f" | cut -d: -f2 | xargs)
            echo "  @$slug"
            echo "    Name: $name"
            echo "    Role: $role"
            echo ""
        fi
    done
}

# === Handle /listcategories ===
list_categories() {
    echo "Valid Categories:"
    echo ""
    echo "  abap-snippets     - ABAP code snippets"
    echo "  vim-enhancements  - SAP VIM enhancements"
    echo "  workflow         - Workflow and approvals"
    echo "  fi-mm            - FI/MM integration"
    echo "  troubleshooting   - Troubleshooting guides"
    echo "  performance      - Performance tuning"
    echo "  best-practices   - Best practices"
}

# === Get field value from input (single line) ===
get_field() {
    local input="$1"
    local field="$2"
    echo "$input" | grep "^${field}=" | cut -d= -f2- | xargs
}

# === Get multiline field value (for body) ===
get_multiline_field() {
    local input="$1"
    local field="$2"
    local in_field=false
    local result=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check if this line starts the field we want
        if [[ "$line" == "${field}="* ]]; then
            in_field=true
            # Get everything after first =
            result="${line#*=}"
            continue
        fi
        
        # If we're in the field, check for new field separator
        if [[ "$in_field" == "true" ]]; then
            # Check if this is a new key=value line
            if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
                break
            fi
            # Add line to result
            if [[ -n "$result" ]]; then
                result+=$'\n'"$line"
            else
                result="$line"
            fi
        fi
    done <<< "$input"
    
    echo "$result"
}

# === Validate author ===
validate_author() {
    local author="$1"
    if [[ ! -f "$PROJECT_DIR/src/content/authors/${author}.md" ]]; then
        echo "ERROR: Author not found: $author"
        echo "Available authors:"
        ls "$PROJECT_DIR/src/content/authors/" | sed 's/\.md$//' | sed 's/^/  - /'
        return 1
    fi
    return 0
}

# === Validate category ===
validate_category() {
    local category="$1"
    case "$category" in
        abap-snippets|vim-enhancements|workflow|fi-mm|troubleshooting|performance|best-practices)
            return 0
            ;;
        *)
            echo "ERROR: Invalid category: $category"
            echo "Valid: abap-snippets vim-enhancements workflow fi-mm troubleshooting performance best-practices"
            return 1
            ;;
    esac
}

# === Handle /newpost ===
handle_newpost() {
    local input="$1"
    
    local title desc author category status tags featured date slug body
    title=$(get_field "$input" "title")
    desc=$(get_field "$input" "description")
    author=$(get_field "$input" "author")
    category=$(get_field "$input" "category")
    status=$(get_field "$input" "status")
    tags=$(get_field "$input" "tags")
    featured=$(get_field "$input" "featured")
    date=$(get_field "$input" "date")
    slug=$(get_field "$input" "slug")
    body=$(get_multiline_field "$input" "body")
    
    # Defaults
    status=${status:-draft}
    featured=${featured:-false}
    date=${date:-$(date +%Y-%m-%d)}
    
    # Validate required
    [[ -n "$title" ]] && [[ -n "$desc" ]] && [[ -n "$author" ]] && [[ -n "$category" ]] && [[ -n "$status" ]] || {
        echo "ERROR: Missing required fields"
        echo "Required: title, description, author, category, status"
        return 1
    }
    
    validate_author "$author" || return 1
    validate_category "$category" || return 1
    
    [[ "$status" == "draft" || "$status" == "published" ]] || {
        echo "ERROR: status must be draft or published"
        return 1
    }
    
    # Generate filename
    local filename
    if [[ -n "$slug" ]]; then
        filename="${date}-${slug}.mdx"
    else
        local slugified
        slugified=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | sed 's/-\+/-/g' | sed 's/^-\+//;s/-\+$//')
        filename="${date}-${slugified}.mdx"
    fi
    
    local filepath="$PROJECT_DIR/src/content/blog/$filename"
    
    if [[ -f "$filepath" ]]; then
        echo "ERROR: Post already exists: $filename"
        return 1
    fi
    
    # Build tags yaml
    local tags_yaml=""
    [[ -n "$tags" ]] && tags_yaml="tags: [$tags]"
    
    # Body content
    local body_content="${body:-Write your content here...}"
    
    # Create post
    cat > "$filepath" << EOF
---
title: "$title"
description: "$desc"
pubDate: $date
author: $author
category: $category
$tags_yaml
status: $status
featured: $featured
---

# $title

$body_content
EOF

    echo "OK: Created $filename"
    echo "  Title: $title"
    echo "  Author: $author"
    echo "  Category: $category"
    echo "  Status: $status"
    
    if [[ "$status" == "published" ]]; then
        echo ""
        echo "Building and deploying..."
        cd "$PROJECT_DIR"
        npm run build
        mkdir -p /var/www/sapvim.blog
        rsync -avz --delete ./dist/ /var/www/sapvim.blog/
        echo ""
        echo "OK: Deployed to https://sapvim.blog"
    else
        echo ""
        echo "OK: Draft saved. Set status=published to deploy."
    fi
}

# === Handle /snippet ===
handle_snippet() {
    local input="$1"
    
    local title desc author status tag featured date body
    title=$(get_field "$input" "title")
    desc=$(get_field "$input" "description")
    author=$(get_field "$input" "author")
    status=$(get_field "$input" "status")
    tag=$(get_field "$input" "tag")
    featured=$(get_field "$input" "featured")
    date=$(get_field "$input" "date")
    body=$(get_multiline_field "$input" "body")
    
    # Defaults
    status=${status:-draft}
    featured=${featured:-false}
    date=${date:-$(date +%Y-%m-%d)}
    local category="abap-snippets"
    local tags="snippet"
    [[ -n "$tag" ]] && tags="snippet,$tag"
    
    # Validate required
    [[ -n "$title" ]] && [[ -n "$desc" ]] && [[ -n "$author" ]] || {
        echo "ERROR: Missing required fields: title, description, author"
        return 1
    }
    
    validate_author "$author" || return 1
    
    # Generate filename
    local slugified
    slugified=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | sed 's/-\+/-/g' | sed 's/^-\+//;s/-\+$//')
    local filename="${date}-${slugified}.mdx"
    local filepath="$PROJECT_DIR/src/content/blog/$filename"
    
    if [[ -f "$filepath" ]]; then
        echo "ERROR: Snippet already exists: $filename"
        return 1
    fi
    
    local body_content="${body:-Write your snippet here...}"
    
    cat > "$filepath" << EOF
---
title: "$title"
description: "$desc"
pubDate: $date
author: $author
category: $category
tags: [$tags]
status: $status
featured: $featured
---

# $title

\`\`\`abap
$body_content
\`\`\`
EOF

    echo "OK: Created snippet $filename"
    echo "  Title: $title"
    echo "  Author: $author"
    echo "  Status: $status"
    
    if [[ "$status" == "published" ]]; then
        echo ""
        echo "Building and deploying..."
        cd "$PROJECT_DIR"
        npm run build
        mkdir -p /var/www/sapvim.blog
        rsync -avz --delete ./dist/ /var/www/sapvim.blog/
        echo ""
        echo "OK: Deployed to https://sapvim.blog"
    fi
}

# === Main ===
main() {
    local input
    
    # Read from file if provided, else from stdin, else from arguments
    if [[ -n "$1" && -f "$1" ]]; then
        input=$(cat "$1")
    elif [[ -p /dev/stdin ]]; then
        input=$(cat)
    else
        # Join all args with newlines
        input=$(printf '%s\n' "$@")
    fi
    
    if [[ -z "$input" ]]; then
        echo "ERROR: No input"
        echo "Usage: /newpost, /snippet, /listauthors, /listcategories"
        return 1
    fi
    
    local first_word
    first_word=$(echo "$input" | head -1 | xargs)
    local body
    body=$(echo "$input" | tail -n +2)
    
    case "$first_word" in
        /newpost|/newpost@*|/newPost)
            handle_newpost "$body"
            ;;
        /snippet|/snippet@*)
            handle_snippet "$body"
            ;;
        /listauthors|/listauthors@*)
            list_authors
            ;;
        /listcategories|/listcategories@*)
            list_categories
            ;;
        *)
            echo "ERROR: Unknown command: $first_word"
            echo "Use: /newpost, /snippet, /listauthors, /listcategories"
            return 1
            ;;
    esac
}

main "$@" < /dev/null
