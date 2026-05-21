#!/usr/bin/env python3
"""Capture the Roku BrightScript debug console (raw TCP, port 8085) to a file for
a fixed window, then exit. Decouples capture from parsing so roku-listener can
replay deterministically with no risk of hanging on a crash (no run-end).

Usage (run the capture in the background, deploy, then replay):

    python3 scripts/capture-console.py 192.168.1.240 65 out/console.log 8085 &
    npm run roku:deploy
    wait
    # trim to the last complete run, then:  bun run --cwd roku-listener replay out/console.log

The roku-listener `live` mode (`bun run --cwd roku-listener listen`) is the simpler
path when the harness is known to emit a run-end; this script is the hang-safe
alternative (hard time bound) and leaves the raw log for debugging.
"""
import socket, sys, time

host = sys.argv[1]
dur = float(sys.argv[2])
out = sys.argv[3]
port = int(sys.argv[4]) if len(sys.argv) > 4 else 8085

try:
    s = socket.create_connection((host, port), timeout=10)
except Exception as e:
    print(f"CAP: connect failed: {e}", file=sys.stderr)
    sys.exit(3)
s.settimeout(1.0)
end = time.time() + dur
nbytes = 0
with open(out, "wb") as f:
    print(f"CAP: connected {host}:{port}, capturing {dur:.0f}s -> {out}", file=sys.stderr)
    while time.time() < end:
        try:
            data = s.recv(8192)
            if not data:
                print("CAP: socket closed by device", file=sys.stderr)
                break
            f.write(data)
            f.flush()
            nbytes += len(data)
        except socket.timeout:
            continue
        except Exception as e:
            print(f"CAP: recv error: {e}", file=sys.stderr)
            break
s.close()
print(f"CAP: done, {nbytes} bytes", file=sys.stderr)
