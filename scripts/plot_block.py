#!/usr/bin/env python3
# draws the block diagram for the report (fig 1)

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
fig, ax = plt.subplots(figsize=(11, 4.6), dpi=170); ax.axis("off"); ax.set_xlim(0, 110); ax.set_ylim(0, 46)
# helpers for boxes, registers and arrows
def box(x, y, w, h, t, fc="#eaf2fb", ec="#1f4e79", fs=7.5):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.3", fc=fc, ec=ec, lw=1.1))
    ax.text(x + w / 2, y + h / 2, t, ha="center", va="center", fontsize=fs)
def reg(x, y, h, t):
    ax.add_patch(plt.Rectangle((x, y), 2.6, h, fc="#fde9d9", ec="#c0504d", lw=1.2))
    ax.text(x + 1.3, y + h + 1.2, t, ha="center", fontsize=6.8, color="#c0504d")
    ax.plot([x, x + 1.3, x + 2.6], [y + 0.3, y + 1.6, y + 0.3], color="#c0504d", lw=0.8)
def arr(x0, y0, x1, y1, t=None, c="#333"):
    ax.annotate("", (x1, y1), (x0, y0), arrowprops=dict(arrowstyle="->", lw=1.0, color=c))
    if t: ax.text((x0 + x1) / 2, (y0 + y1) / 2 + 0.9, t, ha="center", fontsize=6.3)
ax.text(2, 30.5, "A[7:0]", fontsize=8); ax.text(2, 23.5, "B[7:0]", fontsize=8)
box(9, 21, 13, 13, "Partial products\n8 rows\n(A AND B[j]) << j\n64 AND2")
arr(6.5, 31, 9, 29); arr(6.5, 24, 9, 25)
box(26, 21, 17, 13, "Carry-save tree\n4 levels of 3:2\ncompressors\n8 -> 6 -> 4 -> 3 -> 2\n(no carry propagation)")
arr(22.6, 27.5, 26, 27.5, "8 x 16b")
reg(47.5, 21, 13, "S,C reg\n(2 x 16b)"); arr(43.6, 27.5, 47.5, 27.5, "S, C")
box(55, 21, 12, 13, "3:2 compressor\nY + S + C\n(20 bit)")
arr(50.1, 27.5, 55, 27.5)
box(71, 21, 14, 13, "20-bit\nKogge-Stone\nprefix adder\n(log2 depth)")
arr(67.6, 27.5, 71, 27.5, "s, c")
reg(89, 21, 13, "Y reg\n(20b)"); arr(85.6, 27.5, 89, 27.5, "Y_next")
arr(91.6, 27.5, 106, 27.5); ax.text(103, 29, "Y[19:0]", fontsize=8)
ax.plot([95, 95, 61, 61], [27.5, 38.5, 38.5, 34.4], color="#1f4e79", lw=1.0)
ax.annotate("", (61, 34.4), (61, 36), arrowprops=dict(arrowstyle="->", lw=1.0, color="#1f4e79"))
ax.text(78, 39.5, "accumulator feedback (critical loop: Y -> 3:2 -> KS -> Y)", fontsize=6.8, ha="center", color="#1f4e79")
# control and clock gating
box(9, 4, 14, 8, "enable, reset\nv1 valid FF", fc="#f2f2f2", ec="#555")
box(40, 4, 14, 8, "ICG #1\ndlclkp: en = enable\n-> S,C reg clock", fc="#e8f5e9", ec="#2e7d32", fs=6.8)
box(80, 4, 15, 8, "ICG #2\ndlclkp: en = v1 | reset\n-> Y reg clock", fc="#e8f5e9", ec="#2e7d32", fs=6.8)
arr(23.6, 8, 40, 8); arr(54.6, 8, 80, 8, "v1 (valid, 1 cycle later)")
arr(47, 12.4, 48.8, 21, c="#2e7d32"); arr(88, 12.4, 90.3, 21, c="#2e7d32")
ax.axvline(49, ymin=0.02, ymax=0.97, color="#c0504d", ls=":", lw=0.9); ax.axvline(90.3, ymin=0.02, ymax=0.97, color="#c0504d", ls=":", lw=0.9)
ax.text(28, 44, "STAGE 1: multiply (carry-save form)", fontsize=8.5, ha="center", weight="bold")
ax.text(70, 44, "STAGE 2: merge + accumulate", fontsize=8.5, ha="center", weight="bold")
fig.tight_layout(); fig.savefig("results/screenshots/00_block_diagram.png"); print("ok")
