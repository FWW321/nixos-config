# filepath: ~/nixos-config/users/fww/browsers/brave.nix
# Brave Browser 配置
_:

{
  programs.brave = {
    enable = true;
    commandLineArgs = [ "--restore-last-session" ];
    extensions = [ { id = "bdiifdefkgmcblbcghdlonllpjhhjgof"; } ];
  };
}
