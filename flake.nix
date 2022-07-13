{
  description = "Node.js Package Registry server";

  inputs.utils.url  = "github:numtide/flake-utils";
  inputs.ak-nix.url = "github:aakropotkin/ak-nix";
  inputs.ak-nix.inputs.nixpkgs.follows = "/nixpkgs";
  inputs.ak-nix.inputs.utils.follows   = "/utils";
  inputs.utils.inputs.nixpkgs.follows  = "/nixpkgs";

  outputs = { self, nixpkgs, utils, ak-nix }: let
    inherit (utils.lib) eachDefaultSystem;
  in eachDefaultSystem ( system: let
    pkgsFor = nixpkgs.legacyPackages.${system};
    nodePackages = import ./default.nix { pkgs = pkgsFor; };
    inherit (nodePackages) sources shell nodeDependencies verdaccio;
    # This just makes a default wrapper available as an installable.
    # NOTE: If you want to configure things, use `mkVerdaccioWrapper' directly.
    verdaccioWrapped = nixpkgs.lib.makeOverridable self.mkVerdaccioWrapper {
      pkgs = pkgsFor;
      verdaccioUnwrapped = nodePackages.verdaccio;
    };
    verdaccioDocs = ( self.evalVerdaccioConfig {
      inherit system;
      pkgs = pkgsFor;
      verdaccioUnwrapped = nodePackages.verdaccio;
      withDocs = true;
    } ).docs;
    app = utils.lib.mkApp { drv = verdaccio; exePath = "/bin/verdaccio"; };
  in {
    packages = {
      default = verdaccio;
      inherit verdaccio verdaccioWrapped;
      configDocs-all = verdaccioDocs.all;
      configDocs-html = verdaccioDocs.html;
      configDocs-markdown = verdaccioDocs.markdown;
    };
    defaultPackage = verdaccio;

    nodeShell   = shell;
    nodeSources = sources;
    inherit nodeDependencies;

    apps.verdaccio = app;
    apps.default   = app;
    apps.verdaccioWrapped = utils.lib.mkApp {
      drv = verdaccioWrapped; exePath = "/bin/verdaccio";
    };
    defaultApp = app;

    overlays = final: prev: {
      inherit verdaccio verdaccioWrapped verdaccioDocs;
    };
  } ) // {

    # Used to evaluate the module as if it were a normal function.
    # FIXME: I'm 99% sure there's new functions in `nixpkgs.lib' that do this
    #        without the boilerplate.
    #        I wrote this based on ~3 year old NixOS modules I wrote.
    evalVerdaccioConfig = {
      config             ? {}
    , system             ? builtins.currentSystem
    , pkgs               ? nixpkgs.legacyPackages.${system}
    , lib                ? nixpkgs.lib
    , verdaccioUnwrapped ? self.packages.${system}.verdaccio
    , withDocs           ? false
    , docgen             ? import "${ak-nix}/pkgs/docgen" { inherit pkgs nixpkgs; }
    }: let
      em  = lib.evalModules {
        modules = [
          ( import ./verdaccio-cfg.nix )
          {
            config = {
              _module.args = { inherit pkgs lib verdaccioUnwrapped; };
              verdaccio = lib.recursiveUpdate {
                enable = true;
                wrapper.enable = true;
              } ( config.verdaccio or {} );
            };
          }
        ];
      };
      docs = docgen.generateDocsForOptions em.options;
    in em.config.verdaccio // ( lib.optionalAttrs withDocs { inherit docs; } );

    mkVerdaccioWrapper = args:
      ( self.evalVerdaccioConfig args ).wrapper.package;

    nixosModules.verdaccio = import ./verdaccio-cfg.nix;
    nixosModules.default   = import ./verdaccio-cfg.nix;
    nixosModule            = import ./verdaccio-cfg.nix;
  };
}
