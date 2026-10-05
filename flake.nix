{
  description = "Leash OCaml development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.ox = {
    url = "git+file:///home/ribelo/projects/ribelo/ocaml/ox?ref=master&rev=527f8a443366e3e171b18c987dcfcafad3558233";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.opam-nix.follows = "opam-nix";
    inputs.opam-repository.follows = "opam-repository";
    inputs.oxcaml.follows = "oxcaml";
    inputs.oxcaml-opam-repository.follows = "oxcaml-opam-repository";
  };
  inputs.opam-nix = {
    url = "github:tweag/opam-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.opam-repository = {
    url = "github:ocaml/opam-repository/4fde328c35c75c2c7269e426a3cf041888890018";
    flake = false;
  };
  inputs.oxcaml-opam-repository = {
    url = "github:oxcaml/opam-repository/d65f081024758576f7a848bbd369863e7f7c1e81";
    flake = false;
  };
  inputs.oxcaml = {
    url = "github:oxcaml/oxcaml/5.4.0-ox2";
    flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      ox,
      opam-nix,
      opam-repository,
      oxcaml,
      oxcaml-opam-repository,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          cleanLocalSource =
            src:
            pkgs.lib.cleanSourceWith {
              inherit src;
              filter =
                path: type:
                let
                  base = baseNameOf path;
                in
                !(
                  base == ".git"
                  || base == "_build"
                  || base == "_opam"
                  || base == ".opam"
                  || base == ".opam-oxcaml"
                  || base == ".reference"
                  || base == ".scratch"
                  || base == ".motel-data"
                  || base == ".nema"
                  || base == ".pi"
                  || base == ".hill-climbing"
                  || base == "node_modules"
                );
            };
          leashSrc = cleanLocalSource ./.;
          # svc-46f0: ox's own metadata names the ox_json dependency of ox_http
          # and the ppx_yojson_minimal preprocessor of the ox_ai_* packages (Ox
          # 00501a5c), so the branch builds from opam-nix unpatched.
          oxSrc = cleanLocalSource ox;
          opamLib = opam-nix.lib.${system};
          oxRepo = opamLib.makeOpamRepo oxSrc;
          patchedOxcaml = pkgs.runCommand "oxcaml-source-patched" { } ''
            cp -R ${oxcaml} "$out"
            chmod -R u+w "$out"
            substituteInPlace "$out/default.nix" \
              --replace-fail 'version = "5.2.0+ox";' 'version = "5.4.0+ox";'
            ${pkgs.perl}/bin/perl -0pi -e 's|new: old: \{\n        buildInputs = \[|new: old: rec {\n        version = "20231231";\n        src = pkgs.fetchFromGitLab {\n          domain = "gitlab.inria.fr";\n          owner = "fpottier";\n          repo = "menhir";\n          rev = version;\n          sha256 = "sha256-veB0ORHp6jdRwCyDDAfc7a7ov8sOeHUmiELdOFf/QYk=";\n        };\n        patches = [ ];\n        buildInputs = [|' "$out/default.nix"
          '';
          oxcamlCompiler =
            (pkgs.callPackage "${patchedOxcaml}/default.nix" {
              src = patchedOxcaml;
              multidomain = true;
              ocamltest = true;
              pollInsertion = true;
              stackChecks = true;
              warnError = false;
            }).overrideAttrs (old: {
              # OxCaml's runtime primitive declarations rely on pre-C23 [f()].
              NIX_CFLAGS_COMPILE = "${old.NIX_CFLAGS_COMPILE or ""} -std=gnu17";
              doCheck = false;
            });
          oxcamlSystemOverlay = final: prev: {
            ocaml-system = prev.ocaml-system.overrideAttrs (old: {
              nativeBuildInputs = [ oxcamlCompiler ];
              preBuild = (old.preBuild or "") + ''
                substituteInPlace gen_ocaml_config.ml \
                  --replace-fail '5.4.0' '5.4.0+ox'
              '';
            });
            ocaml-config = prev.ocaml-config.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                ln -s ocaml-config/gen_ocaml_config.ml \
                  "$out/share/gen_ocaml_config.ml"
              '';
            });
            ocamlfind = prev.ocamlfind.overrideAttrs (old: {
              postFixup = (old.postFixup or "") + ''
                replacement='"'"$out"'/lib/ocaml/5.4.0/site-lib/toplevel"'
                substituteInPlace "$out/bin/ocaml" \
                  --replace-fail '"$OCAML_TOPLEVEL_PATH"' "$replacement"
              '';
            });
            topkg = prev.topkg.overrideAttrs (old: {
              buildPhase = builtins.replaceStrings
                [ ''args+=("ocaml")'' ]
                [ ''args+=("${final.ocamlfind}/bin/ocaml")'' ]
                old.buildPhase;
            });
            fmt = prev.fmt.overrideAttrs (old: {
              buildPhase = builtins.replaceStrings
                [ ''args+=("ocaml")'' ]
                [ ''args+=("${final.ocamlfind}/bin/ocaml")'' ]
                old.buildPhase;
            });
            mtime = prev.mtime.overrideAttrs (old: {
              buildPhase = builtins.replaceStrings
                [ ''args+=("ocaml")'' ]
                [ ''args+=("${final.ocamlfind}/bin/ocaml")'' ]
                old.buildPhase;
            });
          };
          scope = opamLib.buildOpamProject
            {
              inherit pkgs;
              overlays = [ oxcamlSystemOverlay ];
              repos = [
                # Upstream Eio 1.6 from ox, never the oxcaml/eio snapshot (ox ^neio-w4hd).
                ox.legacyPackages.${system}.eioOpamRepository
                oxRepo
                oxcaml-opam-repository
                opam-repository
              ];
              resolveArgs.env.sys-ocaml-version = "5.4.0";
            }
            "leash"
            leashSrc
            {
              angstrom = "0.16.1";
              faraday = "0.8.2";
              ocaml-system = "*";
              yojson = "2.2.2+ox";
            };

          # daily-ulmi: archive builds have no .git; retain their source revision.
          leash = scope.leash.overrideAttrs (_: {
            LEASH_COMMIT = self.rev or (self.dirtyRev or "unknown");
          });
          unit = import ./packaging/leash-unit.nix { lib = pkgs.lib; };
        in
        {
          default = leash;
          inherit leash;

          # svc-dit8: the generated unit the home-manager module writes, as a file, for
          # a hand install and for `systemd-analyze --user verify` (docs/install.md).
          leash-unit = pkgs.writeTextFile {
            name = "leash-unit";
            destination = "/leash.service";
            text = unit.toText (unit.unit { package = leash; });
          };
        }
      );

      # svc-dit8: the home-manager module, with the package already filled in from this
      # flake's packages, so an import of it is the whole install:
      #
      #   imports = [ inputs.leash.homeManagerModules.leash ];
      #   ribelo.leash.enable = true;
      homeManagerModules.leash = { pkgs, lib, ... }: {
        imports = [ ./packaging/home-manager.nix ];
        ribelo.leash.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.leash;
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          switchName = "5.4.0+ox";
          sharedOpamRoot = "$HOME/.cache/opam";

          setup = pkgs.writeShellApplication {
            name = "leash-opam-install";
            runtimeInputs = [
              pkgs.autoconf
              pkgs.coreutils
              pkgs.git
              pkgs.gnumake
              pkgs.m4
              pkgs.nix
              pkgs.opam
              pkgs.patch
              pkgs.pkg-config
            ];
            text = ''
              switch_name="''${1:-${switchName}}"
              repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
              cd "$repo_root"

              export OPAMROOT="''${OPAMROOT:-${sharedOpamRoot}}"
              export OPAMYES=1

              if ! opam switch list --short | grep -Fxq "$switch_name"; then
                echo "Missing OPAM switch '$switch_name'." >&2
                echo "Run: shared-ocaml-switch-init" >&2
                exit 1
              fi

              export OPAMSWITCH="$switch_name"
              eval "$(opam env --switch "$switch_name" --set-switch)"

              # etabuild-e0gr: install committed Ox master for development.
              ox_path="''${OX_PATH:-$repo_root/../ocaml/ox}"
              export OX_OPAM_PACKAGES="''${OX_OPAM_PACKAGES:-ox ox_app ox_caps ox_lint ox_process ox_ipc ox_rpc ox_json ox_observability ox_test}"
              if command -v ox-opam-install >/dev/null 2>&1; then
                OX_REPO_ROOT="$ox_path" ox-opam-install
              elif [ -d "$ox_path" ]; then
                OX_REPO_ROOT="$ox_path" nix develop "$ox_path" -c ox-opam-install
              else
                echo "Missing Ox checkout at $ox_path" >&2
                exit 1
              fi

              opam pin add --kind=git leash "git+file://$repo_root#master" --no-action --yes
              opam install leash --assume-depexts --yes

              echo "Leash is installed into OPAM switch: $switch_name"
              echo "Shared OPAMROOT: $OPAMROOT"
              echo "Enter it with: nix develop"
            '';
          };

          toolchainCheck = pkgs.writeShellApplication {
            name = "leash-opam-check-toolchain";
            runtimeInputs = [
              pkgs.git
              pkgs.opam
            ];
            text = ''
              repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
              cd "$repo_root"

              export OPAMROOT="''${OPAMROOT:-${sharedOpamRoot}}"
              export OPAMSWITCH="${switchName}"
              eval "$(opam env --switch "${switchName}" --set-switch)"

              test "$(ocamlc -version)" = "${switchName}"
              dune --version >/dev/null
              opam list --installed --short ocamlformat | grep -Fxq ocamlformat
              opam list --installed --short merlin | grep -Fxq merlin
              opam list --installed --short ocaml-lsp-server | grep -Fxq ocaml-lsp-server
            '';
          };

          test = pkgs.writeShellApplication {
            name = "leash-test";
            runtimeInputs = [
              pkgs.git
              pkgs.opam
            ];
            text = ''
              switch_name="''${1:-${switchName}}"
              repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
              cd "$repo_root"

              export OPAMROOT="''${OPAMROOT:-${sharedOpamRoot}}"
              export OPAMSWITCH="$switch_name"
              eval "$(opam env --switch "$switch_name" --set-switch)"

              dune build packages/leash
              dune runtest packages/leash --force
            '';
          };

          hostPackages =
            [
              pkgs.autoconf
              pkgs.cacert
              pkgs.curl
              pkgs.git
              pkgs.gnumake
              pkgs.m4
              pkgs.opam
              pkgs.patch
              pkgs.pkg-config
              pkgs.unzip
              pkgs.which
              setup
              test
              toolchainCheck
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              pkgs.gmp
              pkgs.libffi
              pkgs.openssl
              pkgs.sqlite
              pkgs.zlib
            ];

          shellHook = ''
            export OPAMROOT="''${OPAMROOT:-${sharedOpamRoot}}"
            if [ -d "$OPAMROOT/${switchName}" ]; then
              export OPAMSWITCH="${switchName}"
              eval "$(opam env --switch "${switchName}" --set-switch)"
            fi
            if [ -t 1 ]; then
              echo "Leash OxCaml shell (${switchName})"
              echo "Shared OPAMROOT: $OPAMROOT"
              echo "Run 'shared-ocaml-switch-init' before 'leash-opam-install'."
              echo "Run 'leash-test' after setup to build and test shipped packages."
            fi
          '';
        in
        {
          default = pkgs.mkShell {
            packages = hostPackages;
            inherit shellHook;
          };
        }
      );
    };
}
