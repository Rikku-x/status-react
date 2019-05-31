{ config, stdenv, callPackage,
  pkgs, androidenv, fetchurl, openjdk, nodejs, bash, git, gradle, perl, zlib,
  status-go }:

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
      src = ./../..; # Import the root /android and /mobile_files folders clean of any build artifacts

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
            dirsToExclude = [ ".git" ".svn" "CVS" ".hg" ".gradle" "build" "intermediates" ];
            filesToInclude = [ ".env" ];
            root = src;
          })
      src;
  developmentNodePackages = import ./node2nix/development { inherit pkgs nodejs; };
  projectNodePackage = import ./node2nix/StatusIm { inherit pkgs nodejs; };
  nodePackage = projectNodePackage.package.override(oldAttrs: (realmOverrides oldAttrs));
  nodeProjectName = "StatusIm";

  realmOverrides = import ./realm-overrides { inherit nodeProjectName fetchurl; };

  mavenLocalRepos = import ./gradle/maven-repo.nix { inherit stdenv callPackage; };

  jsc-filename = "jsc-android-236355.1.1";
  react-native-deps = callPackage ./gradle/reactnative-android-native-deps.nix { inherit jsc-filename; };

  androidEnvShellHook = ''
    export JAVA_HOME="${openjdk}"
    export ANDROID_HOME="${licensedAndroidEnv}"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export ANDROID_NDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk/ndk-bundle"
    export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
    export ANDROID_NDK="$ANDROID_NDK_ROOT"
    export PATH="$ANDROID_HOME/bin:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools:$PATH"

    # This avoids RN trying to download dependencies. Maybe we need to wrap this in a special RN environment derivation
    export REACT_NATIVE_DEPENDENCIES="${react-native-deps}/deps"

    for f in package.json .babelrc VERSION metro.config.js
    do
      rm -f $f && ln -s ./mobile_files/$f
    done
  '';

  # fake build to pre-download deps into fixed-output derivation
  deps = stdenv.mkDerivation {
    name = "gradle-install-android-archives";
    inherit src;
    buildInputs = [ gradle bash git perl zlib ] ++ (builtins.attrValues developmentNodePackages);
    unpackPhase = ''
      cp -a $src/* .
      chmod -R u+w android

      # Copy fresh RN maven dependencies and make them writable, otherwise Gradle copy fails
      cp -a ${react-native-deps}/deps ./deps
      chmod -R u+w ./deps

      # Copy fresh node_modules and adjust permissions
      rm -rf ./node_modules
      mkdir -p ./node_modules
      cp -a ${nodePackage}/lib/node_modules/${nodeProjectName}/node_modules .
      chmod u+w -R ./node_modules/react-native

      for f in package.json .babelrc VERSION metro.config.js
      do
        rm -f $f && ln -s ./mobile_files/$f
      done
    '';
    patchPhase = ''
      # Patch maven and google central repositories with our own local directories. This prevents the builder from downloading Maven artifacts
      ${lib.concatStrings (lib.mapAttrsToList (projectName: deriv: ''
      substituteInPlace ${lib.optionalString (projectName != nodeProjectName) "node_modules/${projectName}/"}android/build.gradle \
        --replace "google()" "maven { url \"${deriv}\" }" \
        --replace "jcenter()" "maven { url \"${deriv}\" }" \
        --replace "https://maven.google.com" "${deriv}" \
        --replace "\$rootDir/../node_modules/react-native/android" "${mavenLocalRepos.react-native-android}"
      '') (lib.filterAttrs (name: value: name != "react-native-android") mavenLocalRepos))}

      # Patch prepareJSC so that it doesn't try to download from registry
      substituteInPlace node_modules/react-native/ReactAndroid/build.gradle \
        --replace "prepareJSC(dependsOn: downloadJSC)" "prepareJSC(dependsOn: createNativeDepsDirectories)" \
        --replace "def jscTar = tarTree(downloadJSC.dest)" "def jscTar = tarTree(new File(\"../../../deps/${jsc-filename}.tar.gz\"))"

      # The .git directory does not exist, so no point in calling git in the script
      substituteInPlace scripts/build_no.sh \
        --replace "(git rev-parse --show-toplevel)" "STATUS_REACT_HOME"

      # TODO: figure out why we get `path may not be null or empty string. path='null'`
      substituteInPlace node_modules/react-native/ReactAndroid/release.gradle \
        --replace "classpath += files(project.getConfigurations().getByName(\"compile\").asList())" ""

      # HACK: Run what would get executed in the `prepare` script (though index.js.flow will be missing)
      (cd ./node_modules/react-native-firebase && \
       chmod u+w -R . && \
       mkdir ./dist && \
       genversion ./src/version.js && \
       cp -R ./src/* ./dist && \
       chmod u-w -R .) || exit
    '';
    buildPhase = 
      androidEnvShellHook +
      status-go.shellHook + ''
      export REACT_NATIVE_DEPENDENCIES="$(pwd)/deps" # Use local writable deps, otherwise (for some unknown reason) gradle will fail copying directly from the nix store
      export GRADLE_USER_HOME=$(mktemp -d)
      ( cd android
        LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${stdenv.lib.makeLibraryPath [ zlib ]} \
          gradle --no-daemon react-native-android:installArchives
      )
    '';
    installPhase = ''
      rm -rf $out
      mkdir -p $out
      cp -R node_modules/ $out

      # Patch prepareJSC so that it doesn't subsequently try to build NDK libs
      substituteInPlace $out/node_modules/react-native/ReactAndroid/build.gradle \
        --replace "packageReactNdkLibs(dependsOn: buildReactNdkLib, " "packageReactNdkLibs(" \
        --replace "../../../deps/${jsc-filename}.tar.gz" "${react-native-deps}/deps/${jsc-filename}.tar.gz" 
    '';
    dontPatchELF = true; # The ELF types are incompatible with the host platform, so let's not even try
    noAuditTmpdir = true;
    outputHashAlgo = "sha256";
    outputHashMode = "recursive"; # Take whole sources into consideration when calculating sha
  };

in
  {
    inherit androidComposition;

    buildInputs = [ deps openjdk gradle ];
    shellHook =
      androidEnvShellHook + ''
      $STATUS_REACT_HOME/scripts/generate-keystore.sh

      if [ -d ./node_modules ]; then
        chmod u+w -R ./node_modules
        rm -rf ./node_modules || exit
      fi
      echo "Copying node_modules from Nix store (${deps}/node_modules)..."
      # mkdir -p node_modules # node_modules/react-native/ReactAndroid
      time cp -HR --preserve=all ${deps}/node_modules .
      echo "Done"

      rndir='node_modules/react-native'
      rnabuild="$rndir/ReactAndroid/build"
      chmod 744 $rndir/scripts/.packager.env \
                $rndir/ReactAndroid/build.gradle \
                $rnabuild/outputs/logs/manifest-merger-release-report.txt \
                $rnabuild/intermediates/library_manifest/release/AndroidManifest.xml \
                $rnabuild/intermediates/aapt_friendly_merged_manifests/release/processReleaseManifest/aapt/AndroidManifest.xml \
                $rnabuild/intermediates/aapt_friendly_merged_manifests/release/processReleaseManifest/aapt/output.json \
                $rnabuild/intermediates/incremental/packageReleaseResources/compile-file-map.properties \
                $rnabuild/intermediates/incremental/packageReleaseResources/merger.xml \
                $rnabuild/intermediates/merged_manifests/release/output.json \
                $rnabuild/intermediates/symbols/release/R.txt \
                $rnabuild/intermediates/res/symbol-table-with-package/release/package-aware-r.txt
      chmod u+w -R $rnabuild

      # What went wrong:
      # Failed to create parent directory '/home/pedro/src/github.com/status-im/status-react/node_modules/react-native-touch-id/android/build' when creating directory '/home/pedro/src/github.com/status-im/status-react/node_modules/react-native-touch-id/android/build/intermediates/check_manifest_result/release/checkReleaseManifest/out'
      chmod u+w node_modules
      for p in react-native-background-timer \
               react-native-camera \
               react-native-config \
               react-native-dialogs \
               react-native-firebase \
               react-native-fs \
               react-native-http-bridge \
               react-native-image-resizer \
               react-native-image-crop-picker \
               react-native-keychain \
               react-native-languages \
               react-native-mail \
               react-native-securerandom \
               react-native-shake \
               react-native-splash-screen \
               react-native-status-keycard \
               react-native-svg \
               react-native-touch-id \
               react-native-webview \
               react-native-webview-bridge \
               realm
      do
        chmod -R u+w node_modules/$p
        mkdir -p node_modules/$p/android/build
      done
      chmod u-w node_modules

      export PATH="$PATH:${deps}/node_modules/.bin"
    '';
  }
