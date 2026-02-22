#!/bin/bash
# Telegram Bot Runner for SAP VIM Blog

BOT_TOKEN="8406932136:AAEyww7CsenS5sxz_A0oV5pjumrlD2KOEo0"
PROJECT_DIR="/root/sap-vim-dev-blog"
SCRIPT="$PROJECT_DIR/scripts/telegram-publish.sh"

LAST_UPDATE_FILE="/tmp/telegram-bot-offset"
OFFSET=0

if [[ -f "$LAST_UPDATE_FILE" ]]; then
    OFFSET=$(cat "$LAST_UPDATE_FILE")
fi

echo "$(date): Starting bot polling from offset $OFFSET..."

while true; do
    RESPONSE=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET&timeout=30")
    
    RESULTS=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('result',[])))" 2>/dev/null)
    
    if [[ "$RESULTS" -gt 0 ]]; then
        echo "$RESPONSE" | python3 << 'PYTHON' 2>/dev/null
import json, sys, os, subprocess, urllib.request, urllib.parse

BOT_TOKEN = os.environ.get('BOT_TOKEN', '')

d = json.load(sys.stdin)
for update in d.get('result', []):
    offset = update.get('update_id', 0)
    
    msg = update.get('message', {})
    chat = msg.get('chat', {})
    from_user = msg.get('from', {})
    
    chat_id = chat.get('id')
    user_id = str(from_user.get('id', ''))
    text = msg.get('text', '')
    
    if text and chat_id and user_id:
        # Write temp command file
        with open('/tmp/telegram_cmd.txt', 'w') as f:
            f.write(text)
        
        # Run script
        env = os.environ.copy()
        env['TELEGRAM_USER_ID'] = user_id
        env['BOT_TOKEN'] = BOT_TOKEN
        
        try:
            result = subprocess.run(
                ['/bin/bash', '/root/sap-vim-dev-blog/scripts/telegram-publish.sh', '/tmp/telegram_cmd.txt'],
                capture_output=True, text=True, timeout=120, env=env,
                cwd='/root/sap-vim-dev-blog'
            )
            output = (result.stdout + result.stderr).strip()
        except Exception as e:
            output = f'Error: {str(e)}'
        
        # Limit output
        output_lines = output.split('\n')[:25]
        response_text = '```\n' + '\n'.join(output_lines) + '\n```'
        
        if len(response_text) > 4000:
            response_text = response_text[:4000]
        
        # Send to Telegram
        data = urllib.parse.urlencode({
            'chat_id': chat_id,
            'text': response_text,
            'parse_mode': 'Markdown'
        }).encode()
        
        try:
            req = urllib.request.Request(
                f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage',
                data=data, method='POST'
            )
            urllib.request.urlopen(req, timeout=10)
        except Exception as e:
            print(f'Send error: {e}')
        
        print(f'Processed: user={user_id} chat={chat_id}')
        
        # Save offset
        with open('/tmp/telegram-bot-offset', 'w') as f:
            f.write(str(offset + 1))

if RESULTS > 0:
    with open('/tmp/telegram-bot-offset', 'w') as f:
        last = d.get('result', [])
        if last:
            f.write(str(max([r.get('update_id',0) for r in last]) + 1))
PYTHON
        
        # Save offset after Python
        NEW_OFFSET=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result',[]); print(max([i.get('update_id',0) for i in r])+1) if r else 0" 2>/dev/null)
        echo "$NEW_OFFSET" > "$LAST_UPDATE_FILE"
        OFFSET="$NEW_OFFSET"
    fi
    
    sleep 3
done
