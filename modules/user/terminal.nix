# filepath: ~/nixos-config/modules/user/terminal.nix
{ config, pkgs, ... }:

{
  programs.foot = {
    enable = true;
    server.enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        shell = "nu";
        pad = "12x12";
      };
      mouse = {
        hide-when-typing = "yes";
      };
      csd = {
        preferred = "none";
      };
      url = {
        launch = "\${BROWSER:-zen-beta} \${url}";
        osc8-underline = "url-mode";
      };
      bell = {
        urgent = "yes";
        notify = "yes";
      };
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
