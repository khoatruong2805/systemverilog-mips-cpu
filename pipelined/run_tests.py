#!/usr/bin/env python3
"""Run with Python 3 and Icarus Verilog installed; no Python packages required."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"

def invoke(args):
    result = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=30)
    print(result.stdout, end="")
    return result

def compile_tb(top, source, filename):
    out = BUILD / filename
    result = invoke(["iverilog", "-g2012", "-Wall", "-s", top, "-o", str(out),
                     *map(str, sorted((ROOT / "src").glob("*.sv"))), str(ROOT / "tb" / source)])
    if result.returncode:
        raise RuntimeError("Compilation failed: " + top)
    return out

def main():
    for executable in ("iverilog", "vvp"):
        if not shutil.which(executable):
            raise RuntimeError("Missing executable: " + executable)
    BUILD.mkdir(exist_ok=True)
    jobs = [("five_stage_pipelined_tb", "pipeline_tb.sv", "demo.vvp", "PASS demo:"),
            ("pipeline_regression_tb", "pipeline_regression_tb.sv", "regression.vvp", "ALL PASS:")]
    for top, source, filename, marker in jobs:
        image = compile_tb(top, source, filename)
        result = invoke(["vvp", str(image)])
        (BUILD / (image.stem + ".log")).write_text(result.stdout)
        if result.returncode or marker not in result.stdout:
            raise RuntimeError("Simulation failed: " + top)
    image = compile_tb("memory_guard_tb", "memory_guard_tb.sv", "memory_guard.vvp")
    guard_log = []
    for case in range(5):
        result = invoke(["vvp", str(image), f"+CASE={case}"])
        guard_log.append(result.stdout)
        if result.returncode == 0 or "Invalid data-memory address:" not in result.stdout:
            raise RuntimeError(f"Memory guard case {case} did not fail as expected")
        print(f"PASS memory guard {case}: invalid access rejected as expected")
    (BUILD / "memory_guard.log").write_text("".join(guard_log))
    print("ALL SUITES PASS: demo, 41 regression cases, 5 expected memory-address failures")

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
