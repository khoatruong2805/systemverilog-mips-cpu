# Five-Stage Pipelined MIPS CPU

A 32-bit educational MIPS-subset CPU organized as **IF → ID → EX → MEM → WB**, with IF/ID, ID/EX, EX/MEM, and MEM/WB pipeline registers.

Branches resolve in MEM, jumps resolve in ID, and **there are no delay slots**. An older taken branch takes priority over a younger jump or load-use stall.

## Run the tests

From the repository root, with Python 3 and Icarus Verilog installed:

```bash
python3 pipelined/run_tests.py
```

The runner sets the simulation working directory automatically and writes executables and logs to `pipelined/build/`. Compilation failures, unexpected results, and timeouts return a nonzero exit status.

To generate and view the demo waveform after running the tests:

```bash
cd pipelined
vvp build/demo.vvp +VCD
gtkwave cpu_pipeline_sim.vcd
```

GTKWave is optional. To compile only the demo manually, run from `pipelined/`:

```bash
mkdir -p build
iverilog -g2012 -Wall -s five_stage_pipelined_tb -o build/demo.vvp src/*.sv tb/pipeline_tb.sv
vvp build/demo.vvp
```

Compile separately from `single_clock_cycle/src/` because module names overlap.

## Datapath and hazard handling

The top-level module is `five_stage_pipelined` in `src/pipeline.sv`. It supports `add`, `sub`, `and`, `or`, `slt`, `addi`, `andi`, `ori`, `slti`, `lw`, `sw`, `beq`, `j`, and `nop`.

- **EX/MEM forwarding:** supplies the most recent ALU result to either EX source operand and takes priority over MEM/WB forwarding.
- **MEM/WB forwarding:** uses the final writeback value after the MemToReg mux, including loaded data.
- **WB-to-ID bypass:** ensures a register read sees a value being written in the same cycle.
- **Store data:** uses the forwarded B operand before the ALUSrc immediate mux.
- **Load-use detection:** checks the instruction's actual source registers, ignores writes to `$0`, holds PC and IF/ID, and inserts an ID/EX bubble. The load continues toward MEM. An immediate load-to-store-data dependency also incurs one stall.
- **Branch target:** calculated in EX as `PC + 4 + (sign_extended_offset << 2)`; Branch AND Zero is evaluated from EX/MEM.
- **Jump target:** calculated in ID using the upper four bits of that instruction's PC+4 and its shifted index.

| Event | PC | IF/ID | ID/EX | EX/MEM | MEM/WB |
| --- | --- | --- | --- | --- | --- |
| Normal execution | Advance | Capture | Capture | Capture | Capture |
| Load-use hazard | Hold | Hold | Bubble | Capture | Capture |
| Taken branch in MEM | Branch target | Flush | Flush | Flush | Capture |
| Jump in ID | Jump target | Flush | Flush | Capture | Capture |
| Reset | Zero | Clear | Clear | Clear | Clear |

A branch does not cancel an older instruction already in WB. A jump does not cancel older instructions in EX or MEM. This design does not implement branch prediction.

## Program, memory, and reset

- Separate instruction ROM and data RAM, each 64 words / 256 bytes.
- Byte addresses and word-aligned accesses; combinational instruction and data-memory reads, rising-edge writes.
- `PROGRAM_FILE` defaults to `program.txt`. ROM is initialized to NOPs before loading the hexadecimal program. Set `PROGRAM_FILE=""` for testbench-supplied instructions.
- The demo initializes registers itself and exercises arithmetic forwarding, a store, a load-use dependency, and a terminal jump loop.
- RAM has no default initialization; initialize it in the testbench or store before loading.
- Synchronous active-high reset clears PC, pipeline registers, and the register file, suppresses architectural writes, and preserves RAM contents.
- `$0` always reads as zero. Logical immediates are zero-extended; other supported immediate operations use sign extension. SLT/SLTI use signed comparisons.
- Invalid fetch addresses return X rather than aliasing another ROM word. Invalid RAM addresses trigger simulation-only diagnostics; these are not hardware exceptions.

## Verification coverage

| Testbench | Purpose |
| --- | --- |
| `tb/pipeline_tb.sv` | Demo checks: r3=15, r4=15, r5=20, and memory[0]=15 |
| `tb/pipeline_regression_tb.sv` | Sequential reference model for ordered architectural writes, final state comparison, and pipeline control monitors |
| `tb/memory_guard_tb.sv` | Five expected failures for invalid data-memory accesses |

The regression has **41 cases**: 19 directed programs, 20 deterministic random programs, a mid-flight reset, and a restart after reset. It checks architectural write order, destination, and data, then compares registers and RAM. Cycle-level monitors verify held PC/IF/ID, inserted bubbles, flushed controls, and redirect priority.

Directed coverage includes both forwarding operands, WB-to-ID bypass, newest-producer priority, load-to-ALU/store/address dependencies, negative offsets, false-stall avoidance, `$0`, taken/not-taken branches, load-to-branch dependencies, branch/stall and branch/jump collisions, jumps, logical-immediate extension, signed comparisons, R-type operations, backward branches, NOP/unsupported instructions, and the final RAM word.

Verified result: **41 cases and 14,357 checks passed**, along with the demo and five expected-failure cases. The memory guard tests intentionally print `$fatal` messages; the runner verifies both the expected diagnostic and a failing exit status.

## Limitations

This is a MIPS teaching subset, not the complete ISA. It has no exceptions, overflow traps, interrupts, caches, byte/halfword accesses, `jal`, `jr`, multiply/divide, or HI/LO registers. ADD/SUB/ADDI wrap modulo 2^32; unsupported opcodes/functions have no architectural side effects.

Tests are not an exhaustive proof or post-synthesis timing verification. A synchronous FPGA block RAM implementation requires changes to the current memory timing and hazard handling.

See the [repository overview](../README.md) for the single-cycle comparison and license link.
