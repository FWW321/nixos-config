# filepath: ~/nixos-config/users/fww/default.nix
# 用户 fww 的 Home Manager 配置
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  home.username = "fww";
  home.homeDirectory = "/home/fww";
  home.stateVersion = "25.11";

  # home-manager 26.05 改了 gtk.gtk4.theme 默认值，保持 GTK4 跟随 Stylix 全局主题
  gtk.gtk4.theme = config.gtk.theme;

  # home-manager 今天 (2026-03-24) 新增了 qt.kvantum 模块，其条件 cfg.settings != {} 永远为 true
  # （submodule 会自动注入 General/Applications 选项），导致与 Stylix 冲突
  # 用 mkForce 覆盖整个 submodule 条目，让 Stylix 的自动配色生效
  # 详见: https://github.com/nix-community/home-manager/commit/61463d50
  xdg.configFile."Kvantum/kvantum.kvconfig" = lib.mkForce {
    source = (pkgs.formats.ini { }).generate "kvantum.kvconfig" { General.theme = "Base16Kvantum"; };
  };

  imports = [
    inputs.zen-browser.homeModules.default
    ./ai/opencode.nix
    ../../modules/user/desktop
    ../../modules/user/terminal.nix
    ../../modules/user/editor.nix
    ../../modules/user/scripts/wallpaper-switch.nix
  ];

  # SOPS 密钥管理
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../../secrets/secrets.yaml;
    secrets.github_ssh_key.path = "${config.home.homeDirectory}/.ssh/github";
  };

  # Zen Browser
  stylix.targets.zen-browser.profileNames = [ "default" ];
  programs.zen-browser = {
    enable = true;
    policies.RequestedLocales = [ "zh-CN" "en-US" ];
    profiles.default = {
      settings."browser.startup.page" = 3;
      search = {
        force = true;
        default = "bing";
        engines = {
          "GitHub" = { urls = [{ template = "https://github.com/search?q={searchTerms}"; }]; definedAliases = [ "@gh" ]; };
          "Google Search" = { urls = [{ template = "https://www.google.com/search?q={searchTerms}"; }]; definedAliases = [ "@g" ]; };
          "YouTube Search" = { urls = [{ template = "https://www.youtube.com/results?search_query={searchTerms}"; }]; definedAliases = [ "@yt" ]; };
          "NixOS Packages" = { urls = [{ template = "https://search.nixos.org/packages?query={searchTerms}"; }]; definedAliases = [ "@np" ]; };
          "NixOS Options" = { urls = [{ template = "https://search.nixos.org/options?query={searchTerms}"; }]; definedAliases = [ "@no" ]; };
          "Home Manager Options" = { urls = [{ template = "https://home-manager-options.extranix.com/?query={searchTerms}"; }]; definedAliases = [ "@hm" ]; };
          "Wikipedia" = { urls = [{ template = "https://en.wikipedia.org/wiki/Special:Search?search={searchTerms}"; }]; definedAliases = [ "@w" ]; };
          "Stack Overflow" = { urls = [{ template = "https://stackoverflow.com/search?q={searchTerms}"; }]; definedAliases = [ "@so" ]; };
          "docs.rs" = { urls = [{ template = "https://docs.rs/releases/search?query={searchTerms}"; }]; definedAliases = [ "@docs" ]; };
          "crates.io" = { urls = [{ template = "https://crates.io/search?q={searchTerms}"; }]; definedAliases = [ "@crate" ]; };
          "lib.rs" = { urls = [{ template = "https://lib.rs/search?q={searchTerms}"; }]; definedAliases = [ "@lib" ]; };
          "MDN" = { urls = [{ template = "https://developer.mozilla.org/en-US/search?q={searchTerms}"; }]; definedAliases = [ "@mdn" ]; };
          "npm" = { urls = [{ template = "https://www.npmjs.com/search?q={searchTerms}"; }]; definedAliases = [ "@npm" ]; };
          "PyPI" = { urls = [{ template = "https://pypi.org/search/?q={searchTerms}"; }]; definedAliases = [ "@pypi" ]; };
          "Arch Wiki" = { urls = [{ template = "https://wiki.archlinux.org/index.php?search={searchTerms}"; }]; definedAliases = [ "@arch" ]; };
          "Reddit Search" = { urls = [{ template = "https://www.reddit.com/search/?q={searchTerms}"; }]; definedAliases = [ "@reddit" ]; };
          "Docker Hub" = { urls = [{ template = "https://hub.docker.com/search?q={searchTerms}"; }]; definedAliases = [ "@docker" ]; };
          "bing".metaData.hidden = false;
          "amazondotcom-us".metaData.hidden = true;
          "ebay".metaData.hidden = true;
        };
      };
      extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
        ublock-origin
        kiss-translator
      ];
    };
  };

  # Brave Browser
  programs.brave = {
    enable = true;
    commandLineArgs = [ "--restore-last-session" ];
    extensions = [{ id = "bdiifdefkgmcblbcghdlonllpjhhjgof"; }];
  };

  # 系统工具
  home.packages = with pkgs; [
    qq
    fd
    bun
    curl
    btop
    ripgrep
    nh
    xwayland-satellite
    nvtopPackages.nvidia
  ];

  programs.bash.enable = true;

  # Git 配置 (使用新的 settings 格式)
  programs.git = {
    enable = true;
    settings = {
      user = { name = "fww"; email = "3223400498@qq.com"; };
      init.defaultBranch = "main";
      core = { editor = "nvim"; ignorecase = false; };
      pull.rebase = true;
      push.autoSetupRemote = true;
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  # SSH 配置
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."github.com" = {
      hostname = "github.com";
      user = "git";
      identityFile = config.sops.secrets.github_ssh_key.path;
      identitiesOnly = true;
    };
  };
}
