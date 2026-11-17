#!/usr/bin/env python3
# makes a smaller liberty file
#   --keep netlist.v    only the cells used in a netlist (for gate level sim models)
#   --exclude lists...  drop the cells in openlane's no_synth / drc_exclude lists (for synthesis)

import re, sys, fnmatch
lib, out, mode, *args = sys.argv[1:]
if mode == '--keep':
    keep = set(re.findall(r'\b(sky130_fd_sc_hd__\w+)\s+\S+\s*\(', open(args[0]).read()))
    # the ICG cell has no logic function in the .lib, it gets a hand written model instead
    keep -= {'sky130_fd_sc_hd__dlclkp_1'}
    want = lambda n: n in keep
else:
    pats = [l.strip() for f in args for l in open(f) if l.strip() and not l.startswith('#')]
    want = lambda n: not any(fnmatch.fnmatch(n, p) for p in pats)
txt = open(lib).read()
first = re.search(r'\n\s*cell\s*\(', txt).start()
parts, drop = [], 0
# copy each cell (...) { ... } block by counting braces
for m in re.finditer(r'\n\s*cell\s*\(\s*"?(\w+)"?\s*\)\s*\{', txt):
    i, depth = m.end(), 1
    while depth:
        c = txt[i]; depth += (c == '{') - (c == '}'); i += 1
    if want(m.group(1)): parts.append(txt[m.start():i])
    else: drop += 1
open(out, 'w').write(txt[:first] + '\n'.join(parts) + '\n}\n')
print(f"kept {len(parts)} cells, dropped {drop}")
