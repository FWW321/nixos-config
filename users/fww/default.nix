# filepath: ~/nixos-config/users/fww/default.nix
{
  config,
  pkgs,
  inputs,
  ...
}:

{
  home.username = "fww";
  home.homeDirectory = "/home/fww";
  home.stateVersion = "25.11";

  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../../secrets/secrets.yaml;
  };

  imports = [
    inputs.zen-browser.homeModules.default
    ./ai/opencode.nix
    ../../modules/user/desktop.nix
    ../../modules/user/terminal.nix
    ../../modules/user/editor.nix
  ];

  stylix.targets.zen-browser.profileNames = [ "default" ];

  programs.zen-browser = {
    enable = true;
    policies = {
      RequestedLocales = [ "zh-CN" "en-US" ];
    };
    profiles.default = {
      search = {
        force = true;
        default = "bing";
      };
      extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
        ublock-origin
      ];
    };
  };

  home.packages = with pkgs; [
    fd
    bun
    curl
    btop
    ripgrep
    xwayland-satellite
    nvtopPackages.nvidia
  ];

  programs.bash.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "fww";
      user.email = "3223400498@qq.com";
      init.defaultBranch = "main";
      core.editor = "nvim";
      core.ignorecase = false;
      pull.rebase = true;
      push.autoSetupRemote = true;
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  sops.secrets.github_ssh_key = {
    path = "${config.home.homeDirectory}/.ssh/github";
    mode = "0600";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = config.sops.secrets.github_ssh_key.path;
        identitiesOnly = true;
      };
    };
  };
}
