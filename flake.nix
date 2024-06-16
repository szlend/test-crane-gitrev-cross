{
  description = "Cross compiling a rust program using rust-overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { nixpkgs, crane, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (localSystem:
      let
        crossSystem = "aarch64-linux";

        pkgs = import nixpkgs {
          inherit crossSystem localSystem;
          overlays = [ (import rust-overlay) ];
        };

        rustToolchain = pkgs.pkgsBuildHost.rust-bin.stable.latest.default.override {
          targets = [ "aarch64-unknown-linux-gnu" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        crateExpression =
          { openssl
          , libiconv
          , lib
          , pkg-config
          , qemu
          , stdenv
          }:
          craneLib.buildPackage {
            src = craneLib.cleanCargoSource ./.;
            strictDeps = true;

            nativeBuildInputs = [
              pkg-config
              stdenv.cc
            ] ++ lib.optionals stdenv.buildPlatform.isDarwin [
              libiconv
            ];

            buildInputs = [
              openssl
            ];

            CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
            CARGO_BUILD_TARGET = "aarch64-unknown-linux-gnu";

            HOST_CC = "${stdenv.cc.nativePrefix}cc";
            TARGET_CC = "${stdenv.cc.targetPrefix}cc";
          };

        my-crate = pkgs.callPackage crateExpression { };
      in
      {
        packages.default = my-crate;
      });
}
