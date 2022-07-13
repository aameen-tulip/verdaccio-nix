{ config
, lib
, pkgs
, ...
}: let

  cfg  = config.verdaccio;
  ucfg = cfg.utils;

  registryUrl = "http://${cfg.listenHost}:${toString cfg.listenPort}/";

  rewrite = ''
    #! ${pkgs.bash}/bin/bash
    set -eu
    PATH="''${PATH+$PATH:}${pkgs.jq}/bin"
    pdir="''${1%/package.json}"
    pjs="$pdir/package.json"
    pjsBackup="${ucfg.cacheDir}/$pjs"
    if ! test -r "$pjs"; then
      echo "Could not locate package.json for path $pdir" >&2
      exit 1;
    fi
    backupPjs() {
      mkdir -p "${ucfg.cacheDir}/$pdir"
      if ! test -r "$pjsBackup"; then
        cp -pr --reflink=auto -- "$pjs" "$pjsBackup"
      fi
    }
    writePublishCfg() {
      backupPjs
      jq -SM '.publishConfig.registry|="${registryUrl}"' "$pjsBackup" > "$pjs"
    }
  '';

  restore = ''
    #! ${pkgs.bash}/bin/bash
    set -eu
    PATH="''${PATH+$PATH:}${pkgs.findutils}/bin:${pkgs.coreutils}/bin"
    if ! test -d ${ucfg.cacheDir}; then
      exit 0;  # No cached package.json files exist. That was easy.
    fi
    pushd ${ucfg.cacheDir} > /dev/null
    for pjs in $( find . -type f -name package.json -print; ); do
      cp -pr --reflink=auto -- "$pjs" "/''${pjs#./}"
      echo "Restored: /''${pjs#./}"
      rm -f -- "$pjs"
      rmdir --ignore-fail-on-non-empty -p "''${pjs%/*}"
    done
  '';

  package = lib.mkIf cfg.wrapper.enable ( derivation {
    name = "verdaccio-wrapped";
    inherit (pkgs.stdenv) system;
    PATH="${pkgs.coreutils}/bin";
    inherit rewrite restore;
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

in {
  config = lib.mkIf ( cfg.enable && ucfg.enable ) {
    verdaccio.utils = { inherit package; };
  };
}
