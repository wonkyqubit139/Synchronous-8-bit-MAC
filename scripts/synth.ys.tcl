# yosys synthesis of mac8 for sky130_fd_sc_hd

yosys -import
set stages $::env(STAGES)
set fast   $::env(FAST)
set cg     $::env(CG)
set fulllib $::env(FULL_LIB)
set lib    $::env(LIB)
set out    $::env(OUT)
set clk_ps $::env(CLK_PS)

# full lib as a blackbox lib so the ICG cell instance is known
read_liberty -lib $fulllib
read_verilog -defer -DSKY130_CELLS ../rtl/mac8.v
chparam -set STAGES $stages -set FAST_ARITH $fast -set CLK_GATE $cg mac8
hierarchy -check -top mac8
# KS_PRESERVE=1 keeps the kogge-stone adder as its own module so abc can't turn it back into ripple carry
# (tried it, cost ~21% area, so the final design uses the delay abc script instead)
set ks_preserve [expr {[info exists ::env(KS_PRESERVE)] ? $::env(KS_PRESERVE) : 0}]
if {$ks_preserve} { setattr -mod -set keep_hierarchy 1 {$paramod*ks_adder*} }
synth -top mac8 -flatten
# map flops, then abc for the logic
dfflibmap -liberty $lib
opt -purge
if {$ks_preserve} {
    set fh [open $out/abc_ks.script w]; puts $fh "strash; map -D $clk_ps; topo; stime -p"; close $fh
    abc -D $clk_ps -liberty $lib -script $out/abc_ks.script {$paramod*ks_adder*}
    abc -D $clk_ps -liberty $lib mac8
    setattr -mod -unset keep_hierarchy {$paramod*ks_adder*}
    flatten
    opt_clean -purge
} elseif {[info exists ::env(ABC_SCRIPT)] && $::env(ABC_SCRIPT) ne "default"} {
    set fh [open $out/abc.script w]; puts $fh $::env(ABC_SCRIPT); close $fh
    abc -D $clk_ps -liberty $lib -script $out/abc.script
} else {
    abc -D $clk_ps -liberty $lib
}
opt_clean -purge
# tie cells for constant 0/1
hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO
setundef -zero
opt_clean -purge
tee -o $out/synth_stat.rpt stat -liberty $lib
write_verilog -noattr -noexpr -nohex -nodec $out/mac8_netlist.v
