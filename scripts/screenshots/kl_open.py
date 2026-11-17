# klayout startup macro: open the gds with full hierarchy and sky130 colours, hide the text/label layers
# gds and lyp are passed with -rd

import pya
app = pya.Application.instance()
app.set_config("full-hierarchy-new-cell", "true")
mw = app.main_window()
mw.load_layout(gds, 1)
v = mw.current_view()
v.load_layer_props(lyp)
v.max_hier()
v.set_config("text-visible", "false")
it = v.begin_layers()
while not it.at_end():
    lp = it.current().dup(); n = (lp.source_name or lp.name or "").lower()
    if any(k in n for k in ("label", "boundary", "areaid", ".pin", "text")): lp.visible = False
    v.set_layer_properties(it, lp); it.next()
v.zoom_fit()
