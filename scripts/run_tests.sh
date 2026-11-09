#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m unittest discover -s tests -v
if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
  make test-rtl test-arbiter
else
  echo "SKIP: RTL simulation requires Icarus Verilog (iverilog + vvp)."
  echo "The Python reference-model tests above are not a substitute for RTL simulation."
fi
