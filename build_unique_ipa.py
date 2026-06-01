import os
import random
import subprocess
import sys
import re
from pathlib import Path

def main():
    # 1. Modify the resource file
    resource_path = Path("GlassAlarm/Resources/crystal.wav")
    if not resource_path.exists():
        print(f"Error: {resource_path} not found.")
        return 1

    # Create a backup if it doesn't exist
    backup_path = resource_path.with_suffix(".wav.bak")
    if not backup_path.exists():
        import shutil
        shutil.copy2(resource_path, backup_path)
        print(f"Created backup at {backup_path}")

    # Add random padding (between 10KB and 100KB)
    padding_size = random.randint(10240, 102400)
    print(f"Adding {padding_size} bytes of padding to {resource_path}")
    with open(resource_path, "ab") as f:
        f.write(os.urandom(padding_size))

    # 2. Modify the Swift code
    swift_path = Path("GlassAlarm/App/GlassAlarmApp.swift")
    if swift_path.exists():
        print(f"Updating unique build ID in {swift_path}")
        content = swift_path.read_text(encoding="utf-8")
        unique_id = "".join(random.choices("0123456789abcdef", k=32))
        
        # Check if the identifier already exists
        pattern = r'private static let buildUniqueId = "[a-f0-9]+"'
        if re.search(pattern, content):
            new_content = re.sub(pattern, f'private static let buildUniqueId = "{unique_id}"', content)
        else:
            # Insert it if it doesn't exist
            new_content = content.replace(
                "struct GlassAlarmApp: App {",
                f'struct GlassAlarmApp: App {{\n    private static let buildUniqueId = "{unique_id}"'
            )
        swift_path.write_text(new_content, encoding="utf-8")
    else:
        print(f"Warning: {swift_path} not found.")

    # 3. Run the build process
    print("Starting the build process...")
    try:
        result = subprocess.run(
            [sys.executable, "buildIPA.py", "--skip-auth"],
            check=True
        )
        print("Build process completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Build process failed with exit code {e.returncode}")
        return e.returncode

    return 0

if __name__ == "__main__":
    sys.exit(main())
