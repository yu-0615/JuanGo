#!/usr/bin/env python3
"""Rebuild Sources/PulsoIcon/Icons/LexiIcons.swift with only the icons Lexi uses.

usage: python3 scripts/trim.py <full PulsoIcon checkout> <path to Lexi/Icons.swift>
The keys come from the Icons.table in Icons.swift, plus the icons used directly (.infinity, .dices, .circle).
"""
import glob, os, re, sys

full, icons_swift = sys.argv[1], sys.argv[2]
src = os.path.join(full, 'swift/Sources/PulsoIcon/Icons')
out = os.path.join(os.path.dirname(__file__), '..', 'Sources/PulsoIcon/Icons/LexiIcons.swift')
text = open(icons_swift, encoding='utf-8').read()
keys = sorted(set(re.findall(r'\("([a-z0-9-]+)", (?:true|false)\)', text)) | {'infinity', 'dices', 'circle'})

blocks = {}
for f in sorted(glob.glob(src + '/Icons*.swift')):
    lines = open(f, encoding='utf-8').read().split('\n')
    i = 0
    while i < len(lines):
        m = re.match(r'    public static let (\w+) = PulsoIcon\("(\w+)", "([a-z0-9-]+)"', lines[i])
        if m and m.group(3) in keys:
            j = i
            while lines[j] != '    ])':
                j += 1
            blocks[m.group(3)] = (m.group(1), '\n'.join(lines[i:j + 1]))
            i = j
        i += 1

missing = [k for k in keys if k not in blocks]
if missing:
    sys.exit(f'not in PulsoIcon: {missing}')

body = ('// Only the icons Lexi uses, copied from PulsoIcon (ISC License, see LICENSE) by scripts/trim.py.\n'
        '// To add one: map it in Lexi/Icons.swift, then run scripts/trim.py again.\n\nextension PulsoIcon {\n')
body += '\n'.join(blocks[k][1] for k in keys) + '\n\n'
body += '    public static let iconNames: [String] = [\n' + ''.join(f'        "{k}",\n' for k in keys) + '    ]\n\n'
body += ('    public static func byKey(_ key: String) -> PulsoIcon? {\n        switch key {\n'
         + ''.join(f'        case "{k}": .{blocks[k][0]}\n' for k in keys)
         + '        default: nil\n        }\n    }\n}\n')
open(out, 'w', encoding='utf-8').write(body)
print(f'{len(keys)} icons written to {os.path.normpath(out)}')
