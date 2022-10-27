{
  description = "# Zephyr™ Mechanical Keyboard (ZMK) Firmware";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell-flake.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, flake-utils, devshell-flake }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        name = "zmk-config";
        overlays = [  devshell-flake.overlay ];
        pkgs = import nixpkgs { inherit system overlays; };
      in rec {

        # `nix develop`
        devShell = with pkgs; let
        in
          mkShell {

            buildInputs = with pkgs; [
              # dev
              cmake
              ccache
              ninja
              dtc
              dfu-util
              gcc-arm-embedded
              python38
              python38Packages.west
              python38Packages.pip
              python38Packages.pyelftools
              # ci
              act # run github actions locally
              # utils
              usbutils
            ];

            shellHook = ''
              export ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
              export GNUARMEMB_TOOLCHAIN_PATH=${pkgs.gcc-arm-embedded}
            '';
          };
      });
}
