# The systemd user unit for Leash, in one place (svc-dit8, svc-46f0): the
# home-manager module in this directory assigns `unit`, and the flake's `leash-unit`
# output renders the same value with `toText`, so the text installed by hand is the
# text home-manager writes and `systemd-analyze --user verify` checks the same thing.
#
# ExecStart is the `nix build .#leash` binary with the Door's `run` subcommand
# (Eta_app adds it; a bare invocation runs the same program). The unit belongs to the
# graphical session: After/PartOf graphical-session.target, installed into
# graphical-session.target, `Restart=on-failure` with a two-second delay. The session
# environment the Door needs is XDG_RUNTIME_DIR (systemd's %t) and the Eio backend;
# WAYLAND_DISPLAY and DISPLAY come from the user manager, which the compositor's
# environment-import hook fills (see docs/install.md).
{ lib }:
let
  scalar =
    value: if lib.isBool value then (if value then "true" else "false") else toString value;

  renderValue =
    key: value:
    if lib.isList value then
      lib.concatMapStringsSep "\n" (item: "${key}=${scalar item}") value
    else "${key}=${scalar value}";

  renderSection =
    name: attrs:
    "[${name}]\n"
    + lib.concatStringsSep "\n" (lib.mapAttrsToList renderValue attrs)
    + "\n";
in
rec {
  unit =
    { package }:
    {
      Unit = {
        Description = "Leash browser service for coding agents";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };

      Service = {
        Environment = [
          "XDG_RUNTIME_DIR=%t"
          "EIO_BACKEND=posix"
        ];
        ExecStart = "${package}/bin/leash run";
        Restart = "on-failure";
        RestartSec = 2;
        # The Door exits 0 on SIGTERM, so a stop or a restart is a clean stop and not a
        # failure systemd should count (service-packaging).
        SuccessExitStatus = 0;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

  toText =
    unit:
    lib.concatStringsSep "\n" (map (name: renderSection name unit.${name}) [
      "Unit"
      "Service"
      "Install"
    ]);
}
