#!/usr/bin/env python3
"""Writes the Word Glow icon SVGs: the app icon and Android's adaptive
foreground and background. Four lit tiles spell WO / RD (read across, like a
page), glowing on the night sky.

  python3 tools/make_icon.py && godot --headless --path . -s res://tools/render_icons.gd
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFS = """<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2B2F7A"/><stop offset="1" stop-color="#120F35"/></linearGradient>
<radialGradient id="halo" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#FFB547" stop-opacity=".6"/><stop offset=".55" stop-color="#FF7A45" stop-opacity=".16"/><stop offset="1" stop-color="#FF7A45" stop-opacity="0"/></radialGradient>
<linearGradient id="lit" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD36B"/><stop offset="1" stop-color="#FF8A3D"/></linearGradient>
<linearGradient id="shine" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".45"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>"""
SKY = """<rect width="1024" height="1024" fill="url(#bg)"/>
<circle cx="512" cy="512" r="470" fill="url(#halo)"/>
<path d="M850 168 l12 30 30 12 -30 12 -12 30 -12 -30 -30 -12 30 -12z" fill="#FFE3A6" opacity=".9"/>
<path d="M170 820 l9 22 22 9 -22 9 -9 22 -9 -22 -22 -9 22 -9z" fill="#FFE3A6" opacity=".7"/>
<path d="M160 190 l7 17 17 7 -17 7 -7 17 -7 -17 -17 -7 17 -7z" fill="#FFE3A6" opacity=".55"/>"""

T, G = 260, 36                      # tile size and gap
X0 = Y0 = (1024 - (2 * T + G)) // 2
CELLS = {"W": (0, 0), "O": (1, 0), "R": (0, 1), "D": (1, 1)}   # (column, row)
LETTERS = {
    "W": '<path d="M70 82 L101 184 L130 116 L159 184 L190 82" fill="none"/>',
    "O": '<circle cx="130" cy="132" r="56" fill="none"/>',
    "R": '<path d="M94 188 V78 H140 C182 78 182 140 140 140 H94 M134 140 L180 188" fill="none"/>',
    "D": '<path d="M94 78 V188 H122 C196 188 196 78 122 78 Z" fill="none"/>',
}


def art() -> str:
    out = []
    for k in "WORD":
        c, r = CELLS[k]
        x, y = X0 + c * (T + G), Y0 + r * (T + G)
        out.append(f'<rect x="{x}" y="{y + 16}" width="{T}" height="{T}" rx="66" fill="#B4521F" opacity=".75"/>')
        out.append(f'<rect x="{x}" y="{y}" width="{T}" height="{T}" rx="66" fill="url(#lit)"/>')
        out.append(f'<rect x="{x + 18}" y="{y + 12}" width="{T - 36}" height="{T // 2 - 20}" rx="50" fill="url(#shine)"/>')
        out.append(f'<g transform="translate({x} {y})" stroke="#231D52" stroke-width="40" stroke-linecap="round" stroke-linejoin="round">{LETTERS[k]}</g>')
    return "\n".join(out)


def svg(body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n<defs>\n{DEFS}\n<clipPath id="c"><rect width="1024" height="1024" rx="228"/></clipPath>\n</defs>\n{body}\n</svg>\n'


(ROOT / "assets/icon.svg").write_text(svg(f'<g clip-path="url(#c)">\n{SKY}\n{art()}\n</g>'))
# Adaptive icon: launchers mask to a circle about 61% of the canvas wide, so the
# tiles shrink until their corners fit inside it.
(ROOT / "assets/android/icon_foreground.svg").write_text(svg(f'<g transform="translate(512 512) scale(.78) translate(-512 -512)">\n{art()}\n</g>'))
(ROOT / "assets/android/icon_background.svg").write_text(svg(SKY))
print("wrote assets/icon.svg and assets/android/icon_{foreground,background}.svg")
