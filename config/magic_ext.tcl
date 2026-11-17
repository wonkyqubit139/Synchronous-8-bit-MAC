# extract a spice netlist from the gds for LVS

gds read $env(GDS)
load mac8
select top cell
cd $env(OUT)
extract no all
extract do local
extract unique
extract all
ext2spice lvs
ext2spice -o $env(OUT)/mac8_extracted.spice
quit -noprompt
