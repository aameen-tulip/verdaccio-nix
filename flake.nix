{
  description = "Node.js Package Registry server";
  inputs.utils.url = "github:numtide/flake-utils";
  inputs.utils.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem ( system: let
    pkgsFor = nixpkgs.legacyPackages.${system};
    nodePackages = import ./default.nix { pkgs = pkgsFor; };
    inherit (nodePackages) sources shell nodeDependencies verdaccio;
    # Used to evaluate the module as if it were a normal function.
    # FIXME: I'm 99% sure there's new functions in `nixpkgs.lib' that do this
    #        without the boilerplate.
    #        I wrote this based on ~3 year old NixOS modules I wrote.
    evalVerdaccioModule = {
      config ? {}, pkgs ? pkgsFor, lib ? nixpkgs.lib
    , verdaccioUnwrapped ? nodePackages.verdaccio
    }: lib.evalModules {
      modules = [
        ( import ./verdaccio-cfg.nix )
        {
          config._module.args =
            { inherit config pkgs lib verdaccioUnwrapped; };
          config.verdaccio.enable = true;
          config.verdaccio.wrapper.enable = true;
        }
      ];
    };
    verdaccioWrapped = nixpkgs.lib.makeOverridable ( args:
      ( evalVerdaccioModule args ).config.verdaccio.wrapper.package ) {};
    app = utils.lib.mkApp { drv = verdaccio; exePath = "/bin/verdaccio"; };
  in {
    packages = { default = verdaccio; inherit verdaccio verdaccioWrapped; };
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

    overlays = final: prev: { inherit verdaccio verdaccioWrapped; };
  } ) // {
    nixosModules.verdaccio = import ./verdaccio-cfg.nix;
    nixosModules.default   = import ./verdaccio-cfg.nix;
    nixosModule            = import ./verdaccio-cfg.nix;
  };
}