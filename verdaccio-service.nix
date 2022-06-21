{ pkgs            ? ( builtins.getFlake "nixpkgs" ).legacyPackages.${builtins.currentSystem}
, stdenv          ? pkgs.stdenvNoCC
, verdaccio       ? ( builtins.getFlake "github:tulip/tulip/aameen.nix.verdaccio?dir=tools/nix/pkgs/development/node_modules/verdaccio" )
, nodejs          ? pkgs.nodejs-14_x
, verdaccioConfig ? FIXME
}:
let
in stdenv.mkDerivation {
  name = "verdaccio-daemon";

}
