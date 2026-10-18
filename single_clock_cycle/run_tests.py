#!/usr/bin/env python3
"""Single-cycle CPU verification: Python 3 + Icarus Verilog, no pip dependencies."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"

def run(args):
    result = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=30)
    print(result.stdout, end="")
    return result

def compile_tb(top, source, stem):
    binary = BUILD / (stem + ".vvp")
    result = run(["iverilog", "-g2012", "-Wall", "-s", top, "-o", str(binary),
                  *map(str, sorted((ROOT / "src").glob("*.sv"))), str(ROOT / "tb" / source)])
    (BUILD / (stem + "_compile.log")).write_text(result.stdout)
    if result.returncode:
        raise RuntimeError("Compilation failed: " + top)
    return binary

def main():
    for exe in ("iverilog", "vvp"):
        if not shutil.which(exe):
            raise RuntimeError("Missing executable: " + exe)
    BUILD.mkdir(exist_ok=True)
    for top, source, stem, marker in [
        ("datapath_single_cycle_tb", "datapath_tb.sv", "demo", "PASS demo:"),
        ("single_cycle_regression_tb", "single_cycle_regression_tb.sv", "regression", "ALL PASS:"),
        ("jump_tb", "jump_tb.sv", "jump", "PASS jump unit:")
    ]:
        binary = compile_tb(top, source, stem)
        result = run(["vvp", str(binary)])
        (BUILD / (stem + ".log")).write_text(result.stdout)
        if result.returncode or marker not in result.stdout:
            raise RuntimeError("Simulation failed: " + top)
    for top, source, stem, count, diagnostic in [
        ("memory_guard_tb", "memory_guard_tb.sv", "memory_guard", 5, "Invalid data-memory address:"),
        ("fetch_guard_tb", "fetch_guard_tb.sv", "fetch_guard", 2, "Invalid instruction fetch:")
    ]:
        binary = compile_tb(top, source, stem)
        logs = []
        for case in range(count):
            result = run(["vvp", str(binary), f"+CASE={case}"])
            logs.append(result.stdout)
            if result.returncode == 0 or diagnostic not in result.stdout:
                raise RuntimeError(f"Expected diagnostic missing: {stem} case {case}")
            print(f"PASS {stem} case {case}: rejected as expected")
        (BUILD / (stem + ".log")).write_text("".join(logs))
    print("ALL SUITES PASS: demo, 35 regression cases, jump unit, 7 expected diagnostic failures")

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
