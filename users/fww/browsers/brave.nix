# filepath: ~/nixos-config/users/fww/browsers/brave.nix
# Brave Browser 配置
{ ... }:

{
  programs.brave = {
    enable = true;
    commandLineArgs = [ "--restore-last-session" ];
    extensions = [{ id = "bdiifdefkgmcblbcghdlonllpjhhjgof"; }];
  };
}
