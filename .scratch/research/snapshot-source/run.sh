#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
nix develop -c dune build @install
nix develop -c sh -c 'export OCAMLPATH="$PWD/_build/install/default/lib"; cd .scratch/research/snapshot-source; dune exec --root . ./spike.exe'
