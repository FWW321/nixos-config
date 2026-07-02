{ pkgs, inputs, lib, ... }:

{
  mcp = import ./mcp.nix { inherit pkgs; };
  providers = import ./providers.nix;
  skills = import ./skills.nix { inherit pkgs inputs lib; };
  plugins = import ./plugins.nix { inherit pkgs inputs; };
  rules = ./rules.md;
}
