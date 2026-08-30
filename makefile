# Makefile for AXI4 Interconnect

# Compiler
CC = iverilog
# Simulator
SIM = vvp

# Flags: Enable SystemVerilog (-g2012)
CFLAGS = -g2012 -I rtl/

# Source files (Ensure axi_pkg is loaded first)
SRC = rtl/axi_pkg.sv \
      rtl/rr_arbiter.sv \
      rtl/axi_addr_decode.sv \
      rtl/axi_slave_port.sv \
      rtl/axi_interconnect_top.sv \
      tb/axi_master_vip.sv \
      tb/axi_slave_bram.sv \
      tb/tb_top.sv

# Output executable
OUT = sim.out

all: compile run

compile:
	@echo "Compiling RTL and Testbench..."
	$(CC) $(CFLAGS) -o $(OUT) $(SRC)

run: compile
	@echo "Running Simulation..."
	$(SIM) $(OUT)

clean:
	rm -f $(OUT) *.vcd
	