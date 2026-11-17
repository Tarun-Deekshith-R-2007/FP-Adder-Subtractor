# Local validation

Validated on 2026-11-17.

- Verilator simulation: **PASS**, 106,448 bit-exact arithmetic vectors.
- Protocol tests: **PASS**, synchronous reset, reset priority, recovery,
  input destruction after capture, idle valid deassertion, result hold,
  and consecutive valid requests.
- Yosys **0.33** (YoWASP package 0.33.0.0.post574): synthesis and
  `check -assert` **PASS**; latch absence assertion **PASS**.

Commands in this environment:

```sh
make test-verilator VERILATOR=verilator-cli
make synth YOSYS=yowasp-yosys
```

The simulation executable reports Verilator 5.49. The Python distribution is
named `verilator` version 5.48.0. No local Icarus Verilog or Vivado run was
performed. The GitHub Actions workflow uses Icarus Verilog when published.

The course's RISC-n-Roll-CI has **not** run for this implementation yet.
Local success does not claim an official grading result or FPGA timing closure.
