PYTHON ?= python3
YOSYS ?= yosys
VERILATOR ?= verilator
COUNT ?= 100000
SEED ?= 20261117

.PHONY: test test-verilator vectors synth clean
vectors:
	mkdir -p build
	$(PYTHON) tests/generate_vectors.py --count $(COUNT) --seed $(SEED)

test: vectors
	iverilog -g2012 -Wall -s tb_fp_addsub -o build/tb FP_AddSub/rtl.sv tests/tb_fp_addsub.sv
	vvp build/tb

test-verilator: vectors
	$(VERILATOR) --binary --timing --top-module tb_fp_addsub --Mdir build/obj FP_AddSub/rtl.sv tests/tb_fp_addsub.sv
	build/obj/Vtb_fp_addsub

synth:
	mkdir -p build
	$(YOSYS) -Q -T -l build/synthesis.log -p 'read_verilog -sv FP_AddSub/rtl.sv; hierarchy -check -top fp_addsub; synth -top fp_addsub; check -assert; select -assert-none t:$$dlatch t:$$adlatch t:$$_DLATCH_*; stat'

clean:
	rm -rf build
