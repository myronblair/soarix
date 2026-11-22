# Soarix editions: build once, every edition that should have it gets it

Soarix has three editions:

| Edition | What it is | Builds on |
|---|---|---|
| **Command line** (core) | the base system, tools and settings | |
| **Desktop** | core plus the graphical desktop, its windows, icons and wallpapers | core |
| **Server** | desktop plus the hosting stack (web, mail, databases, Docker and more) | desktop |

A computer's **license key** decides which edition it may download. The license server refuses the others.
Inside an edition, everything built for it, and for the editions below it, is included.

## The rule

> Put a thing in the folder that fits it best. Every edition that builds on that folder gets it automatically.

| Folder | Goes to |
|---|---|
| `system_files/` | command line, desktop and server |
| `desktop-extra/` | desktop and server |
| `server/` | server only |

Only the `usr/` and `etc/` folders inside each of those are shipped. Programs in `usr/bin` and `usr/libexec` are made executable.

Need an exception (for example a launcher that only makes sense on the server)? Add it to `exceptions` in `manifest.json`.
Need a new package in some editions? Add it to `packages` in `manifest.json` with the folder tier it should start from.

## Checking and publishing

```
python tools/stage-editions.py --check          every launcher must start a program its edition has
tools/set-version.sh 0.3.4                      new version number everywhere
N=21 PREV=20 tools/publish-update.sh            build and publish update 21 for all three editions
```

After publishing, put the release notes in the `soarix-updates` repo (`stable.json` and `testing.json`), commit and push
(GitHub, then Gitea).

## Habits that keep this working

- Build features as a program or command first (works in every edition), and the window second (desktop and server).
  The command-line edition then has the same job done by a command.
- American spelling in everything people read (color, license, organization).
- No quote marks in `Exec=` lines of launchers (the app drawer cannot parse them); use `soarix-window NAME`.
- A new window is a page in `desktop-extra/usr/bin/soarix-app`, plus a launcher in `desktop-extra/usr/share/applications`, an icon
  in `desktop-extra/usr/share/icons/hicolor/scalable/apps`, and a route in `soarix-window`.
- Each update is a small layer on top of the previous image. A full rebuild from the Containerfiles collapses them.
