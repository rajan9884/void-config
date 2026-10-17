#!/usr/bin/env python3
# .config/quickshell/plugins/clipboard/clipboard.py
"""Clipboard plugin backend: capture / paste / open for the history menu.

Single backend for plugins/clipboard/Clipboard.qml. Stdlib only, no shell:
every external program is exec'd by argv, and clipboard bytes are piped via
stdin, so hostile clipboard content can never inject commands. The QML side
owns the history file (sole writer); this script only reads it.

State lives under $XDG_STATE_HOME/theme (default ~/.local/state/theme):
  clipboard-history.json   [{type:"text",text} | {type:"image",path,mime,capturedAt}]
  clipboard-images/        sha256-named image payloads (content-deduped)

Usage:
  clipboard.py capture [text|image/MIME]   stdin bytes -> one JSON entry on stdout
  clipboard.py capture                     snapshot the current selection itself
  clipboard.py paste --index N [--copy-only]
  clipboard.py open  --index N             images/files -> xdg-open, text -> copy
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

HOME = Path.home()
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "theme"
HISTORY = STATE_DIR / "clipboard-history.json"
IMAGE_DIR = STATE_DIR / "clipboard-images"
HISTORY_LIMIT = 300

IMAGE_MIMES = ("image/png", "image/jpeg", "image/webp", "image/gif",
               "image/bmp", "image/tiff")
TEXT_MIMES = ("text/plain", "text/plain;charset=utf-8", "UTF8_STRING", "STRING")

EXT_FOR_MIME = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp",
                "image/gif": "gif", "image/bmp": "bmp", "image/tiff": "tiff"}


def die(msg, code=1):
    print(f"clipboard: {msg}", file=sys.stderr)
    sys.exit(code)


def warn(msg):
    print(f"clipboard: warning: {msg}", file=sys.stderr)


def emit(entry):
    print(json.dumps(entry, ensure_ascii=False))


def selection_types():
    """MIME types currently offered by the Wayland selection (best effort)."""
    if not shutil.which("wl-paste"):
        return []
    try:
        r = subprocess.run(["wl-paste", "--list-types"], stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=5)
    except Exception:
        return []
    if r.returncode != 0:
        return []
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]


def sensitive_selection(types):
    if os.environ.get("CLIPBOARD_STATE") == "sensitive":
        return True
    return "x-kde-passwordManagerHint" in types


def decode_text(raw):
    """Clipboard bytes -> str, or None when there is nothing worth storing."""
    if not raw or not raw.strip():
        return None
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        try:
            text = raw.decode("utf-16")
        except Exception:
            return None
    elif len(raw) % 2 == 0 and all(raw[i + 1] == 0 for i in range(0, len(raw), 2)
                                   if raw[i] != 0) and b"\x00" in raw:
        # BOM-less UTF-16LE: every second byte NUL (the pattern hit by some apps).
        try:
            text = raw.decode("utf-16-le")
        except Exception:
            text = raw.decode("utf-8", errors="replace")
    elif len(raw) % 2 == 0 and all(raw[i] == 0 for i in range(1, len(raw), 2)
                                   if raw[i - 1] != 0) and b"\x00" in raw:
        try:
            text = raw.decode("utf-16-be")
        except Exception:
            text = raw.decode("utf-8", errors="replace")
    else:
        text = raw.decode("utf-8", errors="replace")
    text = text.replace("\x00", "")
    return text if text.strip() else None


def capture_text(payload):
    text = decode_text(payload)
    if text is None:
        return  # silent: nothing worth storing
    emit({"type": "text", "text": text})


def capture_image(mime, payload):
    ext = EXT_FOR_MIME.get(mime)
    if ext is None:
        return  # unsupported image flavor: ignore
    if not payload:
        return
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(payload).hexdigest()
    dest = IMAGE_DIR / f"{digest}.{ext}"
    if not dest.exists():
        # mktemp + rename: atomic, no half-written image on crash.
        fd, tmp = tempfile.mkstemp(dir=IMAGE_DIR, prefix=".capture-")
        try:
            with os.fdopen(fd, "wb") as f:
                f.write(payload)
            os.replace(tmp, dest)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
    emit({"type": "image", "mime": mime, "path": str(dest),
          "capturedAt": datetime.now().strftime("%A %H:%M")})


def wl_paste_bytes(mime, timeout=2):
    try:
        r = subprocess.run(["wl-paste", "--type", mime], stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=timeout)
    except Exception:
        return None
    return r.stdout if r.returncode == 0 else None


def cmd_capture(a):
    """Watch target for `wl-paste --watch` (payload on stdin, kind in argv),
    or with no kind: snapshot the current selection itself."""
    if sensitive_selection(selection_types()):
        return
    if a.kind is None:
        types = selection_types()
        for mime in IMAGE_MIMES:
            if mime in types:
                payload = wl_paste_bytes(mime)
                if payload:
                    capture_image(mime, payload)
                return
        if any(t in types for t in TEXT_MIMES) or any(t.startswith("text/") for t in types):
            payload = wl_paste_bytes("text")
            if payload:
                capture_text(payload)
        return
    if a.kind == "text":
        capture_text(sys.stdin.buffer.read())
    elif a.kind == "image" or a.kind.startswith("image/"):
        mime = "image/png" if a.kind == "image" else a.kind
        capture_image(mime, sys.stdin.buffer.read())
    else:
        die(f"unknown capture kind: {a.kind!r}")


def load_history():
    try:
        data = json.loads(HISTORY.read_text())
    except FileNotFoundError:
        die(f"no history yet ({HISTORY})", 2)
    except Exception as e:
        die(f"unreadable history {HISTORY}: {e}", 2)
    if not isinstance(data, list):
        die(f"unreadable history {HISTORY}: not a list", 2)
    return data


def entry_at(index):
    try:
        i = int(index)
    except (TypeError, ValueError):
        die(f"bad index: {index!r}", 2)
    history = load_history()
    if i < 0 or i >= len(history):
        die(f"index {i} out of range (0..{len(history) - 1})", 2)
    entry = history[i]
    if not isinstance(entry, dict) or entry.get("type") not in ("text", "image"):
        die(f"index {i} is not a clipboard entry", 2)
    return entry


def wl_copy(payload, mime=None):
    if not shutil.which("wl-copy"):
        die("wl-copy not found", 3)
    cmd = ["wl-copy"] if mime is None else ["wl-copy", "--type", mime]
    r = subprocess.run(cmd, input=payload, capture_output=True, timeout=10)
    if r.returncode != 0:
        die(f"wl-copy failed: {r.stderr.decode(errors='replace').strip()}", 3)


def shift_insert():
    """Type the pasted selection into the focused window (best effort)."""
    if not shutil.which("wtype"):
        warn("wtype not found; pasted to clipboard only (press Shift+Insert manually)")
        return
    r = subprocess.run(["wtype", "-M", "shift", "-k", "Insert", "-m", "shift"],
                       stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
    if r.returncode != 0:
        warn(f"wtype failed: {r.stderr.decode(errors='replace').strip()}")


def cmd_paste(a):
    entry = entry_at(a.index)
    if entry["type"] == "text":
        wl_copy(str(entry.get("text", "")).encode("utf-8", errors="replace"))
    else:
        path = Path(str(entry.get("path", "")))
        if not path.is_file():
            die(f"image file is gone: {path}", 2)
        wl_copy(path.read_bytes(), entry.get("mime") or "image/png")
    if not a.copy_only:
        shift_insert()


def cmd_open(a):
    """Images/files open in their viewer; plain text lands on the clipboard."""
    entry = entry_at(a.index)
    if entry["type"] == "image":
        path = str(entry.get("path", ""))
        targets = [path] if path else []
    else:
        targets = [l[7:] for l in str(entry.get("text", "")).splitlines()
                   if l.startswith("file://")]
        try:
            from urllib.parse import unquote
            targets = [unquote(t) for t in targets]
        except Exception:
            pass
    if targets:
        if not shutil.which("xdg-open"):
            die("xdg-open not found", 3)
        for t in targets:
            if not Path(t).exists():
                warn(f"not found: {t}")
                continue
            subprocess.Popen(["xdg-open", t], stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    wl_copy(str(entry.get("text", "")).encode("utf-8", errors="replace"))
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "Clipboard", "Entry copied to clipboard"],
                       stdin=subprocess.DEVNULL, capture_output=True, timeout=5)
    else:
        print("clipboard: entry copied to clipboard")


def main():
    ap = argparse.ArgumentParser(prog="clipboard.py")
    sp = ap.add_subparsers(dest="cmd", required=True)
    s = sp.add_parser("capture"); s.add_argument("kind", nargs="?"); s.set_defaults(f=cmd_capture)
    s = sp.add_parser("paste"); s.add_argument("--index", required=True); s.add_argument("--copy-only", action="store_true"); s.set_defaults(f=cmd_paste)
    s = sp.add_parser("open"); s.add_argument("--index", required=True); s.set_defaults(f=cmd_open)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
