{ config, lib, pkgs, verdaccioUnwrapped, ... }: let
  inherit (lib) mkOption;
  cfg = config.verdaccio;
  ucfg = cfg.utils;
  authEnum = lib.types.enum ["all" "authenticated" "anonymous"];
  settingsFormat = pkgs.formats.yaml {};
  registryUrl = "http://${cfg.listenHost}:${toString cfg.listenPort}/";
in  {

/* -------------------------------------------------------------------------- */

  options.verdaccio = {
    enable = lib.mkEnableOption "Verdaccio service";

    utils = {
      enable = lib.mkEnableOption "Dev utilities for configured Verdaccio";
      # This cache dir is wiped out when Verdaccio server exits.
      cacheDir = mkOption {
        description = "Path to stash cached files, such as file backups";
        default = "/var/verdaccio/util/cache";
        type = lib.types.path;
      };
      package = mkOption {
        description = "Dev utilities for configured Verdaccio";
        type = lib.types.package;
      };
    };

    wrapper =  {
      enable = lib.mkEnableOption "Verdaccio wrapper";
      package = mkOption {
        description = "configured Verdaccio wrapper executable";
        type = lib.types.package;
      };
    };

    user = mkOption {
      description = "user to execute verdaccio service (NixOS only)";
      default     = "verdaccio";
      type        = lib.types.str;
    };

    /* CLI flags */
    # -l <HOST>:<PORT>, --config <PATH>
    configFile = mkOption {
      description = "Path to config.yarn, which will be parsed and extended";
      example     = "/home/user/.config/verdaccio/config.yaml";
      default     = null;
      type        = lib.types.nullOr lib.types.path;
    };
    /* CLI flags, split into sub-options */
    listenHost = mkOption {
      description = "Hostname or IPv4 address to listen on";
      default     = "localhost";
      type        = lib.types.strMatching "[a-zA-Z0-9.-]+";
    };
    listenPort = mkOption {
      description = "Port number to listen on. Must be 1-65535";
      default     = 4873;
      type        = lib.types.port;
    };

    /* For config.yaml */
    settings = mkOption {
      description = ''
        Verdaccio config.yaml settings.
        This may not be used if `verdaccio.configFile' is set.
        Misc config may be added with `settings.extraConfig', but may not
        merge cleanly with other YAML settings.
        More Info: https://github.com/verdaccio/verdaccio/tree/master/conf
      '';

      default = {};
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        /* Declared options allow for type checking. */
        options = {
          storage = mkOption {
            description = "Path to a directory to store packages";
            default     = "/var/verdaccio/storage";
            type        = lib.types.path;
          };
          plugins = mkOption {
            description = "Path to a directory with plugins to include";
            default     = "/var/verdaccio/plugins";
            type        = lib.types.path;
          };
          web = {
            title = mkOption {
              description = "Registry \"title\"/name used in Web UI";
              default     = "Verdaccio";
              type        = lib.types.str;
            };
            gravatar = mkOption {
              description = "Enable gravatar support";
              default     = true;
              type        = lib.types.bool;
            };
            sort_packages = mkOption {
              description = "Order packages in ascending order?";
              default     = true;
              type        = lib.types.bool;
            };
            darkMode = mkOption {
              description = "Convert your UI to the dark side";
              default     = true;
              type        = lib.types.bool;
            };
            logo = mkOption {
              default  = null;
              type     = with lib.types; nullOr ( either path string );
              example  = lib.literalExpression ''
                "http://somedomain/favicon/ico" or "/path/favicon.ico"
              '';
            };
            rateLimit = {
              windowMs = mkOption {
                description = "Refresh rate in milliseconds.";
                default     = 1000;
                type        = lib.types.ints.unsigned;
              };
              max = mkOption {
                default = 1000;
                type    = lib.types.ints.unsigned;
              };
            };
          };  # End web

          auth.htpasswd = {
            file = mkOption {
              type    = lib.types.path;
              default = "/var/verdaccio/htpasswd";
            };
            max_users = mkOption {
              description = ''
                Maximum amount of users allowed to register.
                You can set this to -1 to disable registration.
                You can set this to null for unlimited users ( default ).
              '';
              default = null;
              type = lib.types.nullOr (
                lib.types.addCheck lib.types.int ( x: (-1) <= x ) // {
                  name = "unsignedOrNegativeOne";
                  description = "unsigned integer or -1, meaning >=-1";
                } );
            };  # End max_users
          };  # End auth.htpasswd

          uplinks = mkOption {
            description = "List of other known repositories to fetch from";
            default     = { npmjs = { url = "https://registry.npmjs.org"; }; };
            type = lib.types.attrsOf ( lib.types.submodule { options = {
              url = mkOption { type = lib.types.str; };
            }; } );
          };

          packages = mkOption {
            description = ''
              Per-package permissions (all|authenticated|anonymous).
              Names may use glob patterns.
              Proxy names must be named in `config.verdacctio.settings.uplinks', which provides "npmjs" by default.
              Proxy may be set to "null", to force use of verdaccio, but it may not be omitted.
            '';
            default = {
              # A scoped package
              "@*/*" = {
                access    = "all";
                publish   = "authenticated";
                unpublish = "authenticated";
                proxy     = "npmjs";
              };
              "**" = {
                access    = "all";
                publish   = "authenticated";
                unpublish = "authenticated";
                proxy     = "npmjs";
              };
            };
            type = lib.types.attrsOf ( lib.types.submodule { options = {
              access    = mkOption { type = authEnum; };
              publish   = mkOption { type = authEnum; };
              unpublish = mkOption { type = authEnum; };
              proxy     = mkOption { type = lib.types.nullOr lib.types.str; };
            }; } );
          };  # End packages

          server.keepAliveTimeout = mkOption {
            description = ''
              Kill incoming connections after X seconds.
              0 will not kill connections ( behaves like Node.js HTTP pre 8.0.0 ).
            '';
            default = 60;
            type    = lib.types.ints.positive;
          };
          middlewares.audit.enabled = lib.mkEnableOption "audit";

          logs = {
            # FIXME: enum these?
            type   = mkOption { default = "stdout"; type = lib.types.str; };
            format = mkOption { default = "pretty"; type = lib.types.str; };
            level  = mkOption { default = "http";   type = lib.types.str; };
          };

          experiments = mkOption {
            description = "Experimental options - use at your own risk";
            default = {};
            type = lib.types.submodule {
              options = {
                token = mkOption {
                  description = "Support for http token command.";
                  default     = false;
                  type        = lib.types.bool;
                };
                bytesin_off = mkOption {
                  description = "disable writing body size to logs";
                  type        = lib.types.bool;
                  default     = false;
                };
                tarball_url_redirect = mkOption {
                  description = ''
                    Enable tarball URL redirect for hosting tarball with a different
                    server, the tarball_url_redirect can be a template string.
                    The tarball_url_redirect can be a function, takes packageName and
                    filename and returns the url, when working with a js configuration
                    file.
                  '';
                  example = lib.literalExpression ''
                    a URL template:
                      https://mycdn.com/verdaccio/''${packageName}/''${filename}
                    or a function:
                      tarball_url_redirect(packageName, filename) {
                        const signedUrl = // generate a signed url
                        return signedUrl;
                      }
                  '';
                  type = with lib.types; nullOr ( either path string );
                  default = null;
                };  # End tarball_url_redirect
              };  # End experiments.submodule.options
            };  # End experiments.submodule
          }; # End experiments
        }; # End settings.submodule.options
      };  # End settings.submodule;
    };  # End settings
  };  # End options.verdaccio


/* -------------------------------------------------------------------------- */

  config = lib.mkIf cfg.enable {
    verdaccio = let
      # Ensure user has permissions for these dirs.
      handleDirs = let
        dirsL = [
          ucfg.cacheDir
          cfg.settings.storage
          cfg.settings.plugins
          ( dirOf cfg.settings.auth.htpasswd.file )
        ];
        dirs = builtins.concatStringsSep " " dirsL;
      in ''
        : "''${ID:=id}"
        : "''${MKDIR:=mkdir}"
        : "''${CHOWN:=chown}"
        : "''${SUDO:=sudo}"
        : "''${_handledDirs=}"
        handleDirs() {
          test -n "$_handledDirs" && return 0
          local _doPrompt _userGroup
          _doPrompt=
          for d in ${dirs}; do test -w "$d" || _doPrompt=:; done
          test -z "$_doPrompt" && return 0
          _userGroup="$( $ID -un; ):$( $ID -gn; )"
          {
            echo ""
            echo "Verdaccio server requires read/write permissions for the"
            echo "following directories:"
            printf '\t%s\n' ${dirs};
            echo ""
            echo "We will request authorization to create/set perms."
            echo "You may also setup these directories manually if desired."
            echo "The following user/group will be used: $_userGroup"
            echo ""
          } >&2
          $SUDO -kv
          for d in ${dirs}; do
            test -w "$d" && continue
            set -v
            $SUDO $MKDIR -p "$d"
            $SUDO $CHOWN -R "$_userGroup" "$d"
            set +v
          done
          _handledDirs=:
        }
      '';
    in {
      configFile = settingsFormat.generate "config.yaml" cfg.settings;

      wrapper.package = lib.mkIf cfg.wrapper.enable ( derivation {
        name = "verdaccio-wrapped";
        inherit (pkgs.stdenv) system;
        PATH="${pkgs.coreutils}/bin";
        wrapper = ''
          #! ${pkgs.stdenv.shell}

          ${handleDirs}
          handleDirs

          ${if cfg.utils.enable then ''
              _rpr="Would you like to auto-restore backed up project files?"
              read -n 1 -p "$_rpr (Y/n) " _doRestore
              case "$_doRestore" in
                [yY])
                  trap 'es="$?"; ${cfg.utils.package}/bin/restore; exit "$es"' \
                       HUP TERM EXIT INT QUIT
                ;;
                *) :; ;;
              esac
              echo ""
            '' else "exec  \\"}
          ${verdaccioUnwrapped}/bin/verdaccio  \
            -l ${cfg.listenHost}:${toString cfg.listenPort}  \
            ${if cfg.configFile != null then "-c ${cfg.configFile}" else ""}
        '';
        buildPhase = ''
          mkdir -p "$out/bin"
          cat "$wrapperPath" > "$out/bin/verdaccio"
          chmod +x "$out/bin/verdaccio"
        '' + ( lib.optionalString cfg.utils.enable ''
          ln -s -- ${cfg.utils.package}/bin/rewrite "$out/bin/rewrite"
          ln -s -- ${cfg.utils.package}/bin/restore "$out/bin/restore"
        '' );
        passAsFile = ["wrapper" "buildPhase"];
        builder = "${pkgs.stdenv.shell}";
        args = ["-c" ". $buildPhasePath"];
      } );

      utils.package = lib.mkIf ucfg.enable ( derivation {
        name = "verdaccio-wrapped";
        inherit (pkgs.stdenv) system;
        PATH="${pkgs.coreutils}/bin";
        rewrite = ''
          #! ${pkgs.bash}/bin/bash
          set -eu
          PATH="''${PATH+$PATH:}${pkgs.jq}/bin"
          pdir="$( realpath -s "''${1%/package.json}"; )"
          pjs="$pdir/package.json"
          pjsBackup="${ucfg.cacheDir}/''${pjs#/}"

          : "''${ID:=id}"
          : "''${MKDIR:=mkdir}"
          : "''${CHOWN:=chown}"

          ${handleDirs}
          handleDirs

          if ! test -r "$pjs"; then
            echo "Could not locate package.json for path $pdir" >&2
            exit 1
          fi
          backupPjs() {
            local _userGroup
            $MKDIR -p "${ucfg.cacheDir}/$pdir" 2>/dev/null
            if ! test -w "${ucfg.cacheDir}/$pdir"; then
              _userGroup="$( $ID -un; ):$( $ID -gn; )"
              {
                echo ""
                echo "Verdaccio server requires read/write permissions for the"
                echo "following directory:"
                printf '\t%s\n' ${ucfg.cacheDir}/$pdir;
                echo ""
                echo "We will request authorization to create/set perms."
                echo "You may also setup these directories manually if desired."
                echo "The following user/group will be used: $_userGroup"
                echo ""
              } >&2
              $SUDO -kv
              $SUDO $MKDIR -p "${ucfg.cacheDir}/$pdir"
              $SUDO $CHOWN -R "" "${ucfg.cacheDir}"
            fi
            if ! test -r "$pjsBackup"; then
              cp -pr --reflink=auto -- "$pjs" "$pjsBackup"
            fi
          }
          writePublishCfg() {
            backupPjs
            jq -SM '.publishConfig.registry|="${registryUrl}"' "$pjsBackup"  \
                   > "$pjs"
          }
          writePublishCfg
        '';
        restore = ''
          #! ${pkgs.bash}/bin/bash
          set -eu
          PATH="''${PATH+$PATH:}${pkgs.findutils}/bin:${pkgs.coreutils}/bin"

          : "''${SUDO:=sudo}"

          ${handleDirs}
          handleDirs

          if ! test -d ${ucfg.cacheDir}; then
            exit 0  # No cached package.json files exist. That was easy.
          fi
          pushd ${ucfg.cacheDir} > /dev/null
          for pjs in $( find . -type f -name package.json -print; ); do
            cp -pr --reflink=auto -- "$pjs" "/''${pjs#./}"
            echo "Restored: /''${pjs#./}"
            rm -f -- "$pjs"
            rmdir --ignore-fail-on-non-empty -p "''${pjs%/*}" 2>/dev/null
          done
        '';
        buildPhase = ''
          mkdir -p "$out/bin"
          cat "$rewritePath" > "$out/bin/rewrite"
          cat "$restorePath" > "$out/bin/restore"
          chmod +x "$out/bin/rewrite" "$out/bin/restore"
        '';
        passAsFile = ["rewrite" "restore" "buildPhase"];
        builder = "${pkgs.stdenv.shell}";
        args = ["-c" ". \"$buildPhasePath\""];
      } );

    };
  };


/* -------------------------------------------------------------------------- */

}  # End Global
