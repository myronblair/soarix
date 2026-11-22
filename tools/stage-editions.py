#!/usr/bin/env python3
"""stage-editions.py - work out what each Soarix edition receives, from editions/manifest.json.

  python tools/stage-editions.py OUTDIR            lay out OUTDIR/<edition>/tree (files), exec.txt, packages.txt, after.txt
  python tools/stage-editions.py --check           look for mistakes (launchers without a program, and so on)

The rule: an item belongs to the edition of the folder it is in and to every edition above that one
(core -> desktop -> server). So a tool added to system_files reaches all three editions, a desktop window
reaches desktop and server, and a server tool stays on the server. The manifest can list exceptions.
"""
import json
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EDITIONS = ["core", "desktop", "server"]


def manifest():
    return json.load(open(os.path.join(ROOT, "editions", "manifest.json"), encoding="utf-8"))


def ancestors(m, ed):
    """The edition itself and every edition it builds on (server -> desktop -> core)."""
    out, cur = [ed], ed
    while cur in m.get("inherits", {}):
        cur = m["inherits"][cur]
        out.append(cur)
    return out


def files_for(m, ed):
    """{path inside the image: path in the repo} for one edition."""
    inc = set(ancestors(m, ed))
    tier_of = {t["folder"]: t["tier"] for t in m["tiers"]}
    out = {}
    for folder, tier in tier_of.items():
        base = os.path.join(ROOT, folder)
        for dp, _dn, fn in os.walk(base):
            for f in fn:
                full = os.path.join(dp, f)
                rel = os.path.relpath(full, base).replace(os.sep, "/")
                if rel.split("/")[0] not in m["only_these_subfolders"] or f in (".gitkeep", "Containerfile") or f.endswith((".pyc",)):
                    continue
                repo = folder + "/" + rel
                allowed = m.get("exceptions", {}).get(repo)
                if (ed in allowed) if allowed is not None else (tier in inc):
                    out[rel] = full
    return out


def packages_for(m, ed):
    inc = set(ancestors(m, ed))
    out = []
    for g in m.get("packages", []):
        if g["tier"] in inc:
            out += [p for p in g["packages"] if p not in out]
    return out


def stage(outdir):
    m = manifest()
    for ed in EDITIONS:
        d = os.path.join(outdir, ed)
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(os.path.join(d, "tree"))
        files = files_for(m, ed)
        execs = []
        for rel, full in sorted(files.items()):
            dst = os.path.join(d, "tree", rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            data = open(full, "rb").read().replace(b"\r\n", b"\n") if not full.endswith((".png", ".jpg", ".ico")) else open(full, "rb").read()
            open(dst, "wb").write(data)
            if any(rel.startswith(x + "/") for x in m["executable_folders"]):
                execs.append("/" + rel)
        open(os.path.join(d, "exec.txt"), "w", newline="\n").write("\n".join(execs) + "\n")
        open(os.path.join(d, "packages.txt"), "w", newline="\n").write(" ".join(packages_for(m, ed)) + "\n")
        after = []
        for e in ancestors(m, ed)[::-1]:
            after += m.get("after_install", {}).get(e, [])
        open(os.path.join(d, "after.txt"), "w", newline="\n").write("\n".join(after) + "\n")
        print("%-8s %3d files (%d programs), %d packages" % (ed, len(files), len(execs), len(packages_for(m, ed))))


def check():
    """Every launcher must start a program that its edition has, and every edition must be able to boot."""
    m = manifest()
    bad = 0
    for ed in EDITIONS:
        files = files_for(m, ed)
        have = {os.path.basename(r) for r in files if any(r.startswith(x + "/") for x in m["executable_folders"])}
        have |= {"foot", "firefox", "nmtui", "xdg-open", "system-config-printer", "nm-connection-editor", "gnome-software", "soarix-session"}
        for rel, full in files.items():
            if not rel.endswith(".desktop"):
                continue
            for ln in open(full, encoding="utf-8").read().splitlines():
                mo = re.match(r"(?:Exec|TryExec)=(\S+)", ln)
                if mo and mo.group(1).startswith("soarix-") and mo.group(1) not in have:
                    print("[%s] %s starts %s, which this edition does not have" % (ed, rel, mo.group(1)))
                    bad += 1
    for ed in EDITIONS:
        print("%-8s ok" % ed if not bad else "")
    return 1 if bad else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        sys.exit(check())
    if len(sys.argv) == 2:
        stage(sys.argv[1])
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
