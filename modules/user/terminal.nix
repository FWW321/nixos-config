# filepath: ~/nixos-config/modules/user/terminal.nix
{ config, pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      window-decoration = false;
      command = "nu";
    };
  };

  programs.nushell = {
    enable = true;
    extraConfig = ''$env.config = { show_banner: false, edit_mode: vi, error_style: "fancy" }'';
    shellAliases = {
      vi = "nvim";
      vim = "nvim";
      ll = "ls -l";
      cat = "bat";
      y = "yazi";
    };
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = "$all";
    };
  };
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    options = [ "--cmd cd" ];
  };
  programs.direnv = {
    enable = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  programs.bat = {
    enable = true;
  };

  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    shellWrapperName = "y";
  };
}
