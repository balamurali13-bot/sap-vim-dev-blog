#!/usr/bin/env bash
# Telegram Publish Wrapper for SAP VIM Dev Blog
# Multi-user with role-based permissions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/telegram-users.json"
LOG_FILE="$PROJECT_DIR/logs/telegram-access.log"

# === Load config ===
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Config file not found: $CONFIG_FILE"
        exit 1
    fi
    CONFIG=$(cat "$CONFIG_FILE")
}

# === Get user from telegram ID ===
get_user_by_id() {
    local telegram_id="$1"
    echo "$CONFIG" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for u in d.get('users', []):
    if str(u.get('telegram_id','')) == '$telegram_id':
        print(json.dumps(u))
        break
" 2>/dev/null
}

# === Get user role ===
get_user_role() {
    local user_json="$1"
    echo "$user_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('role',''))" 2>/dev/null
}

# === Get user name ===
get_user_name() {
    local user_json="$1"
    echo "$user_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null
}

# === Get role permissions ===
role_can_create_draft() {
    local role="$1"
    echo "$CONFIG" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('roles',{}).get('$role',{}).get('can_create_draft',False))" 2>/dev/null
}

role_can_publish() {
    local role="$1"
    echo "$CONFIG" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('roles',{}).get('$role',{}).get('can_publish',False))" 2>/dev/null
}

role_allowed_commands() {
    local role="$1"
    echo "$CONFIG" | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(d.get('roles',{}).get('$role',{}).get('allowed_commands',[])))" 2>/dev/null
}

# === Check if user can run command ===
can_run_command() {
    local user_json="$1"
    local command="$2"
    
    if [[ -z "$user_json" ]]; then
        return 1
    fi
    
    local role=$(get_user_role "$user_json")
    local allowed=$(role_allowed_commands "$role")
    
    if echo "$allowed" | grep -q "\b$command\b"; then
        return 0
    fi
    return 1
}

# === Check if user can publish ===
can_publish() {
    local user_json="$1"
    
    if [[ -z "$user_json" ]]; then
        return 1
    fi
    
    local role=$(get_user_role "$user_json")
    local result=$(role_can_publish "$role")
    [[ "$result" == "True" ]]
}

# === Log action ===
log_action() {
    local telegram_id="$1"
    local command="$2"
    local status="$3"
    local result="$4"
    
    mkdir -p "$PROJECT_DIR/logs"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $telegram_id | $command | $status | $result" >> "$LOG_FILE"
}

# === Handle /help ===
handle_help() {
    local user_json="$1"
    local role=$(get_user_role "$user_json")
    local name=$(get_user_name "$user_json")
    local allowed=$(role_allowed_commands "$role")
    
    echo "=========================================="
    echo "  SAP VIM Dev Blog - Telegram Commands"
    echo "=========================================="
    echo ""
    echo "Logged in as: $name"
    echo "Role: $role"
    echo ""
    echo "Available commands:"
    echo ""
    echo "  /listauthors   - List available authors"
    echo "  /listcategories - List valid categories"
    echo "  /myrole       - Show your role and permissions"
    echo "  /help         - Show this help message"
    echo ""
    
    if echo "$allowed" | grep -qw "newpost"; then
        if echo "$allowed" | grep -qw "snippet"; then
            echo "  /newpost      - Create a new post"
            echo "  /snippet      - Create a code snippet"
        else
            echo "  /newpost      - Create a new post (draft)"
        fi
    fi
    echo ""
    echo "=========================================="
}

# === Handle /myrole ===
handle_myrole() {
    local user_json="$1"
    local role=$(get_user_role "$user_json")
    local name=$(get_user_name "$user_json")
    local can_draft=$(role_can_create_draft "$role")
    local can_pub=$(role_can_publish "$role")
    
    echo "=========================================="
    echo "  Your Account Info"
    echo "=========================================="
    echo ""
    echo "Name: $name"
    echo "Role: $role"
    echo ""
    echo "Permissions:"
    echo "  Can create drafts: $can_draft"
    echo "  Can publish:       $can_pub"
    echo ""
}

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
        if [[ "$line" == "${field}="* ]]; then
            in_field=true
            result="${line#*=}"
            continue
        fi
        
        if [[ "$in_field" == "true" ]]; then
            if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
                break
            fi
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
    local user_json="$2"
    local telegram_id="$3"
    
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
    
    # Check publish permission
    if [[ "$status" == "published" ]]; then
        if ! can_publish "$user_json"; then
            echo "ERROR: You don't have permission to publish posts."
            echo "Your role does not allow publishing. Contact an admin to upgrade your permissions."
            log_action "$telegram_id" "newpost" "DENIED" "No publish permission"
            return 1
        fi
    fi
    
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
        if can_publish "$user_json"; then
            echo ""
            echo "Building and deploying..."
            cd "$PROJECT_DIR"
            npm run build
            mkdir -p /var/www/sapvim.blog
            rsync -avz --delete ./dist/ /var/www/sapvim.blog/
            echo ""
            echo "OK: Deployed to https://sapvim.blog"
            log_action "$telegram_id" "newpost" "SUCCESS" "Published: $filename"
        else
            echo ""
            echo "OK: Draft saved (publish denied)"
            log_action "$telegram_id" "newpost" "DENIED" "No publish permission"
        fi
    else
        echo ""
        echo "OK: Draft saved. Set status=published to deploy."
        log_action "$telegram_id" "newpost" "SUCCESS" "Draft: $filename"
    fi
}

# === Handle /snippet ===
handle_snippet() {
    local input="$1"
    local user_json="$2"
    local telegram_id="$3"
    
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
    
    # Check publish permission
    if [[ "$status" == "published" ]]; then
        if ! can_publish "$user_json"; then
            echo "ERROR: You don't have permission to publish snippets."
            echo "Your role does not allow publishing. Contact an admin to upgrade your permissions."
            log_action "$telegram_id" "snippet" "DENIED" "No publish permission"
            return 1
        fi
    fi
    
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
        if can_publish "$user_json"; then
            echo ""
            echo "Building and deploying..."
            cd "$PROJECT_DIR"
            npm run build
            mkdir -p /var/www/sapvim.blog
            rsync -avz --delete ./dist/ /var/www/sapvim.blog/
            echo ""
            echo "OK: Deployed to https://sapvim.blog"
            log_action "$telegram_id" "snippet" "SUCCESS" "Published: $filename"
        else
            echo ""
            echo "OK: Draft saved (publish denied)"
            log_action "$telegram_id" "snippet" "DENIED" "No publish permission"
        fi
    else
        log_action "$telegram_id" "snippet" "SUCCESS" "Draft: $filename"
    fi
}

# === Main ===
main() {
    local telegram_id="${TELEGRAM_USER_ID:-}"
    
    # Load config
    load_config
    
    # Check if user is authorized
    local authorized=false
    local user_json=""
    
    if [[ -n "$telegram_id" ]]; then
        user_json=$(get_user_by_id "$telegram_id")
        if [[ -n "$user_json" ]]; then
            authorized=true
        fi
    fi
    
    local input
    
    # Read from file if provided, else from stdin, else from arguments
    if [[ -n "$1" && -f "$1" ]]; then
        input=$(cat "$1")
    elif [[ -p /dev/stdin ]]; then
        input=$(cat)
    else
        input=$(printf '%s\n' "$@")
    fi
    
    if [[ -z "$input" ]]; then
        echo "ERROR: No input"
        echo "Use: /help to see available commands"
        return 1
    fi
    
    local first_word
    first_word=$(echo "$input" | head -1 | xargs)
    local body
    body=$(echo "$input" | tail -n +2)
    
    # Handle commands
    case "$first_word" in
        /help|/help@*)
            handle_help "$user_json"
            log_action "$telegram_id" "help" "INFO" "Viewed help"
            ;;
        /myrole|/myrole@*)
            if [[ "$authorized" == "true" ]]; then
                handle_myrole "$user_json"
                log_action "$telegram_id" "myrole" "INFO" "Viewed role"
            else
                echo "Your Telegram ID: $telegram_id"
                echo "Status: Not authorized"
                echo ""
                echo "Contact the admin to get access."
                log_action "$telegram_id" "myrole" "INFO" "Not authorized"
            fi
            ;;
        /listauthors|/listauthors@*)
            list_authors
            log_action "$telegram_id" "listauthors" "INFO" "Listed authors"
            ;;
        /listcategories|/listcategories@*)
            list_categories
            log_action "$telegram_id" "listcategories" "INFO" "Listed categories"
            ;;
        /newpost|/newpost@*)
            if [[ "$authorized" == "false" ]]; then
                echo "ERROR: Unauthorized"
                echo "Your Telegram ID ($telegram_id) is not authorized to use this command."
                echo "Contact the admin to get access."
                log_action "$telegram_id" "newpost" "DENIED" "Not authorized"
                return 1
            fi
            if ! can_run_command "$user_json" "newpost"; then
                echo "ERROR: Your role does not allow /newpost command"
                log_action "$telegram_id" "newpost" "DENIED" "Role not allowed"
                return 1
            fi
            handle_newpost "$body" "$user_json" "$telegram_id"
            ;;
        /snippet|/snippet@*)
            if [[ "$authorized" == "false" ]]; then
                echo "ERROR: Unauthorized"
                echo "Your Telegram ID ($telegram_id) is not authorized to use this command."
                echo "Contact the admin to get access."
                log_action "$telegram_id" "snippet" "DENIED" "Not authorized"
                return 1
            fi
            if ! can_run_command "$user_json" "snippet"; then
                echo "ERROR: Your role does not allow /snippet command"
                log_action "$telegram_id" "snippet" "DENIED" "Role not allowed"
                return 1
            fi
            handle_snippet "$body" "$user_json" "$telegram_id"
            ;;
        *)
            echo "ERROR: Unknown command: $first_word"
            echo "Use /help to see available commands"
            log_action "$telegram_id" "unknown" "ERROR" "Unknown command"
            return 1
            ;;
    esac
}

main "$@" < /dev/null
