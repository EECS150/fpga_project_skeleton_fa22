# Add source files

add_files -norecurse [glob src/riscv_core/*.v]
add_files -norecurse [glob src/riscv_core/*.vh]
add_files -norecurse [glob src/io_circuits/*.v]
add_files -norecurse [glob src/accelerator/*.v]
add_files -norecurse [glob src/accelerator/*.vh]
add_files -norecurse src/EECS151.v
add_files -norecurse src/clk_wiz.v
add_files -norecurse src/z1top_axi.v
# Add memory initialization file
add_files -norecurse ../software/bios151v3/bios151v3.mif

check_syntax

# This project needs Block Design
source scripts/z1top_axi_bd.tcl
