{ inputs, ... }:
{
  imports = [
    inputs.rust-flake.flakeModules.default
    inputs.rust-flake.flakeModules.nixpkgs
  ];

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
      globalCrateConfig = {
        autoWire = [ ];

        crane = {
          args = {
            buildInputs = with pkgs; [
              openssl

            ];

            nativeBuildInputs = with pkgs; [
              makeWrapper
              pkg-config
            ];
          };

          extraBuildArgs = {
            postInstall = ''
              # prisma-client-rust-cli looks for openssl binary to determine its version
              # https://github.com/Brendonovich/prisma-client-rust/blob/3ac68d0052533d3ae0332d93a56a8ad169c2ee18/cli/src/binaries/platform.rs#L112
              wrapProgram $out/bin/prisma-rust-cli \
                --prefix PATH : "${lib.makeBinPath [ pkgs.openssl ]}" \
                --set PRISMA_GLOBAL_CACHE_DIR "${self'.packages.prisma-cli-bin}"
            '';
          };
        };
      };
    in
    {
      rust-project = {
        src =
          let
            filterCargoSources =
              path: type:
              config.rust-project.crane-lib.filterCargoSources path type
              && !(lib.hasSuffix ".toml" path && !lib.hasSuffix "Cargo.toml" path);
          in
          lib.cleanSourceWith {
            src = inputs.self;
            filter = path: type: filterCargoSources path type || lib.hasSuffix ".proto" path;
          };

        crates = {
          prisma-rust-cli = {
            imports = [ globalCrateConfig ];
            autoWire = [
              "crate"
              "clippy"
            ];
          };
        };
      };
    };
}
