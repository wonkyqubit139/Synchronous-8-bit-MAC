# gtkwave script: add the tb signals, buses in decimal, zoom to T0..T1 (in ps)

set sigs {mac8_tb.clk mac8_tb.reset mac8_tb.enable mac8_tb.A[7:0] mac8_tb.B[7:0] mac8_tb.Y[19:0] mac8_tb.expected[19:0]}
gtkwave::addSignalsFromList $sigs
gtkwave::highlightSignalsFromList {mac8_tb.A[7:0] mac8_tb.B[7:0] mac8_tb.Y[19:0] mac8_tb.expected[19:0]}
gtkwave::/Edit/Data_Format/Decimal
gtkwave::/Edit/UnHighlight_All
gtkwave::setZoomRangeTimes $::env(T0) $::env(T1)
