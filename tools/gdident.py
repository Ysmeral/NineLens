import re, sys

path = sys.argv[1] if len(sys.argv) > 1 else r"D:\deepseeek\nbr_cheat\nbr_cheat.gd"
src = open(path, encoding="utf-8").read()

# strip comments and strings (keep structure)
def strip(src):
    out = []
    i = 0
    n = len(src)
    in_str = None
    while i < n:
        c = src[i]
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
            out.append(" ")
            i += 1
            continue
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)

code = strip(src)
lines = code.splitlines()

declared = set()
for m in re.finditer(r"^\s*(?:var|const)\s+([A-Za-z_]\w*)", code, re.M):
    declared.add(m.group(1))
for m in re.finditer(r"^\s*func\s+([A-Za-z_]\w*)\s*\(([^)]*)\)", code, re.M):
    declared.add(m.group(1))
    params = m.group(2)
    for p in params.split(","):
        p = p.strip()
        pm = re.match(r"([A-Za-z_]\w*)", p)
        if pm:
            declared.add(pm.group(1))
for m in re.finditer(r"\bfor\s+([A-Za-z_]\w*)", code):
    declared.add(m.group(1))
for m in re.finditer(r"\bvar\s+([A-Za-z_]\w*)", code):
    declared.add(m.group(1))
for m in re.finditer(r"\bconst\s+([A-Za-z_]\w*)", code):
    declared.add(m.group(1))
for m in re.finditer(r"match\s+\w+:", code):
    pass

# builtins / globals we allow
allow = set("""
_ready _process _input _draw _init _exit _physics_process _unhandled_input
self true false null not and or in is as if else elif for while match break continue return
pass var const func class extends enum static signal breakpoint
Color Vector2 Vector3 Rect2 Basis Transform3D Quaternion Node Node2D Node3D Control CanvasLayer Camera3D
CollisionShape3D BoxShape3D CylinderShape3D SphereShape3D CharacterBody3D RayCast3D MeshInstance3D
ImmediateMesh QuadMesh ThemeDB Engine Input InputEventMouseMotion InputEventMouseButton Time FileAccess
DirAccess ProjectSettings OS DisplayServer RenderingServer Tween SceneTree Callable Variant Dictionary
Array PackedByteArray String StringName TAU PI KEY_F5 KEY_F6 KEY_F7 KEY_F8 KEY_F9 KEY_F10 KEY_F11 KEY_F12
KEY_T KEY_B KEY_L KEY_P KEY_A KEY_O KEY_Z KEY_X KEY_R KEY_BRACKETLEFT KEY_BRACKETRIGHT KEY_BACKSLASH
MOUSE_BUTTON_LEFT HORIZONTAL_ALIGNMENT_LEFT PROPERTY_USAGE_SCRIPT_VARIABLE Vector4 PackedVector2Array
""".split())

# find identifiers used as members start with underscore, or in a suspicious list
suspects = {}
for ln, line in enumerate(lines, 1):
    for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)", line):
        name = m.group(1)
        if name in declared or name in allow:
            continue
        # skip if followed by '(' and looks like a builtin call we haven't listed
        after = line[m.end():m.end()+1]
        if after == "(":
            continue
        if name.startswith("_") or name in ("lock_aim", "show_best", "aim_theta"):
            suspects.setdefault(name, []).append(ln)

if suspects:
    print("SUSPECT undeclared identifiers:")
    for k, v in suspects.items():
        print(f"  {k}: lines {v[:8]}")
else:
    print("no suspicious undeclared identifiers")

# also: draw call arity sanity for known risky ones
print("declared vars/funcs:", len(declared))