#!/usr/bin/env python3
"""Keyboard-first installer PTY smoke test. Never uses a real disk."""
import errno
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import time

binary = os.path.abspath(sys.argv[1])

def launch(cols, rows):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    original = termios.tcgetattr(slave)
    def attach():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
    env = dict(os.environ, TERM="xterm-256color")
    p = subprocess.Popen([binary, "install", "--tui-demo"], stdin=slave, stdout=slave,
                         stderr=slave, env=env, preexec_fn=attach)
    return master, slave, p, original

def collect(master, seconds=0.2):
    output = bytearray()
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        if not select.select([master], [], [], 0.03)[0]:
            continue
        try:
            data = os.read(master, 65536)
            if not data:
                break
            output.extend(data)
        except OSError as e:
            if e.errno == errno.EIO:
                break
            raise
    return bytes(output)

def verify_restored(slave, original):
    now = termios.tcgetattr(slave)
    assert now == original, f"PTY flags were not restored:\n{original}\n{now}"

# Full keyboard-only wizard, no graphical session. Enter on review only
# prints the read-only demo preview, never executes any partitioning command.
master, slave, process, original = launch(80, 24)
try:
    output = bytearray(collect(master, 0.35))
    assert b"KOVA LINUX" in output
    for _ in range(7):
        os.write(master, b"\r")
        output.extend(collect(master, 0.13))
    process.wait(timeout=8)
    output.extend(collect(master, 0.3))
    assert process.returncode == 0, output.decode("utf-8", "replace")[-2000:]
    assert b"NO PARTITIONS OR FILES WERE MODIFIED" in output
    assert b"DRY RUN ONLY" in output
    verify_restored(slave, original)
finally:
    if process.poll() is None:
        process.kill()
    os.close(master); os.close(slave)

# 40x15 fits, supports navigation, then Ctrl+C restores saved terminal flags.
master, slave, process, original = launch(40, 15)
try:
    output = bytearray(collect(master, 0.3))
    assert b"KOVA LINUX" in output
    os.write(master, b"\x1b[B\x1b[A")  # Arrow down / up
    output.extend(collect(master, 0.25))
    os.write(master, b"\x03")  # Raw Ctrl+C must be handled, not SIGINT
    process.wait(timeout=8)
    output.extend(collect(master, 0.2))
    assert process.returncode != 0
    assert b"No disk changes" in output or b"no disk changed" in output
    verify_restored(slave, original)
finally:
    if process.poll() is None:
        process.kill()
    os.close(master); os.close(slave)

print("Kova TTY wizard: 80x24 preview and 40x15 Ctrl+C restoration OK")
