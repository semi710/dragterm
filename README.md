# dragterm

Drag and drop from the command line. Run `drag <files>` and a file icon appears
under your cursor — move it where you want, click to drop.

This is a fork of [Wevah/dragterm](https://github.com/Wevah/dragterm), which
itself is a modernized rewrite of [ciaran/drag](https://github.com/ciaran/drag)
(updated to use modern AppKit drag-and-drop APIs, since starting a drag without
a view no longer works on current macOS).

## Features

- **Cursor-following icon.** The icon tracks your cursor so you can position it
  freely before dropping — no need to hold the button while moving.
- **Shift to passthrough.** Hold **Shift** to fade the icon and let clicks pass
  through to whatever is behind it (Finder, desktop, other apps). Release Shift
  to bring the icon back and drop.
- **Keyboard cancel.** Press `Esc`, `q`, `Ctrl-C`, or `Ctrl-D` to cancel. The
  app runs in the background so keystrokes still reach your terminal.
- **Multiple files.** Pass as many paths as you like.
- **Trash support.** Drop onto the Trash to move files there.
- **No accessibility permission required.** Cursor tracking polls
  `NSEvent.mouseLocation`; passthrough polls the modifier flag state.

## Usage

```
drag <files>
```

An icon appears under the cursor and follows it as you move.

- **Move the cursor** → the icon follows.
- **Hold Shift** → the icon fades and clicks pass through to apps behind it.
- **Click and hold, drag, release** → drops the file(s) at the destination.
- **`Esc` / `q` / `Ctrl-C` / `Ctrl-D`** → cancels.

### Examples

```sh
drag ~/Desktop/screenshot.png
drag file1.txt file2.txt file3.txt
drag *.png
```

## Building

Requires Xcode (not just Command Line Tools).

```sh
xcodebuild -project dragterm.xcodeproj -scheme dragterm
```

The built binary lands under `~/Library/Developer/Xcode/DerivedData/dragterm-*/Build/Products/Debug/drag`
(or `Release` if you pass `-configuration Release`).

### Install

Copy the binary somewhere in your `PATH`:

```sh
mkdir -p ~/bin
cp ~/Library/Developer/Xcode/DerivedData/dragterm-*/Build/Products/Debug/drag ~/bin/
```

Ensure `~/bin` is on your `PATH` (add `export PATH="$HOME/bin:$PATH"` to your
shell config), then:

```sh
drag <files>
```

### First run

macOS may prompt for accessibility or input monitoring permission on first
launch. Grant it under **System Settings → Privacy & Security**.

## Nix

The flake is at `github:semi710/dragterm` and exposes the `drag` package for
`aarch64-darwin` and `x86_64-darwin`.

### Run

```sh
nix run github:semi710/dragterm -- <files>
```

### Build

```sh
nix build github:semi710/dragterm
./result/bin/drag <files>
```

### Devshell

```sh
nix develop
```

Includes `just` and pre-commit hooks (treefmt). Use `just` to drive common tasks:

```sh
just          # list commands
just build    # nix build .#drag
just run FILE # nix run .#drag -- FILE
```

### As a flake input

Add to your flake:

```nix
inputs.dragterm.url = "github:semi710/dragterm";
```

Then consume the package, e.g. via an overlay:

```nix
drag = inputs.dragterm.packages.${final.stdenv.hostPlatform.system}.drag;
```

## How it works

`drag` creates a transparent, borderless window centered on the cursor and
runs it as a background (accessory) app so the terminal keeps keyboard focus.
The window recenters on the cursor each event tick, so the file icon follows
your mouse without holding a button. Holding Shift toggles
`ignoresMouseEvents` and fades the window so clicks reach apps behind it. A
mouse-down on the icon starts a standard `NSDraggingSession` to perform the
actual drop.

## License

See [LICENSE](LICENSE).
