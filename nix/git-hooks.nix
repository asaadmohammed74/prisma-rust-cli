{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];

  perSystem =
    { config, system, ... }:
    {
      pre-commit.check.enable = false;
    };
}
