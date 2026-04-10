{ pkgs, ... }:

{
  programs.opencode.settings.plugin = [
    "@tarquinen/opencode-dcp@latest"
    "opencode-pty"
    "opencode-handoff"
  ];
}
