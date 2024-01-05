{
  description = "libations - a web app for viewing cocktail recipes";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    formatters.url = "github:Gerschtli/nix-formatter-pack";
    formatters.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , formatters
    , nixpkgs
    , ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];

      pkgsForSystem = system: (import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      });
    in
    {
      overlays.default = _final: prev:
        let
          inherit (prev) buildGoModule callPackage lib;
          inherit (self) lastModifiedDate;
        in
        {
          libations = callPackage ./nix/libations.nix { inherit buildGoModule lastModifiedDate lib; };
        };

      packages = forAllSystems (system: rec {
        inherit (pkgsForSystem system) libations;
        default = libations;
      });

      nixosModules = rec {
        default = libations;
        libations = import ./nix/module.nix;
      };

      devShells = forAllSystems (system:
        let
          pkgs = pkgsForSystem system;
        in
        {
          default = pkgs.mkShell {
            name = "libations";
            NIX_CONFIG = "experimental-features = nix-command flakes";
            nativeBuildInputs = with pkgs; [
              go_1_21
              go-tools
              gofumpt
              gopls
              zsh
            ];
            shellHook = "exec zsh";
          };
        });

      formatter = forAllSystems (system:
        formatters.lib.mkFormatter {
          pkgs = pkgsForSystem system;
          config.tools = {
            deadnix.enable = true;
            nixpkgs-fmt.enable = true;
            statix.enable = true;
          };
        }
      );
    };
}

