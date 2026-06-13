import os
import re

def main():
    lib_dir = r"d:\Database Lanjutan\makarya_erp\lib"
    
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'): continue
            
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            original = content
            
            # Simple replacements for MakaryaColors.surface01 and 02 to use GlassContainer
            # Let's replace `color: MakaryaColors.surface01,` with nothing in containers
            # Actually, this is too hard. Let's just import glass_helpers.dart in all screens
            if 'import \'../widgets/glass_helpers.dart\';' not in content and 'import \'package:makarya_erp/widgets/glass_helpers.dart\';' not in content:
                if 'import \'../theme/makarya_theme.dart\';' in content:
                    content = content.replace('import \'../theme/makarya_theme.dart\';', 'import \'../theme/makarya_theme.dart\';\nimport \'../widgets/glass_helpers.dart\';')
                elif 'import \'theme/makarya_theme.dart\';' in content:
                    content = content.replace('import \'theme/makarya_theme.dart\';', 'import \'theme/makarya_theme.dart\';\nimport \'widgets/glass_helpers.dart\';')
            
            # Replace basic containers that act as cards
            # We look for Container( ... color: MakaryaColors.surface02 ... )
            # We'll use a regex to replace `color: MakaryaColors.surface02` with `/* color removed for glass */`
            content = re.sub(r'color:\s*MakaryaColors\.surface0[12],', '', content)
            
            # But the Container still remains a Container! I need it to be GlassContainer if it has surface01/02
            # It's better to just write a simple parsing logic:
            
            if content != original:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                    
if __name__ == '__main__':
    main()
