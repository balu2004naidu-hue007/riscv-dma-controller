#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -d third_party/picorv32/.git ]; then
  echo "PicoRV32 source already present: third_party/picorv32"
else
  git clone https://github.com/YosysHQ/picorv32.git third_party/picorv32
fi
printf '\nReview the upstream LICENSE and record the checked-out commit:\n'
git -C third_party/picorv32 rev-parse HEAD
