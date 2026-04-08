import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    new_content = content
    # Remove const before constructors and classes, like const Text(...)
    new_content = re.sub(r'\bconst\s+([A-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_]+)?\s*\()', r'\1', new_content)
    
    # Remove const before arrays or maps
    new_content = re.sub(r'\bconst\s+\[', r'[', new_content)
    new_content = re.sub(r'\bconst\s+\{', r'{', new_content)

    # Sometimes const is used without parenthesis immediately, like const EdgeInsetsGeometry
    new_content = re.sub(r'\bconst\s+([A-Z_][a-zA-Z0-9_]*)', r'\1', new_content)

    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Removed consts from {filepath}")

if __name__ == "__main__":
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))
