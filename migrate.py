import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    has_import = "package:flutter_screenutil/flutter_screenutil.dart" in content
    
    if 'package:flutter/' not in content:
         return

    new_content = content

    new_content = re.sub(r'(width:\s*)([0-9]+(?:\.[0-9]+)?)(?!\.w|\.h|\.sp|\.r|\.sh|\.sw)', r'\1\2.w', new_content)
    new_content = re.sub(r'(height:\s*)([0-9]+(?:\.[0-9]+)?)(?!\.w|\.h|\.sp|\.r|\.sh|\.sw)', r'\1\2.h', new_content)
    new_content = re.sub(r'(fontSize:\s*)([0-9]+(?:\.[0-9]+)?)(?!\.w|\.h|\.sp|\.r|\.sh|\.sw)', r'\1\2.sp', new_content)
    new_content = re.sub(r'(Radius\.circular\()([0-9]+(?:\.[0-9]+)?)(\))', r'\1\2.r\3', new_content)

    if new_content != content:
        if not has_import:
            # Need to import it at the top. Let's find first import.
            new_content = re.sub(
                r'(import\s+[^;]+;)', 
                r"\1\nimport 'package:flutter_screenutil/flutter_screenutil.dart';", 
                new_content, 
                count=1
            )
        
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

def main():
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))

if __name__ == "__main__":
    main()
