{ stdenv, lib, callPackage,
  gradle, bash, perl, status-go, zlib,
  src, nodeProjectName, projectNodePackage, androidEnvShellHook, developmentNodePackages }:

let
  mavenLocalRepos = import ./gradle/maven-repo.nix { inherit stdenv callPackage; };

  jsc-filename = "jsc-android-236355.1.1";
  react-native-deps = callPackage ./gradle/reactnative-android-native-deps.nix { inherit jsc-filename; };

  # fake build to pre-download deps into fixed-output derivation
  deps = stdenv.mkDerivation {
    name = "gradle-install-android-archives-and-patch-npm-modules";
    inherit src;
    buildInputs = [ gradle bash perl zlib ] ++ (builtins.attrValues developmentNodePackages);
    unpackPhase = ''
      runHook preUnpack

      mkdir src
      cp -a $src/. ./src
      chmod u+w ./src

      chmod -R u+w ./src/android

      # Copy fresh RN maven dependencies and make them writable, otherwise Gradle copy fails
      cp -a ${react-native-deps}/deps ./deps
      chmod -R u+w ./deps

      pushd ./src

      # Copy fresh node_modules and adjust permissions
      rm -rf ./node_modules
      mkdir -p ./node_modules
      cp -a ${projectNodePackage}/lib/node_modules/${nodeProjectName}/node_modules .
      chmod u+w -R ./node_modules/react-native

      # Set up symlinks to mobile enviroment in project root 
      for f in package.json .babelrc VERSION metro.config.js
      do
        rm -f $f && ln -s ./mobile_files/$f
      done

      sourceRoot=$(pwd)
      popd

      runHook postUnpack
    '';
    patchPhase = ''
      # Patch maven and google central repositories with our own local directories. This prevents the builder from downloading Maven artifacts
      ${lib.concatStrings (lib.mapAttrsToList (projectName: deriv:
        let targetGradleFile = if projectName == nodeProjectName then "android/build.gradle" else "node_modules/${projectName}/android/build.gradle";
        in ''
      grep 'google()' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "google()" "maven { url \"${deriv}\" }"
      grep 'jcenter()' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "jcenter()" "maven { url \"${deriv}\" }"
      grep 'https://maven.google.com' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "https://maven.google.com" "${deriv}"
      grep '\$rootDir/../node_modules/react-native/android' ${targetGradleFile} > /dev/null && substituteInPlace ${targetGradleFile} --replace "\$rootDir/../node_modules/react-native/android" "${mavenLocalRepos.react-native-android}"
        '') (lib.filterAttrs (name: value: name != "react-native-android") mavenLocalRepos))}

      # Patch prepareJSC so that it doesn't try to download from registry
      substituteInPlace node_modules/react-native/ReactAndroid/build.gradle \
        --replace "prepareJSC(dependsOn: downloadJSC)" "prepareJSC(dependsOn: createNativeDepsDirectories)" \
        --replace "def jscTar = tarTree(downloadJSC.dest)" "def jscTar = tarTree(new File(\"../../../../deps/${jsc-filename}.tar.gz\"))"

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
        LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib.makeLibraryPath [ zlib ]} \
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

    # The ELF types are incompatible with the host platform, so let's not even try
    dontPatchELF = true;
    noAuditTmpdir = true;

    # Take whole sources into consideration when calculating sha
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
  };

in {
  inherit deps;

  shellHook = ''
    # This avoids RN trying to download dependencies. Maybe we need to wrap this in a special RN environment derivation
    export REACT_NATIVE_DEPENDENCIES="${react-native-deps}/deps"

    for f in package.json .babelrc VERSION metro.config.js
    do
      rm -f $f && ln -s ./mobile_files/$f
    done

    export PATH="$PATH:${deps}/node_modules/.bin"
    export GRADLE_USER_HOME="$STATUS_REACT_HOME/.gradle" # Assign our own Gradle cache location, so that other non-Nix projects don't pollute our environment
  '';
}
