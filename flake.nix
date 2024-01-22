{
  description = "OVHcloud dedicated server";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "";
    };
  };

  outputs = { self, nixpkgs, disko, agenix, ... }: let
    secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");
  in
  {
    nixosConfigurations.ovhcloud = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit secrets; };
      modules = [
        ./configuration.nix
        disko.nixosModules.disko
        agenix.nixosModules.default
        {
          environment.systemPackages = [ agenix.packages.x86_64-linux.default ];
        }
      ];
    };
  };
}
