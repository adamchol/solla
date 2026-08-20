{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs =
            with pkgs;
            [
              nixfmt-rfc-style
              swift
              swiftpm
              swift-format
              swiftPackages.Dispatch
              swiftPackages.Foundation
              swiftPackages.XCTest
            ]
            ++ lib.optionals stdenv.isDarwin [
              xcodegen
            ];

          # swiftpm-built binaries (including the compiled Package.swift
          # manifest) locate the corelibs at runtime via LD_LIBRARY_PATH.
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.swiftPackages.Dispatch
            pkgs.swiftPackages.Foundation
            pkgs.swiftPackages.XCTest
          ];
        };
      }
    );
}
