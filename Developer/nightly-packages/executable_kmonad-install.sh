#!/usr/bin/env bash

# dext is installed by karabiner-elements (brew install --cask karabiner-elements)
# stack is installed with brew (brew install haskell-stack)
#
# Docs: https://github.com/kmonad/kmonad/blob/master/doc/installation.md#installing-kmonad
cd ./kmonad || exit
stack build --flag kmonad:dext --extra-include-dirs=c_src/mac/Karabiner-DriverKit-VirtualHIDDevice/include/pqrs/karabiner/driverkit:c_src/mac/Karabiner-DriverKit-VirtualHIDDevice/src/Client/vendor/include
