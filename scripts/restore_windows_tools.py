"""Restore Velopack with visible progress and a bounded download time."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

WINDOWS = Path(__file__).resolve().parent.parent / "windows"


def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()


def main():
    try:
        ready = subprocess.run(
            ["dotnet", "tool", "run", "vpk", "--", "--skip-updates", "--help"],
            cwd=WINDOWS, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        if ready.returncode == 0:
            print("Velopack is already installed.", flush=True)
            return 0
    except subprocess.TimeoutExpired:
        pass
    print("Downloading the pinned Velopack installer tools from NuGet…", flush=True)
    print("This is separate from compiling SmartNotch. The first download may take several minutes.", flush=True)
    process = subprocess.Popen(
        ["dotnet", "tool", "restore", "--disable-parallel", "--verbosity", "normal"],
        cwd=WINDOWS, start_new_session=True)
    started = time.monotonic()
    try:
        while True:
            try:
                code = process.wait(timeout=15)
                if code:
                    print("Velopack download failed. Check the NuGet error above, then rerun the packaging command.", file=sys.stderr)
                return code
            except subprocess.TimeoutExpired:
                elapsed = int(time.monotonic() - started)
                if elapsed >= 300:
                    stop(process)
                    print("Velopack download timed out after 5 minutes. Check access to https://api.nuget.org/v3/index.json and rerun.", file=sys.stderr)
                    return 1
                print(f"Still downloading/restoring Velopack… {elapsed}s elapsed (5-minute limit).", flush=True)
    except KeyboardInterrupt:
        stop(process)
        print("\nVelopack download cancelled. No installer was created.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
