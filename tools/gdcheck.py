import re, sys, io

path = r"D:\deepseeek\nbr_cheat\nbr_cheat.gd"
src = open(path, encoding="utf-8").read()
lines = src.splitlines()

# ---- strip strings & comments, then check bracket balance
def strip_line(s):
    out = []
    i = 0
    in_str = None
    while i < len(s):
        c = s[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c in "\"'":
            in_str = c
            i += 1
            continue
        if c == "#":
            break
        out.append(c)
        i += 1
    return "".join(out)

depth = {"(": 0, "[": 0, "{": 0}
pairs = {")": "(", "]": "[", "}": "{"}
for ln, s in enumerate(lines, 1):
    t = strip_line(s)
    for ch in t:
        if ch in depth:
            depth[ch] += 1
        elif ch in pairs:
            depth[pairs[ch]] -= 1
            if depth[pairs[ch]] < 0:
                print(f"UNBALANCED close {ch} at line {ln}: {s.strip()[:80]}")
print("balance:", depth)

# ---- indentation: tabs only, no mixed
bad = []
for ln, s in enumerate(lines, 1):
    if not s.strip():
        continue
    lead = s[: len(s) - len(s.lstrip())]
    if " " in lead:
        bad.append((ln, s[:60]))
print("space-indent lines:", len(bad))
for b in bad[:5]:
    print("   ", b)

# ---- block openers must end with ':'
openers = re.compile(r"^(func|if|elif|else|for|while|match|class|enum)\b")
badblock = []
for ln, s in enumerate(lines, 1):
    st = s.strip()
    if not st or st.startswith("#"):
        continue
    if openers.match(st):
        if not st.endswith(":") and not st.endswith(": #") and not re.search(r":\s*(#.*)?$", st):
            badblock.append((ln, st[:70]))
print("block headers missing ':' :", len(badblock))
for b in badblock[:5]:
    print("   ", b)

# ---- declared vars vs used
decl = set(re.findall(r"^\s*var\s+([A-Za-z_]\w*)", src, re.M))
print("var count:", len(decl))
for name in ["auto_aim", "auto_fire", "_auto_t", "_px_budget", "_fire_cd", "_cal_fail", "_cal_gain_t"]:
    print(f"  declared {name}: {name in decl}")

# ---- duplicate function definitions
funcs = re.findall(r"^func\s+([A-Za-z_]\w*)", src, re.M)
dups = {f for f in funcs if funcs.count(f) > 1}
print("dup funcs:", dups if dups else "none", "total funcs:", len(funcs))