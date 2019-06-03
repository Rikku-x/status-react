{ config, stdenv, pkgs, callPackage, fetchurl, target-os,
  gradle, status-go, composeXcodeWrapper, nodejs }:

with stdenv;

let
  platform = callPackage ../platform.nix { inherit target-os; };
  xcodewrapperArgs = {
    version = "10.1";
  };
  xcodeWrapper = composeXcodeWrapper xcodewrapperArgs;
  androidPlatform = callPackage ./android { inherit config pkgs nodejs gradle status-go nodeProjectName developmentNodePackages; projectNodePackage = projectNodePackage'; };
  selectedSources =
    [ status-go ] ++
    lib.optional platform.targetAndroid androidPlatform;

  developmentNodePackages = import ./node2nix/development { inherit pkgs nodejs; };
  projectNodePackage = import ./node2nix/StatusIm { inherit pkgs nodejs; };
  projectNodePackage' = projectNodePackage.package.override(oldAttrs: (realmOverrides oldAttrs));
  nodeProjectName = "StatusIm";
  realmOverrides = import ./realm-overrides { inherit nodeProjectName fetchurl; };

in
  {
    inherit (androidPlatform) androidComposition;
    inherit xcodewrapperArgs;

    buildInputs =
      status-go.buildInputs ++
      lib.catAttrs "buildInputs" selectedSources ++
      lib.optional (platform.targetIOS && isDarwin) xcodeWrapper;
    shellHook = lib.concatStrings (lib.catAttrs "shellHook" selectedSources);
  }
