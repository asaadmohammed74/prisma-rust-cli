{ inputs, ... }:
{
  perSystem =
    {
      config,
      self',
      pkgs,
      lib,
      system,
      ...
    }:
    let
      craneLib = (inputs.crane.mkLib pkgs).overrideToolchain (
        p:
        p.rust-bin.stable.latest.minimal.override {
          extensions = [
            "rust-analyzer"
            "rust-src"
            "clippy"
          ];
        }
      );

      src =
        let
          filterCargoSources =
            path: type:
            craneLib.filterCargoSources path type
            && !(lib.hasSuffix ".toml" path && !lib.hasSuffix "Cargo.toml" path);
        in
        lib.cleanSourceWith {
          src = inputs.self;
          filter = path: type: filterCargoSources path type;
        };

      commonArgs = {
        inherit src;
        strictDeps = true;

        buildInputs = with pkgs; [
          openssl
        ];

        nativeBuildInputs = with pkgs; [
          pkg-config
          makeWrapper
        ];
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      individualCrateArgs = commonArgs // {
        inherit cargoArtifacts;
        inherit (craneLib.crateNameFromCargoToml { inherit src; }) version;

        doCheck = false;
      };

      fileSetForCrate =
        crate:
        lib.fileset.toSource {
          root = ../.;
          fileset = lib.fileset.unions [
            ../Cargo.toml
            ../Cargo.lock
            (craneLib.fileset.commonCargoSources crate)
          ];
        };

      prisma-rust-cli = craneLib.buildPackage (
        individualCrateArgs
        // {
          pname = "prisma-rust-cli";
          cargoExtraArgs = "-p prisma-rust-cli";
          src = fileSetForCrate ../crates/prisma-rust-cli;

          postInstall = ''
            # prisma-client-rust-cli looks for openssl binary to determine its version
            # https://github.com/Brendonovich/prisma-client-rust/blob/3ac68d0052533d3ae0332d93a56a8ad169c2ee18/cli/src/binaries/platform.rs#L112
            wrapProgram $out/bin/prisma-rust-cli \
              --prefix PATH : "${lib.makeBinPath [ pkgs.openssl ]}" \
              --set PRISMA_GLOBAL_CACHE_DIR "${self'.packages.prisma-cli-bin}"
          '';
        }
      );
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;

        overlays = [
          inputs.rust-overlay.overlays.default
        ];
      };

      packages = {
        inherit prisma-rust-cli;
      };

      devShells.default = craneLib.devShell {
        inherit (self') checks;

        shellHook = config.pre-commit.installationScript;
      };
    };
}
