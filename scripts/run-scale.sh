#! /usr/bin/env nix-shell
#! nix-shell -i bash
#
# Pin nixpkgs revision for reproducibility
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/d2b52322f35597c62abf56de91b0236746b2a03d.tar.gz
#
# Packages
#! nix-shell -p coreutils parallel xsv zstd
#
set -euxo pipefail

# Get relative paths from this file
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

doit() {
        name=$(basename $1)
	outdir=/home/julius/ham_out/${name}_client-$2

	mkdir -p $outdir
	
	/home/julius/hammurabi/target/debug/scale "$2" "$1" ../tmp $outdir --start=0 --end="$(expr $(ls $1 | wc -l) - 1)"
}

export -f doit
parallel --verbose -t doit {} ::: /mnt/nas/ham_csv/*.jsonl.zst ::: chrome firefox
