{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = {
    treefmt = {
      projectRootFile = "./flake.nix";

      programs = {
        nixfmt.enable = true;
        statix.enable = true;
        shfmt.enable = true;
        prettier.enable = true;
        just.enable = true;
        rustfmt.enable = true;
        yamlfmt.enable = true;
        taplo.enable = true;
        actionlint.enable = true;

        deadnix = {
          enable = true;
          no-lambda-arg = true;
          no-lambda-pattern-names = true;
          no-underscore = true;
        };
      };

      settings = {
        on-unmatched = "fatal";

        global.excludes = [
          "prisma/schema.prisma"
          ".gitignore"
          "*.proto"
        ];
      };
    };

    pre-commit.settings.hooks.treefmt.enable = true;
  };
}
