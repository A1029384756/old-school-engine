{
  description = "Rust Devshell and Builds";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, crane, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
        src = craneLib.cleanCargoSource ./.;
        nativeBuildInputs = with pkgs; [ 
          pkg-config
          rust-analyzer-unwrapped
          toolchain
          #put your env dependencies here
        ];
        buildInputs = with pkgs; [
          glslang
          libxkbcommon
          shaderc
          vulkan-loader
          vulkan-tools
          vulkan-validation-layers
          wayland
          #put your runtime and build dependencies here
        ];
        commonArgs = { inherit src buildInputs nativeBuildInputs; };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        bin = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });
      in
      with pkgs;
      {
        packages = {
          inherit bin;
          default = bin;
        };
        devShells.default = mkShell {
          inputsFrom = [ bin ];
          LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}";
          VK_LAYER_PATH = "${vulkan-validation-layers}/share/vulkan/explicit_layer.d";
        };
      }
    );
}
