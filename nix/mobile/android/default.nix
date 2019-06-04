{ config, stdenv, stdenvNoCC, callPackage,
  pkgs, androidenv, fetchurl, openjdk, nodejs, bash, gradle, perl, zlib,
  status-go, nodeProjectName, projectNodePackage, developmentNodePackages }:

with stdenv;

let
  androidComposition = androidenv.composeAndroidPackages {
    toolsVersion = "26.1.1";
    platformToolsVersion = "28.0.2";
    buildToolsVersions = [ "28.0.3" ];
    includeEmulator = false;
    platformVersions = [ "28" ];
    includeSources = false;
    includeDocs = false;
    includeSystemImages = false;
    systemImageTypes = [ "default" ];
    abiVersions = [ "armeabi-v7a" ];
    lldbVersions = [ "2.0.2558144" ];
    cmakeVersions = [ "3.6.4111459" ];
    includeNDK = true;
    ndkVersion = "19.2.5345600";
    useGoogleAPIs = false;
    useGoogleTVAddOns = false;
    includeExtras = [ "extras;android;m2repository" "extras;google;m2repository" ];
  };
  licensedAndroidEnv = callPackage ./licensed-android-sdk.nix { inherit androidComposition; };
  src =
    let
      src = ./../../..; # Import the root /android and /mobile_files folders clean of any build artifacts

      mkFilter = { dirsToInclude, dirsToExclude, filesToInclude, root }: path: type:
        let
          inherit (lib) elem elemAt splitString;
          baseName = baseNameOf (toString path);
          subpath = elemAt (splitString "${toString root}/" path) 1;
          spdir = elemAt (splitString "/" subpath) 0;

        in lib.cleanSourceFilter path type && ((type != "directory" && (elem spdir filesToInclude)) || ((elem spdir dirsToInclude) && ! (
          # Filter out version control software files/directories
          (type == "directory" && (elem baseName dirsToExclude)) ||
          # Filter out editor backup / swap files.
          lib.hasSuffix "~" baseName ||
          builtins.match "^\\.sw[a-z]$" baseName != null ||
          builtins.match "^\\..*\\.sw[a-z]$" baseName != null ||

          # Filter out generated files.
          lib.hasSuffix ".o" baseName ||
          lib.hasSuffix ".so" baseName ||
          # Filter out nix-build result symlinks
          (type == "symlink" && lib.hasPrefix "result" baseName)
        )));
      in builtins.filterSource
          (mkFilter {
            dirsToInclude = [ "android" "mobile_files" "packager" "resources" "scripts" ];
            dirsToExclude = [ ".git" ".svn" "CVS" ".hg" ".gradle" "build" "intermediates" "libs" "obj" ];
            filesToInclude = [ ".env" ];
            root = src;
          })
      src;

  gradleAndNodeDeps = callPackage ./gradle-and-npm-deps.nix { inherit stdenvNoCC gradle bash perl zlib src nodeProjectName androidEnvShellHook projectNodePackage developmentNodePackages status-go; };

  androidEnvShellHook = ''
    export JAVA_HOME="${openjdk}"
    export ANDROID_HOME="${licensedAndroidEnv}"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export ANDROID_NDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk/ndk-bundle"
    export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
    export ANDROID_NDK="$ANDROID_NDK_ROOT"
    export PATH="$ANDROID_HOME/bin:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools:$PATH"
  '';

in
  {
    inherit androidComposition;

    buildInputs = [ gradleAndNodeDeps.deps openjdk gradle ];
    shellHook =
      androidEnvShellHook + 
      gradleAndNodeDeps.shellHook + ''
      $STATUS_REACT_HOME/scripts/generate-keystore.sh
      nodeModulesDir="$STATUS_REACT_HOME/node_modules"
    '' +
    # Check if we need to copy node_modules (e.g. in case it has been modified after last copy)
    ''
      needCopyModules=1
      if [ -d $nodeModulesDir ]; then
        if [ -f $nodeModulesDir/.copied ]; then
          echo "Checking for modifications in node_modules..."
          modifiedFiles=$(find $nodeModulesDir -writable -type f -newer $nodeModulesDir/.copied)
          if [ $? -eq 0 ] && [ -z "$modifiedFiles" ]; then
            needCopyModules=0
            echo "No modifications detected."
          fi
        fi
        if [ $needCopyModules -eq 1 ]; then
          chmod u+w -R $nodeModulesDir
          rm -rf $nodeModulesDir || exit
        fi
      fi
      if [ ! -d $nodeModulesDir ]; then
        echo "Copying node_modules from Nix store (${gradleAndNodeDeps.deps}/node_modules)..."
        time cp -HR --preserve=all ${gradleAndNodeDeps.deps}/node_modules . && \
          chmod u+w $nodeModulesDir && \
          touch $nodeModulesDir/.copied && \
          chmod u-w $nodeModulesDir
        echo "Done"
      fi
    '' +
    # Fix permissions in certain directories so that React Native doesn't have a fit
    ''
      rndir="$nodeModulesDir/react-native"
      rnabuild="$rndir/ReactAndroid/build"
      chmod u+w -R $rnabuild
      chmod 744 $rndir/scripts/.packager.env \
                $rndir/ReactAndroid/build.gradle \
                $rnabuild/outputs/logs/manifest-merger-release-report.txt \
                $rnabuild/intermediates/library_manifest/release/AndroidManifest.xml \
                $rnabuild/intermediates/aapt_friendly_merged_manifests/release/processReleaseManifest/aapt/{AndroidManifest.xml,output.json} \
                $rnabuild/intermediates/incremental/packageReleaseResources/{merger.xml,compile-file-map.properties} \
                $rnabuild/intermediates/merged_manifests/release/output.json \
                $rnabuild/intermediates/symbols/release/R.txt \
                $rnabuild/intermediates/res/symbol-table-with-package/release/package-aware-r.txt

      # If these directories are missing, there will be an error later on when building with this node_modules directory:
      # What went wrong:
      # Failed to create parent directory 'node_modules/react-native-touch-id/android/build' when creating directory 'node_modules/react-native-touch-id/android/build/intermediates/check_manifest_result/release/checkReleaseManifest/out'
      chmod u+w $nodeModulesDir
      for p in $nodeModulesDir/react-native-{background-timer,camera,config,dialogs,firebase,fs,http-bridge,image-resizer,image-crop-picker,keychain,languages,mail,securerandom,shake,splash-screen,status-keycard,svg,touch-id,webview,webview-bridge} \
               $nodeModulesDir/realm
      do
        chmod -R u+w $p
        mkdir -p $p/android/build
      done
      chmod u-w $nodeModulesDir
      [ -n "$JENKINS_URL" ] && chmod -r u+w $nodeModulesDir # HACK: Allow CI to clean node_modules, will need to rethink this later
      unset nodeModulesDir
    '';
  }
