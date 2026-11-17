# Implementation and verification

The original assignment specification remains in `FP_AddSub/README.md`.
The synthesizable implementation is `FP_AddSub/rtl.sv`; no helper modules,
vendor IP, real arithmetic, initial register values, or gated clocks are used.

## Datapath

1. Flip B's sign when `sub=1`, then handle NaNs and infinities.
2. Decode each finite significand. Subnormals have no hidden one and use
   effective biased exponent 1 for alignment.
3. Order by magnitude and right-shift the lesser significand. Preserve all
   discarded nonzero bits in a sticky bit.
4. Add equal-sign magnitudes or subtract opposite-sign magnitudes.
5. Normalize a carry right, or a cancellation result left, stopping at
   effective exponent 1 so subnormal results remain representable.
6. Round using guard/round/sticky and the retained least-significant bit:
   increment when `guard && (round || sticky || retained_lsb)`.
7. Pack a normal, subnormal, signed zero, or signed infinity.

NaNs are always canonical `7fc00000`. Exact cancellation produces positive
zero; two negative-zero addends produce negative zero after B's sign flip.

## Clock behavior

At each rising edge, synchronous active-high reset clears result and out_valid.
Otherwise out_valid receives in_valid and, when valid, result captures the
combinational answer. The answer is valid immediately after that edge.
Inputs can then change without changing the registered answer. On an idle
edge out_valid clears and result holds its previous value. The design also
accepts consecutive valid edges, although the course harness sends one request
at a time. Latency is within the required 64-cycle budget.

This is a combinational arithmetic datapath with a registered output, not a
timing-optimized pipeline. No FPGA device or frequency was specified; timing
closure and resource utilization require synthesis for the actual target.

## Reproduce tests

Install Python 3, GNU Make, Icarus Verilog and Yosys, then run:

```sh
make test
make synth
```

Alternatively use `make test-verilator` with Verilator, a C++ compiler and Make.
Set `COUNT=1000000 SEED=123` for a larger independently seeded run.
`vvp build/tb +vcd` creates an optional waveform after `make test`.

The oracle uses arbitrary-precision integers in units of 2^-149. It computes
an exact signed sum and rounds once, independently of the RTL's alignment and
GRS implementation. The default suite includes 4,608 edge cross-product cases,
1,840 ties-to-even cases, and 100,000 seeded random/constrained-random cases.
Constraints target cancellation, subnormals and equal exponents in addition
to unconstrained random bit patterns. The testbench also checks reset priority,
recovery, idle pulses, output stability after input changes and consecutive
valid transactions. These local tests are additional evidence; only the
course's RISC-n-Roll-CI can provide the official assignment result.

## Vivado simulation

Create an RTL project and add `FP_AddSub/rtl.sv` as a SystemVerilog design source.
Set `fp_addsub` as the design top. Add `tests/tb_fp_addsub.sv` as a simulation
source and set `tb_fp_addsub` as the simulation top. Generate vectors using
`python tests/generate_vectors.py`. The testbench opens `build/vectors.txt`
relative to the simulator's working directory; copy the generated file into
that directory's `build` subdirectory (or change the testbench path to an
absolute path on your machine). Run behavioral simulation until `$finish`.

## Submission checklist

- Create a **public repository from the allocated template**, not a fork:
  https://github.com/pranav0x2212/RISC-V-FP-AddSub
- Commit this implementation to its default branch, preserving the template.
- Keep `stage: fp_addsub` and source path `FP_AddSub/rtl.sv` in `rnr-stage.yaml`.
- Install https://github.com/apps/risc-n-roll-ci/installations/new for that repo.
- Add the two actual teammates as collaborators; their usernames are needed.
- Wait for the official check on the newest default-branch commit. It may take
  several hours. The supplementary Actions workflow is a separate check.
- Submit the repository URL through the course form. No form URL was supplied.
