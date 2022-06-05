{ config, lib, pkgs, verdaccioUnwrapped, ... }:
let
  inherit (lib) mkOption;
  cfg = config.verdaccio;
  authEnum = lib.types.enum ["all" "authenticated" "anonymous"];
  settingsFormat = pkgs.formats.yaml {};
in  {
  options.verdaccio = {
    enable = lib.mkEnableOption "Verdaccio service";

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

  config = lib.mkIf cfg.enable {
    verdaccio = {
      configFile = settingsFormat.generate "config.yaml" cfg.settings;
      wrapper.package = lib.mkIf cfg.wrapper.enable ( derivation {
        name = "verdaccio-wrapped";
        inherit (pkgs.stdenv) system;
        PATH="${pkgs.coreutils}/bin";
        wrapper = ''
          #! ${pkgs.stdenv.shell}
          exec ${verdaccioUnwrapped}/bin/verdaccio                            \
            -l ${cfg.listenHost}:${toString cfg.listenPort}                   \
            ${if cfg.configFile != null then "-c ${cfg.configFile}" else ""}  \
            ;
        '';
        buildPhase = ''
          mkdir -p $out/bin
          cat $wrapperPath > $out/bin/verdaccio
          chmod +x $out/bin/verdaccio
        '';
        passAsFile = ["wrapper" "buildPhase"];
        builder = "${pkgs.stdenv.shell}";
        args = ["-c" ". $buildPhasePath"];
      } );
    };
  };

}  # End Global
