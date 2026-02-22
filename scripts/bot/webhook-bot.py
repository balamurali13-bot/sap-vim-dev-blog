from flask import Flask, request
import os
import subprocess
import json

app = Flask(__name__)

BOT_TOKEN = "8406932136:AAEyww7CsenS5sxz_A0oV5pjumrlD2KOEo0"

def send_message(chat_id, text):
    import urllib.request, urllib.parse
    data = urllib.parse.urlencode({
        'chat_id': chat_id,
        'text': text[:4000],
        'parse_mode': 'Markdown'
    }).encode()
    req = urllib.request.Request(
        f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage',
        data=data, method='POST'
    )
    urllib.request.urlopen(req)

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json()
    
    if data and 'message' in data:
        msg = data['message']
        chat_id = msg['chat']['id']
        user_id = str(msg['from']['id'])
        text = msg.get('text', '')
        
        # Write command to temp file
        with open('/tmp/telegram_cmd.txt', 'w') as f:
            f.write(text)
        
        # Run publish script
        env = os.environ.copy()
        env['TELEGRAM_USER_ID'] = user_id
        
        result = subprocess.run(
            ['/bin/bash', '/root/sap-vim-dev-blog/scripts/telegram-publish.sh', '/tmp/telegram_cmd.txt'],
            capture_output=True, text=True, timeout=120, env=env,
            cwd='/root/sap-vim-dev-blog'
        )
        
        output = result.stdout + result.stderr
        send_message(chat_id, '```\n' + output[:3500] + '\n```')
    
    return "ok"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
