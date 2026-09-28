# svc-dit8: Leash as a home-manager module, in the shape of the Pie entry in
# nixos-config (home/common/desktop/shell-stack.nix): the unit is declared here, the
# flake's `homeManagerModules.leash` fills `package` in from the flake's own
# `nix build .#leash` output, and `docs/install.md` is the operator's procedure.
{ config, lib, ... }:
let
  cfg = config.ribelo.leash;
  unit = import ./leash-unit.nix { inherit lib; };
in
{
  options.ribelo.leash = {
    enable = lib.mkEnableOption "the Leash browser service";

    package = lib.mkOption {
      type = lib.types.package;
      description = ''
        The Leash package whose "bin/leash" the unit runs: the output of
        "nix build .#leash". Importing the flake's "homeManagerModules.leash" sets
        this from the flake's packages, so that import needs nothing else.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.leash = unit.unit { package = cfg.package; };
  };
}
