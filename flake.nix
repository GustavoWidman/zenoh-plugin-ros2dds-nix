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

          releaseArch =
            {
              "x86_64-linux" = "x86_64-unknown-linux-gnu";
              "aarch64-linux" = "aarch64-unknown-linux-gnu";
              "x86_64-darwin" = "x86_64-apple-darwin";
              "aarch64-darwin" = "aarch64-apple-darwin";
            }
            .${system} or (throw "Unsupported system: ${system}");

          binaryHash =
            {
              "x86_64-linux" = "sha256-Q47vcJKIGd90nu2Kk6m/W/pwVlilppgVn+A4w9DnB9Q=";
              "aarch64-linux" = "sha256-aykNH1Bxi0xEOiwM53Wa88KvBXKxnv2pZIHbmRTlVYw=";
              "x86_64-darwin" = "sha256-Amsdwl3Kw3w2ZQMjk4mFkp1BsyriHnWWk+GsaQlo6/4=";
              "aarch64-darwin" = "sha256-IRvBQrHojVNKXLKgPyUPXSaFpF5G2BtudNqcmcZQUs4=";
            }
            .${system};

          zenoh-bridge-ros2dds-bin = pkgs.stdenv.mkDerivation {
            pname = "zenoh-bridge-ros2dds-bin";
            inherit version;

            src = pkgs.fetchzip {
              url = "https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/${version}/zenoh-plugin-ros2dds-${version}-${releaseArch}-standalone.zip";
              hash = binaryHash;
              stripRoot = false;
            };

            nativeBuildInputs = [ pkgs.unzip ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              cp zenoh-bridge-ros2dds $out/bin/
              chmod +x $out/bin/zenoh-bridge-ros2dds

              runHook postInstall
            '';

            meta = {
              description = "Zenoh bridge for ROS2/DDS (pre-built binary)";
              homepage = "https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds";
              platforms = import systems;
            };
          };

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
            inherit src version;
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

            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

            preConfigure = ''
              export CMAKE_POLICY_VERSION_MINIMUM=3.5
            '';

            CYCLONEDDS_HOME = "${pkgs.cyclonedds}";
          };

          zenoh-bridge-ros2dds = craneLib.buildPackage (
            args
            // {
              cargoArtifacts = craneLib.buildDepsOnly args;
            }
          );
        in
        {
          packages = {
            default = zenoh-bridge-ros2dds-bin;
            zenoh-bridge-ros2dds = zenoh-bridge-ros2dds;
            zenoh-bridge-ros2dds-bin = zenoh-bridge-ros2dds-bin;
          };
        };
    };
}
