#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
nix develop -c dune build @install
secret-env ai -- nix develop -c sh -c 'export OCAMLPATH="$PWD/_build/install/default/lib"; cd .scratch/research/state-measurement; dune exec --root . ./spike.exe'
python3 -m json.tool .scratch/research/state-measurement/results.json .scratch/research/state-measurement/results.pretty.json
