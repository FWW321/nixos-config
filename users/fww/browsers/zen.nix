# filepath: ~/nixos-config/users/fww/browsers/zen.nix
# Zen Browser 配置 + 搜索引擎别名
{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.zen-browser.homeModules.default ];

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
          "Bilibili" = { urls = [{ template = "https://search.bilibili.com/all?keyword={searchTerms}"; }]; definedAliases = [ "@bili" ]; };
          "Hugging Face" = { urls = [{ template = "https://huggingface.co/search/full-text?q={searchTerms}"; }]; definedAliases = [ "@hf" ]; };
          "bing".metaData.hidden = false;
          "amazondotcom-us".metaData.hidden = true;
          "ebay".metaData.hidden = true;
        };
      };
      extensions.packages =
        with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
        [
          ublock-origin
          kiss-translator
        ];
    };
  };
}
