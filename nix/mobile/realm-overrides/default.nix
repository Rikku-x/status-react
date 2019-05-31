{ fetchurl,
  nodeProjectName }:

let
  realm-core-version = "5.12.1";
  realm-version = "2.28.0";
  realm-patched-name = "realm-${realm-version}";
  # We download ${realm-core-src} to ${realm-dest-dir} in order to avoid having realm try to download these files on its own (which is disallowed by Nix)
  realm-core-src = fetchurl (
    if builtins.currentSystem == "x86_64-darwin" then {
      url = "https://static.realm.io/downloads/core/realm-core-Release-v${realm-core-version}-Darwin-devel.tar.gz";
      sha256 = "05ji1zyskwjj8p6i01kcg7h1cxdjj62fcsp6haf2f65qshp6r44d";
    } else {
      url = "https://static.realm.io/downloads/core/realm-core-Release-v${realm-core-version}-Linux-devel.tar.gz";
      sha256 = "02pvi28qnvzdv7ghqzf79bxn8id9s7mpp3g2ambxg8jrcrkqfvr1";
    }
  );
  realm-dest-dir = if builtins.currentSystem == "x86_64-darwin" then
    "$out/lib/node_modules/${nodeProjectName}/node_modules/realm/compiled/node-v64_darwin_x64/realm.node" else
    "$out/lib/node_modules/${nodeProjectName}/node_modules/realm/compiled/node-v64_linux_x64/realm.node";
  # TODO: I believe that mobile builds are actually expecting a v57 node executable, not v64
  # realm-dest-dir = if builtins.currentSystem == "x86_64-darwin" then
  #   "$out/lib/node_modules/${nodeProjectName}/node_modules/realm/compiled/node-v57_darwin_x64/realm.node" else
  #   "$out/lib/node_modules/${nodeProjectName}/node_modules/realm/compiled/node-v57_linux_x64/realm.node";

in oldAttrs: {
  reconstructLock = true;
  preRebuild = ''
    # Do not attempt to do any http calls!
    substituteInPlace $out/lib/node_modules/${nodeProjectName}/node_modules/realm/scripts/download-realm.js \
      --replace "!shouldSkipAcquire(realmDir, requirements, options.force)" "false"
    mkdir -p ${realm-dest-dir}
    tar -xzf ${realm-core-src} -C ${realm-dest-dir}
  '';
}