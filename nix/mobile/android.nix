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

      # Set up symlinks to mobile enviroment in project root 
      for f in package.json .babelrc VERSION metro.config.js
      do
        rm -f $f && ln -s ./mobile_files/$f
      done
    '';
    patchPhase = ''
      # Patch maven and google central repositories with our own local directories. This prevents the builder from downloading Maven artifacts
      ${lib.concatStrings (lib.mapAttrsToList (projectName: deriv:
        let targetGradleFile = "${lib.optionalString (projectName != nodeProjectName) "node_modules/${projectName}/"}android/build.gradle";
        in ''
      grep 'google()' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "google()" "maven { url \"${deriv}\" }"
      grep 'jcenter()' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "jcenter()" "maven { url \"${deriv}\" }"
      grep 'https://maven.google.com' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "https://maven.google.com" "${deriv}"
      grep '\$rootDir/../node_modules/react-native/android' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "\$rootDir/../node_modules/react-native/android" "${mavenLocalRepos.react-native-android}"
        '') (lib.filterAttrs (name: value: name != "react-native-android") mavenLocalRepos))}

      # Patch prepareJSC so that it doesn't try to download from registry
      substituteInPlace node_modules/react-native/ReactAndroid/build.gradle \
        --replace "prepareJSC(dependsOn: downloadJSC)" "prepareJSC(dependsOn: createNativeDepsDirectories)" \
        --replace "def jscTar = tarTree(downloadJSC.dest)" "def jscTar = tarTree(new File(\"../../../deps/${jsc-filename}.tar.gz\"))"

      # The .git directory does not exist, so no point in calling git in the script
      substituteInPlace scripts/build_no.sh \
        --replace "(git rev-parse --show-toplevel)" "STATUS_REACT_HOME"

      # HACK: Run what would get executed in the `prepare` script (though index.js.flow will be missing)
      # Ideally we'd invoke `npm run prepare` instead, but that requires quite a few additional dependencies
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
      export GRADLE_USER_HOME="$STATUS_REACT_HOME/.gradle"
      ( cd android
        LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${stdenv.lib.makeLibraryPath [ zlib ]} \
          gradle --no-daemon react-native-android:installArchives
      )

      # If these directories are missing, there will be an error later on when building with this node_modules directory:
      # What went wrong:
      # Failed to create parent directory 'node_modules/react-native-touch-id/android/build' when creating directory '/home/pedro/src/github.com/status-im/status-react/node_modules/react-native-touch-id/android/build/intermediates/check_manifest_result/release/checkReleaseManifest/out'
      for p in react-native-{background-timer,camera,config,dialogs,firebase,fs,http-bridge,image-resizer,image-crop-picker,keychain,languages,mail,securerandom,shake,splash-screen,status-keycard,svg,touch-id,webview,webview-bridge} \
               realm
      do
        chmod -R u+w node_modules/$p
        mkdir -p node_modules/$p/android/build
      done
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

    # The ELF types are incompatible with the host platform, so let's not even try
    dontPatchELF = true;
    noAuditTmpdir = true;

    # Take whole sources into consideration when calculating sha
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
  };

in
  {
    inherit androidComposition;

    buildInputs = [ deps openjdk gradle ];
    shellHook =
      androidEnvShellHook + ''
      $STATUS_REACT_HOME/scripts/generate-keystore.sh
    '' +
    # Check if we need to copy node_modules (e.g. in case it has been modified after last copy)
    ''
      needCopyModules=1
      if [ -d ./node_modules ]; then
        if [ -f ./node_modules/.copied ]; then
          echo "Checking for modifications in node_modules..."
          modifiedFiles=$(find ./node_modules -writable -type f -newer ./node_modules/.copied)
          if [ $? -eq 0 ] && [ -z "$modifiedFiles" ]; then
            needCopyModules=0
            echo "No modifications detected."
          fi
        fi
        if [ $needCopyModules -eq 1 ]; then
          chmod u+w -R ./node_modules
          rm -rf ./node_modules || exit
        fi
      fi
      if [ ! -d ./node_modules ]; then
        echo "Copying node_modules from Nix store (${deps}/node_modules)..."
        time cp -HR --preserve=all ${deps}/node_modules . && \
          chmod u+w ./node_modules && \
          touch ./node_modules/.copied && \
          chmod u-w ./node_modules
        echo "Done"
      fi
    '' +
    # Fix permissions in certain directories so that React Native doesn't have a fit
    ''
      rndir='node_modules/react-native'
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
    '' +
    # Lastly, add some configuration
    ''
      export PATH="$PATH:${deps}/node_modules/.bin"
      export GRADLE_USER_HOME="$STATUS_REACT_HOME/.gradle" # Assign our own Gradle cache location, so that other non-Nix projects don't pollute our environment
    '';
  }
