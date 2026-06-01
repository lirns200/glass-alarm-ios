import os
import random
import subprocess
import sys
import re
from pathlib import Path

def main():
    """
    Universal AI Build Tool for Glass Alarm.
    1. Randomizes resources (binary footprint).
    2. Updates unique build identifiers.
    3. Triggers remote GitHub build.
    """
    print("=== Glass Alarm: Universal AI Build Tool ===")
    
    root = Path(__file__).parent.parent
    
    # 1. Randomize Resource (WAV Padding)
    resource_path = root / "GlassAlarm/Resources/crystal.wav"
    if resource_path.exists():
        padding = os.urandom(random.randint(10000, 100000))
        with open(resource_path, "ab") as f:
            f.write(padding)
        print(f"[OK] Added {len(padding)} bytes to resources.")
    
    # 2. Update Swift Unique ID
    swift_path = root / "GlassAlarm/App/GlassAlarmApp.swift"
    if swift_path.exists():
        content = swift_path.read_text(encoding="utf-8")
        unique_id = "".join(random.choices("0123456789abcdef", k=32))
        pattern = r'private static let buildUniqueId = "[a-f0-9]+"'
        if re.search(pattern, content):
            new_content = re.sub(pattern, f'private static let buildUniqueId = "{unique_id}"', content)
            swift_path.write_text(new_content, encoding="utf-8")
            print(f"[OK] Updated build ID: {unique_id}")
            
    # 3. Trigger Build
    print("[INFO] Triggering buildIPA.py...")
    try:
        # Assuming buildIPA.py is in the root
        build_script = root / "buildIPA.py"
        subprocess.run([sys.executable, str(build_script), "--skip-auth"], check=True)
        print("=== BUILD SUCCESSFUL ===")
    except Exception as e:
        print(f"=== BUILD FAILED: {e} ===")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
