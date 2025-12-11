{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{
      flake-parts,
      crane,
      fenix,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      perSystem =
        {
          lib,
          pkgs,
          system,
          ...
        }:
        let
          version = "1.7.1";
          src = pkgs.fetchFromGitHub {
            owner = "eclipse-zenoh";
            repo = "zenoh-plugin-ros2dds";
            rev = version;
            hash = "sha256-1NakS7pCL0Dn6WzXbcyahs/X7tTzaM2mmjR4Pv4VB8g=";
          };

          toolchain = fenix.packages.${system}.fromToolchainFile {
            file = src + "/rust-toolchain.toml";
            sha256 = "sha256-AJ6LX/Q/Er9kS15bn9iflkUwcgYqRQxiOIL2ToVAXaU=";
          };
          craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

          args = {
            inherit src;
            pname = "zenoh-bridge-ros2dds";
            strictDeps = true;

            nativeBuildInputs = with pkgs; [
              pkg-config
              clang
              cmake
            ];
            buildInputs =
              with pkgs;
              [
                openssl
                llvmPackages.libclang.lib
              ]
              ++ lib.optionals pkgs.stdenv.isDarwin [
                pkgs.libiconv
              ];

            preConfigure = ''
              export CMAKE_POLICY_VERSION_MINIMUM=3.5
            '';

            CYCLONEDDS_HOME = "${pkgs.cyclonedds}";
          };

          bin = craneLib.buildPackage (
            args
            // {
              cargoArtifacts = craneLib.buildDepsOnly args;
            }
          );
        in
        {
          packages.default = bin;
        };
    };
}
