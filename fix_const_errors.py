import os
import re

def main():
    log_file = '/tmp/analyze.log'
    if not os.path.exists(log_file):
        return
        
    with open(log_file, 'r') as f:
        log_content = f.read()

    # The format in analyze.log is typically:
    # error • Extension methods can't be used in constant expressions • lib/all_transactions_screen.dart:1059:57 • const_eval_extension_method
    
    pattern = re.compile(r'error • .* • (lib/.*?\.dart):(\d+):\d+ • const_eval_extension_method')
    
    fixes_per_file = {}
    for match in pattern.finditer(log_content):
        file_path = match.group(1)
        line_num = int(match.group(2))
        
        if file_path not in fixes_per_file:
            fixes_per_file[file_path] = set()
        fixes_per_file[file_path].add(line_num)
        
    for file_path, lines in fixes_per_file.items():
        if not os.path.exists(file_path):
            continue
            
        with open(file_path, 'r') as f:
            file_lines = f.readlines()
            
        modified = False
        for line_num in lines:
            idx = line_num - 1 # 0-indexed
            if idx < len(file_lines):
                # Remove ONLY the word "const " from this specific line
                original = file_lines[idx]
                # Sometimes const is at the very beginning or has spaces around it
                file_lines[idx] = re.sub(r'\bconst\s+', '', file_lines[idx])
                if original != file_lines[idx]:
                    modified = True
                    
        # Extra check: sometimes the 'const ' is on the line above the screenutil method
        # So it's best to also remove const on the line prior just to be safe if it exists
        for line_num in lines:
            idx = line_num - 1 - 1 # line before
            if idx >= 0 and idx < len(file_lines):
                 if '\bconst\s+' in file_lines[idx] or 'const ' in file_lines[idx]:
                     file_lines[idx] = re.sub(r'\bconst\s+', '', file_lines[idx])
                     modified = True
                     
        if modified:
            with open(file_path, 'w') as f:
                f.writelines(file_lines)
            print(f"Fixed const errors in {file_path}")

if __name__ == "__main__":
    main()
