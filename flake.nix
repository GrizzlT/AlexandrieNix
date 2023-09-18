{
  description = "An alternative crate registry, implemented in Rust.";

  inputs = {
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.11.0";
    flake-utils.follows = "cargo2nix/flake-utils";
    nixpkgs.follows = "rust-overlay/nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    cargo2nix.inputs.nixpkgs.follows = "nixpkgs";
    cargo2nix.inputs.rust-overlay.follows = "rust-overlay";

    alexandrie-src = {
      url = "github:Hirevo/alexandrie?rev=4813442d0bc4ff419725c1684ffff94960d2cce7";
      flake = false;
    };
  };

  outputs = inputs: with inputs;
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ cargo2nix.overlays.default ];
        };

        alexandriePatched = pkgs.rustBuilder.rustLib.makeOverride {
          name = "alexandrie";
          overrideAttrs = drv: {
            patches = drv.patches or [] ++ [ ./0001-Add-migrations-dir-to-alexandrie-crate-root.patch ];
          };
        };

        rustPkgs = database: frontend: pkgs.rustBuilder.makePackageSet {
          rustVersion = "1.68.0";
          packageFun = import ./Cargo.nix;
          rootFeatures = [ "alexandrie/${database}" "alexandrie/git2" ] ++ (pkgs.lib.optional frontend "alexandrie/frontend");
          workspaceSrc = alexandrie-src;
          packageOverrides = pkgs: pkgs.rustBuilder.overrides.all ++ [ alexandriePatched ];
        };
      in rec {
        packages = {
          alexandrie-postgres-frontend = ((rustPkgs "postgres" true).workspace.alexandrie {}).bin;
          alexandrie-postgres = ((rustPkgs "postgres" false).workspace.alexandrie {}).bin;

          default = packages.alexandrie-postgres-frontend;
        };
      }
    );
}
