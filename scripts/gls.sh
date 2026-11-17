#!/bin/bash
# gate level sim of a netlist with the testbench, also dumps a vcd for power

NETLIST=${NETLIST:-$1/mac8_netlist.v}
LIB=${LIB:-$STA_LIB}
d=$1; s=$2
# verilog models for the cells in the netlist, made from the liberty file
python3 liberty_filter.py $LIB $d/cells_used.lib --keep $NETLIST > /dev/null
yosys -q -p "read_liberty $d/cells_used.lib; write_verilog -noattr $d/cell_models.v" > $d/gls_yosys.log 2>&1
cat ../tb/sky130_icg_model.v >> $d/cell_models.v
# tap/fill/decap cells have no logic, just add empty modules for them
for c in $(grep -oE '^\s*sky130_(fd|ef)_sc_hd__\w+' $NETLIST | tr -d ' ' | sort -u); do
    grep -qE "^module (\\\\)?$c\b" $d/cell_models.v || echo "module $c(); endmodule" >> $d/cell_models.v
done
TB=$(realpath ../tb/mac8_tb.v); NET=$(realpath $NETLIST)
cd $d && iverilog -g2005 -DGLS -P mac8_tb.STAGES=$s -P mac8_tb.EN_PCT=${EN_PCT:-75} -o gls.vvp $TB $NET cell_models.v 2>&1 | head -5 && vvp -n gls.vvp > gls.log; grep RESULT gls.log
