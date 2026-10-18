# Single-Cycle MIPS CPU

A 32-bit educational MIPS-subset processor. Each instruction completes in one clock cycle: instruction fetch, register reads, ALU operation, optional data-memory read, and next-PC selection are combinational; the PC, register file, and data-memory writes update on the rising edge.

There are no pipeline registers, forwarding paths, stalls, or delay slots.

## Run the tests

From the repository root, with Python 3 and Icarus Verilog installed:

```bash
python3 single_clock_cycle/run_tests.py
```

The runner works from any directory when invoked with the correct script path. It sets the simulation working directory automatically. Results and executables are written to `single_clock_cycle/build/`; failures or timeouts produce a nonzero exit status.

To generate and view the demo waveform after running the tests:

```bash
cd single_clock_cycle
vvp build/demo.vvp +VCD
gtkwave waveform.vcd
```

GTKWave is optional. To compile only the demo manually, run from `single_clock_cycle/`:

```bash
mkdir -p build
iverilog -g2012 -Wall -s datapath_single_cycle_tb -o build/demo.vvp src/*.sv tb/datapath_tb.sv
vvp build/demo.vvp
```

Do not include the sibling `pipelined/src/` files in the same compilation.

## Implementation

- Top-level module: `datapath_single_cycle` in `src/datapath.sv`.
- Supported instructions: `add`, `sub`, `and`, `or`, `slt`, `addi`, `andi`, `ori`, `slti`, `lw`, `sw`, `beq`, `j`, and `nop`.
- Logical immediates (`andi`, `ori`) are zero-extended; other supported immediate operations use sign extension. Comparisons are signed for `slt` and `slti`.
- `beq` selects `PC + 4 + (sign_extended_offset << 2)` when equal. Jump targets concatenate the upper four bits of `PC + 4`, the 26-bit instruction index, and two zero bits.
- Synchronous active-high reset clears PC and all 32 registers, suppresses register/RAM writes and RAM reads, and preserves RAM contents. `$0` always reads as zero.
- The control unit receives reset explicitly. Unsupported R-type functions and opcodes have no side effects.

| ALUOp | Operation |
| --- | --- |
| `000` | Addition: ADDI, LW, SW |
| `001` | Subtraction: BEQ |
| `010` | R-type function decode |
| `011` | ANDI |
| `100` | ORI |
| `101` | SLTI |

## Program and memory setup

Instruction ROM and data RAM each contain 64 words. Addresses are byte-based and must be word-aligned. Reads are combinational and writes are clocked.

The top-level `PROGRAM_FILE` parameter defaults to `tb/machine_code.txt`. ROM is filled with NOPs before `$readmemh` loads that hexadecimal file. Set `PROGRAM_FILE=""` when a testbench supplies ROM contents directly. The original ten-instruction demo is preserved, with NOP padding to fill the remaining ROM words.

RAM is not initialized by reset. Programs must write data before reading it, or testbenches must initialize the required words. Simulation checks reject invalid data-memory addresses and invalid instruction fetches. These diagnostics are excluded from synthesis and do not implement hardware exceptions.

## Verification coverage

| Testbench | Purpose |
| --- | --- |
| `tb/datapath_tb.sv` | Original demo: 10 checks for ADDI, SUB, SLT, SW, LW, taken branch, jump, and skipped writes |
| `tb/single_cycle_regression_tb.sv` | Independent sequential reference model; checks PC, control signals, all 32 registers and all 64 RAM words every cycle |
| `tb/jump_tb.sv` | Three unit checks for PC+4 upper bits, index shifting, and disabled jump selection |
| `tb/memory_guard_tb.sv` | Five expected failures for invalid load/store addresses |
| `tb/fetch_guard_tb.sv` | Two expected failures for an out-of-range fetch and an unknown instruction |

The regression has **35 cases**: 12 directed programs, 20 seeded random programs, a reset during a pending register write, a reset during a pending store, and a restart after reset.

Directed cases cover every supported opcode, back-to-back dependencies, immediate bit 15 set, negative values, signed boundaries, arithmetic wraparound, memory offsets, the first/last RAM words, `$0`, taken/not-taken and backward branches, load-to-branch dependencies, jumps without delay slots, NOPs, and unsupported instructions.

Verified result: **197,694 checks across 1,957 instruction cycles passed**. The demo, jump unit, and seven expected-failure cases also passed. `$fatal` messages from the guard testbenches are intentional; the runner verifies their diagnostic and exit status.

## Limitations

This is a teaching subset, not a full MIPS implementation. It has no overflow traps, exceptions, interrupts, caches, HI/LO, `jal`, `jr`, or byte/halfword accesses. ADD, SUB, and ADDI wrap modulo 2^32. Unsupported instructions are inert rather than trapped.

The tests are not a formal proof or post-synthesis timing analysis. Synchronous FPGA block RAM would require changes to the current single-cycle memory timing.

See the [repository overview](../README.md) for the architecture comparison and license link.
