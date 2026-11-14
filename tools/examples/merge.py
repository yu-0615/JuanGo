#!/usr/bin/env python3
"""Merge generated example sentences (out*.jsonl from the generator) into words.json.
Usage: merge.py <words.json> <out1.jsonl> [out2.jsonl ...]  — only fills entries whose ex is empty."""
import json, sys
path = sys.argv[1]
words = json.load(open(path, encoding='utf-8'))
got = {}
for f in sys.argv[2:]:
    for line in open(f, encoding='utf-8'):
        line = line.strip()
        if not line: continue
        d = json.loads(line)
        if 'en' in d and 'zh' in d: got[d['w']] = d
n = 0
for e in words:
    g = got.get(e['w'])
    if g and not e.get('ex'):
        e['ex'], e['exZh'] = g['en'], g['zh']; n += 1
json.dump(words, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(f'filled {n} examples; {sum(1 for e in words if e.get("ex"))} of {len(words)} entries now have one')
