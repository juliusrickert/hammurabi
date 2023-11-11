{
  inputs = {
    naersk.url = "github:nix-community/naersk/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, naersk }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        naersk-lib = pkgs.callPackage naersk { };
      in
      {
        defaultPackage = naersk-lib.buildPackage {
          src = ./.;
          nativeBuildInputs = with pkgs; [
            pkg-config
            openssl.dev
          ];
        };
        devShell = with pkgs; mkShell {
          buildInputs = [
            pkg-config
            openssl.dev

            # Git
            pre-commit
            #Prolog
            swiProlog
            # Ruby
            ruby
            # Rust
            cargo
            rustc
            rustfmt
            rustPackages.clippy
            ];
          RUST_SRC_PATH = rustPlatform.rustLibSrc;
        };
      });
}

