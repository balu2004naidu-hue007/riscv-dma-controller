#!/usr/bin/env python3
"""Convert a flat binary image to 32-bit little-endian $readmemh words."""
import argparse
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("input_bin")
p.add_argument("output_mem")
p.add_argument("--words", type=int, default=8192)
a = p.parse_args()
data = Path(a.input_bin).read_bytes()
capacity = a.words * 4
if len(data) > capacity:
    raise SystemExit(f"image is {len(data)} bytes; memory capacity is {capacity}")
data = data + bytes(capacity - len(data))
with Path(a.output_mem).open("w", encoding="ascii") as f:
    for i in range(0, len(data), 4):
        f.write(f"{int.from_bytes(data[i:i+4], 'little'):08x}\n")
print(f"Wrote {a.words} words ({capacity} bytes) to {a.output_mem}")
