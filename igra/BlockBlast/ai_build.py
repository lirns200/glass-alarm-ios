import os
import random
import subprocess
import sys
import re
from pathlib import Path

def main():
    """
    Universal AI Build Tool for Block Blast (Engine: Glass Alarm).
    """
    print("=== Block Blast: Universal AI Build Tool ===")
    
    root = Path(__file__).parent
    
    # 1. Update Swift Unique ID
    swift_path = root / "GlassAlarm/App/GlassAlarmApp.swift"
    if swift_path.exists():
        content = swift_path.read_text(encoding="utf-8")
        unique_id = "".join(random.choices("0123456789abcdef", k=32))
        pattern = r'private static let buildUniqueId = "[^"]+"'
        if re.search(pattern, content):
            new_content = re.sub(pattern, f'private static let buildUniqueId = "{unique_id}"', content)
            swift_path.write_text(new_content, encoding="utf-8")
            print(f"[OK] Updated build ID: {unique_id}")
    else:
        print(f"[ERROR] GlassAlarmApp.swift not found at {swift_path}")
            
    # 2. Trigger Build
    print("[INFO] Triggering buildIPA.py...")
    try:
        build_script = root / "buildIPA.py"
        subprocess.run([sys.executable, str(build_script), "--skip-auth"], check=True)
        print("=== BUILD SUCCESSFUL ===")
    except Exception as e:
        print(f"=== BUILD FAILED: {e} ===")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
