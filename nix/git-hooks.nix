{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];

  perSystem =
    { config, system, ... }:
    {
      make-shells.default.shellHook = config.pre-commit.installationScript;

      pre-commit = {
        check.enable = false;

        settings.hooks = {
          check-toml.enable = true;
          check-yaml.enable = true;
        };
      };
    };
}
