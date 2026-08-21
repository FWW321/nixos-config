# filepath: ~/nixos-config/users/fww/browsers/zen.nix
# Zen Browser 配置 + 搜索引擎别名
{ config, pkgs, inputs, ... }:

let
  # 陪读蛙(Read Frog):上游 firefox-addons 未收录,按 rycee 同款结构从 AMO 自打包
  # (addonId passthru + xpi 落位 share/mozilla/extensions/<FF ext GUID>/,新版 HM 无 buildFirefoxXpiAddon)
  # 更新:查 https://addons.mozilla.org/api/v5/addons/addon/read-frog-open-ai-translator
  # 换 current_version 的 version / file.url / file.hash 三处
  read-frog-addonId = "{bd311a81-4530-4fcc-9178-74006155461b}";
  read-frog = pkgs.stdenv.mkDerivation {
    pname = "read-frog";
    version = "1.46.4";
    src = pkgs.fetchurl {
      url = "https://addons.mozilla.org/firefox/downloads/file/4971952/read_frog_open_ai_translator-1.46.4.xpi";
      sha256 = "01vaq4l147594zmcc9jrnwm8kj54pafd5y8hh1bgvrjxl69gj0vr";
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      dst="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
      mkdir -p "$dst"
      cp "$src" "$dst/${read-frog-addonId}.xpi"
      runHook postInstall
    '';
    passthru.addonId = read-frog-addonId;
    meta = {
      description = "陪读蛙 - 翻译与学习 (Read Frog)";
      homepage = "https://github.com/mengxi-ream/read-frog";
      mozPermissions = [ ];
    };
  };
in
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
          read-frog
        ];
    };
  };

  # 默认浏览器：http(s) 链接 + HTML 文件 → Zen（home-manager 自动与 media.nix 的 xdg.mimeApps 合并）
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = "zen-beta.desktop";
    "x-scheme-handler/https" = "zen-beta.desktop";
    "text/html" = "zen-beta.desktop";
    "application/xhtml+xml" = "zen-beta.desktop";
  };
}
