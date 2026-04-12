{ pkgs, ... }:

let
  rtkPlugin = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/rtk-ai/rtk/master/hooks/opencode/rtk.ts";
    hash = "sha256-1fxnpkmqd31qb4gsvnwdimjiwgji9s6xdar2jlpqk13cjhqw2c35";
  };
in
{
  programs.opencode.settings.plugin = [
    "@tarquinen/opencode-dcp@latest"
    "opencode-pty"
    "opencode-handoff"
  ];

  xdg.configFile."opencode/plugins/rtk.ts".source = rtkPlugin;
}
