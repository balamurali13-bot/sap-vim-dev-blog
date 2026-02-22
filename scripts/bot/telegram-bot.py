#!/usr/bin/env python3
import os
import json
import subprocess
import urllib.request
import urllib.parse
import time

BOT_TOKEN = "8526467554:AAGrUB2Q2p9Prl2JAEZR3CqDfYdumxOsHfc"
PROJECT_DIR = "/root/sap-vim-dev-blog"
OFFSET_FILE = "/tmp/telegram-bot-offset"

def send_message(chat_id, text):
    try:
        data = urllib.parse.urlencode({
            'chat_id': chat_id,
            'text': text[:4000],
            'parse_mode': 'Markdown'
        }).encode()
        req = urllib.request.Request(
            f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            data=data, method='POST'
        )
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        print(f"Send error: {e}")

def main():
    offset = 0
    if os.path.exists(OFFSET_FILE):
        try:
            offset = int(open(OFFSET_FILE).read().strip())
        except:
            pass
    
    print(f"Starting bot polling from offset {offset}...")
    
    while True:
        try:
            url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates?offset={offset}&timeout=30"
            resp = urllib.request.urlopen(url, timeout=35)
            data = json.loads(resp.read().decode())
            
            results = data.get('result', [])
            if results:
                for update in results:
                    offset = update.get('update_id', 0) + 1
                    msg = update.get('message', {})
                    chat = msg.get('chat', {})
                    user = msg.get('from', {})
                    
                    chat_id = chat.get('id')
                    user_id = str(user.get('id', ''))
                    text = msg.get('text', '')
                    
                    if text and chat_id and user_id:
                        print(f"Command from {user_id}: {text[:50]}")
                        
                        # Write command to temp file
                        with open('/tmp/telegram_cmd.txt', 'w') as f:
                            f.write(text)
                        
                        # Run script
                        env = os.environ.copy()
                        env['TELEGRAM_USER_ID'] = user_id
                        
                        try:
                            result = subprocess.run(
                                ['/bin/bash', f'{PROJECT_DIR}/scripts/telegram-publish.sh', '/tmp/telegram_cmd.txt'],
                                capture_output=True, text=True, timeout=120,
                                cwd=PROJECT_DIR, env=env
                            )
                            output = (result.stdout + result.stderr).strip()
                        except Exception as e:
                            output = f"Error: {str(e)}"
                        
                        # Send response
                        output_lines = output.split('\n')[:25]
                        response = "```\n" + "\n".join(output_lines) + "\n```"
                        send_message(chat_id, response)
                
                with open(OFFSET_FILE, 'w') as f:
                    f.write(str(offset))
            
            time.sleep(3)
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()
