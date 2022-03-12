
set project_name   [lindex $argv 0]
set testbench_name [lindex $argv 1]
set sw             [lindex $argv 2]
set test_name      [lindex $argv 3]

set sources_file scripts/${project_name}.tcl

if {![file exists $sources_file]} {
    puts "Invalid project name!"
    puts ${project_name}
    exit
}

if {![file exists ${project_name}_proj/${project_name}_proj.xpr]} {
    source scripts/build_project.tcl
} else {
    open_project ${project_name}_proj/${project_name}_proj.xpr
}

update_compile_order -fileset sources_1

# Add simulation file
add_files -fileset sim_1 -norecurse sim/${testbench_name}.v
add_files -fileset sim_1 -norecurse sim/mem_model.v

# Add memory initialization file
if {[string match "" ${sw}]} {
  set test_name ${testbench_name}
} else {
  add_files -norecurse [glob ../software/${sw}/*.mif]
}

set_property top ${testbench_name} [get_filesets sim_1]
update_compile_order -fileset sim_1

## Run Simulation
launch_simulation -step compile
launch_simulation -step elaborate

# if "make sim tb=isa_testbench", we run the whole riscv-tests test suite
if {[string match "isa_testbench" ${testbench_name}] && [string match "all" $test_name]} {
  set tests [list ]
  # Full ISA test suit (except fence_i)
  lappend tests addi
  lappend tests add
  lappend tests andi
  lappend tests and
  lappend tests auipc
  lappend tests beq
  lappend tests bge
  lappend tests bgeu
  lappend tests blt
  lappend tests bltu
  lappend tests bne
  lappend tests jal
  lappend tests jalr
  lappend tests lb
  lappend tests lbu
  lappend tests lh
  lappend tests lhu
  lappend tests lui
  lappend tests lw
  lappend tests ori
  lappend tests or
  lappend tests sb
  lappend tests sh
  lappend tests simple
  lappend tests slli
  lappend tests sll
  lappend tests slti
  lappend tests sltiu
  lappend tests slt
  lappend tests sltu
  lappend tests srai
  lappend tests sra
  lappend tests srli
  lappend tests srl
  lappend tests sub
  lappend tests sw
  lappend tests xori
  lappend tests xor
} else {
  set tests [list ${test_name} ]
}

set num_tests [llength $tests]

set current_dir [pwd]
cd ${project_name}_proj/${project_name}_proj.sim/sim_1/behav/xsim

for {set i 0} {$i < $num_tests} {incr i} {
  xsim ${testbench_name}_behav -testplusarg MIF_FILE=[lindex $tests $i].mif
  run all
}

exit
