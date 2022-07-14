let
  verdaccio-nix = builtins.getFlake "github:aameen-tulip/verdaccio-nix";
  config = {
    listenPort   = 420;
    # Extra CLI utilities/wrappers for writing local configs to use your
    # configured Verdaccio server.
    # Thes are defined in `verdaccio-cfg.nix'.
    utils.enable = true;
    # Fallback package registries
    settings.uplinks = {
      # This NPM entry is the default, but you must explicitly name it when
      # defining uplinks explicitly.
      npmjs.url = "https://registry.npmjs.org";
      # Some private registry
      my-org.url = "https://intranet.my-org.net/npm-registry";
    };
  };
in verdaccio-nix.mkVerdaccioWrapper { inherit config; }
