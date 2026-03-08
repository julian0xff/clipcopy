# clipcopy

Tiny cross-platform clipboard CLI for macOS and Linux.

- No runtime dependencies
- Single shell script
- Works well for agent workflows

## Install

Local checkout:

```bash
cd clipcopy
./install.sh
```

Remote install (after pushing to GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/julian0xff/clipcopy/main/install.sh | sh
```

Default install path: `~/.local/bin/clipcopy`

## Usage

```bash
clipcopy "Research summary"
echo "Research summary" | clipcopy
clipcopy -p "Done"
clipcopy -- "-text-starting-with-dash"
```

## Options

| Flag | Description |
|------|-------------|
| `-p`, `--print` | Print copied text to stdout |
| `-h`, `--help` | Show help message |
| `--` | Stop flag parsing |

## Clipboard backend order

1. `pbcopy` (macOS)
2. `wl-copy` (Linux Wayland)
3. `xclip` (Linux X11)
4. `xsel` (Linux X11)

Backends are tried in order — if one fails at runtime (e.g. `wl-copy` on an X11 session), the next is attempted. If none work, the command exits with an install hint.
