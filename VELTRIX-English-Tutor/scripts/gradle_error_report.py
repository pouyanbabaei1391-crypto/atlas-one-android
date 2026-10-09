#!/usr/bin/env python3
"""Extract helpful Gradle errors into GitHub's summary. Never claim success."""
from pathlib import Path
import re, sys
f=Path(sys.argv[1])
t=f.read_text(encoding='utf8',errors='replace').splitlines()
expressions=[r'^\s*> What went wrong:', r'\be: file:', r'\berror:', r'^\s*FAILURE:', r'^\s*> Task .* FAILED', r'^\s*Execution failed for task', r'^\s*Could not resolve', r'^\s*Could not find', r'^\s*CMake Error', r'^\s*ninja: build stopped', r'^\s*Caused by:', r'not found', r'Could not compile']
found=[(i,line) for i,line in enumerate(t) if any(re.search(p,line,re.I) for p in expressions)]
# Prefer the actionable compiler diagnostics / What went wrong over a Java stacktrace.
first=[]
for i,line in found:
    if len(line)>350: line=line[:350]+'…'
    if line.strip() not in first:
        first.append(f'Log line {i+1}: {line}')
    if len(first)>=24:break
print('```text')
if first:
    print('\n'.join(first))
else:
    print('No explicit diagnostic matched; last 65 lines follow:')
    print('\n'.join(t[-65:])[:14000])
print('```')
print('Build exit code was non-zero. Full build log is available in VELTRIX-FAILURE-DIAGNOSTICS artifact.')
