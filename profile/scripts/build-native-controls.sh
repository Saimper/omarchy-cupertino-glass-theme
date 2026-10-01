#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
expected=efb50993780079460b0cbed1363e2166a2de1d9f
if ! Hyprland --version | head -1 | grep -F "$expected" >/dev/null; then
    printf '%s\n' 'This plugin source is pinned to Hyprland 0.56.2. Revalidate it before building for another version.' >&2
    exit 1
fi
mkdir -p "$root/plugins-native/build"
make -C "$root/plugins-native/vendor/hyprbars" CXX=g++ EXTRA_FLAGS=-fno-gnu-unique
cp "$root/plugins-native/vendor/hyprbars/hyprbars.so" "$root/plugins-native/build/hyprbars.so.new"
mv "$root/plugins-native/build/hyprbars.so.new" "$root/plugins-native/build/hyprbars.so"
g++ -O2 -shared -fPIC -fno-gnu-unique -std=c++23 \
    $(pkg-config --cflags hyprland libinput libudev wayland-server xkbcommon lua) \
    "$root/plugins-native/cupertino-bridge.cpp" -o "$root/plugins-native/build/cupertino-bridge.so.new"
mv "$root/plugins-native/build/cupertino-bridge.so.new" "$root/plugins-native/build/cupertino-bridge.so"
