{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    crane.url = "github:ipetkov/crane";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";

    prisma-utils.url = "github:VanCoding/nix-prisma-utils";
    prisma-utils.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      crane,
      fenix,
      prisma-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        rustToolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-Qxt8XAuaUR2OMdKbN4u8dBJOhSHxS+uS06Wl9+flVEk=";
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        src = craneLib.cleanCargoSource ./.;

        commonArgs = {
          inherit src;

          strictDeps = true;

          buildInputs = with pkgs; [
            openssl
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        prisma-cli-crate = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          inherit (commonArgs) buildInputs;

          nativeBuildInputs = commonArgs.nativeBuildInputs ++ [
            pkgs.makeWrapper
          ];

          postInstall = ''
            wrapProgram $out/bin/prisma-rust-cli --set PRISMA_GLOBAL_CACHE_DIR ${prisma-cli-bin.package}
          '';
        });

        prisma =
          (prisma-utils.lib.prisma-factory {
            inherit pkgs;

            prisma-fmt-hash = "sha256-v0EWddy7VVuxCK9BB8LqnBhIcZet+kVhuvzlKIS+qfs=";
            query-engine-hash = "sha256-nffpy13K7Z+ZLUjkdLyLIN1+mIaDpFJ7yglal4rWO9o=";
            libquery-engine-hash = "sha256-o/16nzI8emeM1EvCdqtL53CJ7yEyJjWusKovGXMllo4=";
          })
          # hardcoded in prisma-client-rust
          # https://github.com/Brendonovich/prisma-client-rust/blob/0.6.11/cli/src/binaries/mod.rs
          # which is now archived, so it's not going to change.
          .fromCommit
            "d6e67a83f971b175a593ccc12e15c4a757f93ffe";

        prisma-cli-bin = (
          pkgs.callPackage ./prisma-cli-bin.nix {
            inherit pkgs;

            # the prisma-client-go version that is used by prisma-client-rust.
            prisma-cli-version = "4.8.0";
            prisma-cli-hash = "sha256-1xLi64oM609dXJc3cd64VoXvephiSiQBhsRq8qxvjrI=";
            prisma-engines-commit = "d6e67a83f971b175a593ccc12e15c4a757f93ffe";
            query-engine-hash = "sha256-nffpy13K7Z+ZLUjkdLyLIN1+mIaDpFJ7yglal4rWO9o=";
            migration-engine-hash = "sha256-u3jxty/tUI5/QrR8DJKionMtlpccs7XTBb0Hqqg7gi0=";
            introspection-engine-hash = "sha256-IODNrQ4J0pyJiOjIegI/yqgSZjPCF9Uffca1GziHK28=";
            prisma-fmt-hash = "sha256-v0EWddy7VVuxCK9BB8LqnBhIcZet+kVhuvzlKIS+qfs=";
          }
        );
      in
      with pkgs;
      {
        checks = {
          inherit prisma-cli-crate;
        };

        packages.default = prisma-cli-crate;

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};
        };
      }
    );
}
