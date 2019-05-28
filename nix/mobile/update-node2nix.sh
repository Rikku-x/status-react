#!/usr/bin/env bash

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

node2nix --nodejs-10 --development --bypass-cache \
         -i $SCRIPTPATH/../../mobile_files/package.json \
         -o $SCRIPTPATH/node2nix/node-packages.nix \
         -c $SCRIPTPATH/node2nix/default.nix \
         -e $SCRIPTPATH/node2nix/node-env.nix