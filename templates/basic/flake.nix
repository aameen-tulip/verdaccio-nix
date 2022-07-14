{
  description = "My Configured Verdaccio Server";

  inputs.verdaccio-nix = {
    url = "github:aameen-tulip/verdaccio-nix";
    inputs.nixpkgs.follows = "/nixpkgs";
    inputs.utils.follows   = "/utils";
  };
  inputs.utils.url = "github:numtide/flake-utils";
  inputs.utils.inputs.nixpkgs.follows  = "/nixpkgs";

  outputs = { self, nixpkgs, utils, verdaccio-nix, ... }: let
    config = {
      listenPort = 420;
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
    inherit (utils.lib) eachDefaultSystemMap;
  in {
    packages = eachDefaultSystemMap ( system: let
      verdaccioConfigured = verdaccio-nix.evalVerdaccioConfig {
        inherit config system;
        withDocs = true;
      };
    in {
      verdaccio = verdaccioConfigured.wrapper.package;
      cfg-docs  = verdaccioConfigured.docs.all;
      cfg-yaml  = verdaccioConfigured.configFile;
      default   = self.packages.${system}.verdaccio;
    } );
  };
}
