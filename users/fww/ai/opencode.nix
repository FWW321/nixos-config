{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "opencode" ''
      OPENCODE_CONFIG=/run/secrets/rendered/opencode/opencode.json exec ${pkgs.bun}/bin/bunx opencode-ai "$@"
    '')
  ];
}
