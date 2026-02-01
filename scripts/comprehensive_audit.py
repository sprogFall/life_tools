import os
import re

def analyze_directory(root_dir):
    stats = {
        'total_files': 0,
        'total_lines': 0,
        'files_with_chinese': [],
        'files_with_magic_numbers': [],
        'files_with_hardcoded_textstyle': [],
        'files_with_hardcoded_colors': [],
        'large_files': [],
        'deeply_nested_files': []
    }

    # Regex patterns
    chinese_pattern = re.compile(r"['\"][^\x00-\x7F]+['\"]") # Matches strings with non-ascii
    magic_padding_pattern = re.compile(r"EdgeInsets\.(all|only|fromLTRB|symmetric)\(.*?[0-9]")
    text_style_pattern = re.compile(r"TextStyle\s*\(")
    color_pattern = re.compile(r"(Color\s*\(|Colors\.[a-z])")
    
    # Walk through directory
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in filenames:
            if not filename.endswith('.dart'):
                continue
            
            filepath = os.path.join(dirpath, filename)
            rel_path = os.path.relpath(filepath, root_dir)
            stats['total_files'] += 1
            
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    line_count = len(lines)
                    stats['total_lines'] += line_count
                    
                    if line_count > 400:
                        stats['large_files'].append((rel_path, line_count))
                    
                    has_chinese = False
                    has_magic = False
                    has_style = False
                    has_color = False
                    max_indent = 0
                    
                    for line in lines:
                        content = line.strip()
                        if content.startswith('//'): continue # Skip comments
                        
                        if not has_chinese and chinese_pattern.search(content):
                            has_chinese = True
                        if not has_magic and magic_padding_pattern.search(content):
                            has_magic = True
                        if not has_style and text_style_pattern.search(content):
                            # Exclude files in theme/ or test/ from style checks if needed, but keeping strict for now
                            if 'ios26_theme.dart' not in rel_path: 
                                has_style = True
                        if not has_color and color_pattern.search(content):
                            if 'ios26_theme.dart' not in rel_path:
                                has_color = True
                        
                        # Simple indentation check (2 spaces per level)
                        indent = len(line) - len(line.lstrip())
                        if indent > 40: # > 20 levels deep? rough heuristic
                            max_indent = max(max_indent, indent)

                    if has_chinese: stats['files_with_chinese'].append(rel_path)
                    if has_magic: stats['files_with_magic_numbers'].append(rel_path)
                    if has_style: stats['files_with_hardcoded_textstyle'].append(rel_path)
                    if has_color: stats['files_with_hardcoded_colors'].append(rel_path)
                    if max_indent > 0: stats['deeply_nested_files'].append((rel_path, max_indent))
                    
            except Exception as e:
                print(f"Error reading {filepath}: {e}")

    return stats

def print_report(stats):
    print("="*40)
    print("      全面代码质量审计报告 (Python 扫描版)")
    print("="*40)
    print(f"扫描文件总数: {stats['total_files']}")
    print(f"代码总行数:   {stats['total_lines']}")
    print("-" * 40)
    
    print(f"\n[1] 包含硬编码中文的文件: {len(stats['files_with_chinese'])} 个")
    # for f in stats['files_with_chinese'][:5]: print(f"  - {f}")
    # if len(stats['files_with_chinese']) > 5: print(f"  ... 以及其他 {len(stats['files_with_chinese'])-5} 个")

    print(f"\n[2] 包含 Magic Number (EdgeInsets) 的文件: {len(stats['files_with_magic_numbers'])} 个")
    
    print(f"\n[3] 硬编码 TextStyle 的文件 (违反 IOS26 规范): {len(stats['files_with_hardcoded_textstyle'])} 个")
    
    print(f"\n[4] 硬编码 Color 的文件: {len(stats['files_with_hardcoded_colors'])} 个")

    print(f"\n[5] 超大文件 (> 400 行) Top 10:")
    sorted_large = sorted(stats['large_files'], key=lambda x: x[1], reverse=True)
    for f, lines in sorted_large[:10]:
        print(f"  - {f} ({lines} 行)")

if __name__ == "__main__":
    # Assuming script is run from project root or scripts dir
    # Try to find lib dir
    base_dir = os.getcwd()
    if os.path.basename(base_dir) == 'scripts':
        base_dir = os.path.dirname(base_dir)
    
    lib_dir = os.path.join(base_dir, 'lib')
    if not os.path.exists(lib_dir):
        # Fallback to absolute path known in env
        lib_dir = r"d:\Projects\android\life_tools\lib"
    
    print(f"Scanning directory: {lib_dir}")
    stats = analyze_directory(lib_dir)
    print_report(stats)
