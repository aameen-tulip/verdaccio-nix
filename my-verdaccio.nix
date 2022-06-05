{ nixpkgs            ? builtins.getFlake "nixpkgs"
, system             ? builtins.currentSystem
, pkgs               ? import nixpkgs.legacyPackages.${system}
, lib                ? nixpkgs.lib
, verdaccioNode      ? import ../../../tools/nix/pkgs/development/node-packages/verdaccio { inherit pkgs; }
, verdaccioUnwrapped ? verdaccioNode.verdaccio
, ak-nix             ? builtins.getFlake "github:aakropotkin/ak-nix/main"
, docgen             ? ak-nix.docgen system
, linkFarmFromDrvs   ? pkgs.linkFarmFromDrvs
}:
let
  inherit (docgen) docbookToManN docbookToTexi docbookToHtml docbookToOrg;
  inherit (docgen) texiToInfo;

  userModule = {
    config._module.args = { inherit pkgs lib verdaccioUnwrapped; };
    config.verdaccio = {
      enable = true;
      wrapper.enable = true;
      settings.web.title = "Boy, Howdy!";
    };
    imports = [./verdaccio-cfg.nix];
  };
  ev = lib.evalModules { modules = [userModule]; };
  docs = docgen.generateDocsForOptions ev.options;
in {
  inherit (ev.config.verdaccio) configFile;
  inherit (ev.config.verdaccio.wrapper) package;
} // docs
