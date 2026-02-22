import os
import subprocess
import json
import urllib.request
import urllib.parse
import time

TOKEN = "8406932136:AAEyww7CsenS5sxz_A0oV5pjumrlD2KOEo0"
OFFSET_FILE = "/tmp/telegram-bot-offset"

def send_message(chat_id, text):
    data = urllib.parse.urlencode({
        'chat_id': chat_id,
        'text': text[:4000],
        'parse_mode': 'Markdown'
    }).encode()
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{TOKEN}/sendMessage",
        data=data, method="POST"
    )
    try:
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        print(f"Send error: {e}")

def get_updates():
    offset = "0"
    try:
        with open(OFFSET_FILE) as f:
            offset = f.read().strip()
    except:
        pass
    
    url = f"https://api.telegram.org/bot{TOKEN}/getUpdates?offset={offset}&timeout=30"
    try:
        resp = urllib.request.urlopen(url, timeout=35)
        return json.loads(resp.read().decode())
    except Exception as e:
        print(f"Get updates error: {e}")
        return {"ok": False, "result": []}

def process_update(update):
    msg = update.get("message", {})
    chat_id = msg.get("chat", {}).get("id")
    user_id = str(msg.get("from", {}).get("id", ""))
    text = msg.get("text", "")
    
    if not (text and chat_id and user_id):
        return
    
    # Write command
    with open("/tmp/telegram_cmd.txt", "w") as f:
        f.write(text)
    
    # Run publish script
    env = os.environ.copy()
    env["TELEGRAM_USER_ID"] = user_id
    
    result = subprocess.run(
        ["/bin/bash", "/root/sap-vim-dev-blog/scripts/telegram-publish.sh", "/tmp/telegram_cmd.txt"],
        capture_output=True, text=True, timeout=60, env=env,
        cwd="/root/sap-vim-dev-blog"
    )
    
    output = (result.stdout or "") + (result.stderr or "")
    
    # Send response
    send_message(chat_id, "```\n" + output[:3500] + "\n```")
    
    # Update offset
    with open(OFFSET_FILE, "w") as f:
        f.write(str(update.get("update_id", 0) + 1))
    
    print(f"Processed: {user_id} -> {text[:30]}")

print("Bot starting...")
while True:
    data = get_updates()
    if data.get("ok") and data.get("result"):
        for update in data["result"]:
            process_update(update)
    time.sleep(2)
