# filepath: ~/nixos-config/pkgs/chatgpt/default.nix
# 抄自 NixOS/nixpkgs PR #551713(Moraxyc/nixpkgs chatgpt-linux 分支)
# https://github.com/NixOS/nixpkgs/pull/551713
#
# unified ChatGPT/Codex 桌面应用(官方 .deb 解包 + autoPatchelf)。
# 上游 nixpkgs 的 chatgpt 包仅 darwin;此 PR 补齐 Linux 支持。
#
# 核心设计(相比同主题 PR #551852 的优势):
#   - app.asar 内 familySync() 判 libc 被 autoPatchelf 移动的 PT_INTERP 骗过 →
#     sed 强制 'glibc'(grep 断言先验证 patch 点存在,上游改版即构建失败,自校验)
#   - node/rg/tectonic 不用 .deb 捆绑版,symlink nixpkgs 的(闭包更干净)
#   - codexPackage 参数:桌面端 resources/codex 复用 nixpkgs codex CLI 同一二进制,
#     与 home-manager programs.codex 单一来源
#   - Electron 要改写捆绑插件清单 → launcher 把可写的 plugins/ 拷到
#     ~/.cache/chatgpt/bundled-plugins/<version-arch>/(mktemp staging + mv -T 原子发布),
#     其余大目录 symlink store;按版本 key 缓存,升级自动失效
#   - wrapGAppsHook3 + qt6.wrapQtAppsHook 标准桌面集成;
#     NIXOS_OZONE_WL + WAYLAND_DISPLAY 时自动加 Wayland flags
#
# 维护:上游只发可变 latest/ .deb(openai/codex#38457),版本前进后跑 update.sh 重写
# source.json(nix run 之后手动比对 hash)。
#
# TODO(PR 合并进 nixpkgs master 后删除本目录):
#   1. 删 pkgs/chatgpt/
#   2. 删 pkgs/default.nix 中 chatgpt overlay 行
#   3. 使用方 pkgs.chatgpt 自动落回 nixpkgs 官方包,无需改动
{
  lib,
  stdenv,
  stdenvNoCC,
  callPackage,
  fetchurl,

  # hooks
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,

  # native build inputs
  dpkg,
  unzip,

  # build inputs
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  dconf,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libgbm,
  libnotify,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  qt6,
  systemdLibs,

  # runtime deps
  bubblewrap,
  libGL,
  libpulseaudio,
  libsecret,
  nodejs-slim,
  pipewire,
  ripgrep,
  tectonic-unwrapped,
  vulkan-loader,
  xdg-utils,

  codexPackage ? null,
}:
let
  inherit (stdenvNoCC.hostPlatform) isLinux isDarwin system;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  inherit (finalAttrs.passthru.source) version;

  src = fetchurl finalAttrs.passthru.source.src;

  strictDeps = true;
  __structuredAttrs = true;

  # autoPatchelf moves PT_INTERP beyond detect-libc's 2 KiB scan. Its
  # process.report fallback trips Electron's CFI, so use the glibc watcher.
  postPatch = lib.optionalString isLinux ''
    grep -aFq 'const family = familySync();' usr/lib/chatgpt/resources/app.asar
    sed -i "s|const family = familySync();|const family = 'glibc'     ;|" usr/lib/chatgpt/resources/app.asar
  '';

  nativeBuildInputs =
    lib.optionals isDarwin [ unzip ]
    ++ lib.optionals isLinux [
      autoPatchelfHook
      dpkg
      makeWrapper
      qt6.wrapQtAppsHook
      wrapGAppsHook3
    ];

  buildInputs = lib.optionals isLinux [
    (lib.getLib stdenv.cc.cc)
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dconf
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libgbm
    libnotify
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    qt6.qtbase
    systemdLibs
  ];

  dontWrapGApps = true;
  dontWrapQtApps = true;

  sourceRoot = if isLinux then "root" else ".";

  installPhase = ''
    runHook preInstall
  ''
  + lib.optionalString isDarwin ''
    mkdir -p "$out/Applications"
    mkdir -p "$out/bin"
    cp -a ChatGPT.app "$out/Applications"
    ln -s "$out/Applications/ChatGPT.app/Contents/MacOS/ChatGPT" "$out/bin/ChatGPT"
  ''
  + lib.optionalString isLinux ''
    mkdir -p "$out"
    cp -r usr/* "$out"

    # Remove the unused Qt 5 fallback shim.
    rm -f "$out/lib/chatgpt/libqt5_shim.so"

    # This glibc desktop package uses neither musl nor Android variants.
    rm -f \
      "$out/lib/chatgpt/resources/app.asar.unpacked/node_modules/@worklouder/device-kit-oai/node_modules/@worklouder/wl-device-kit/node_modules/serialport/node_modules/@serialport/bindings-cpp/prebuilds/"{linux-*/node.napi.musl.node,android-*/node.napi.*.node} \
      "$out/lib/chatgpt/resources/app.asar.unpacked/node_modules/@worklouder/device-kit-oai/node_modules/@worklouder/wl-device-kit/node_modules/node-hid/prebuilds/"{HID,HID_hidraw}-linux-*-musl/node-napi-v4.node \
      "$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/"{browser,chrome}"/scripts/node_modules/classic-level/prebuilds/"{linux-*/classic-level.musl.node,android-*/classic-level.*.node}

    ln -sf ${lib.getExe tectonic-unwrapped} "$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/latex/bin/tectonic"
    ln -sf ${lib.getExe ripgrep} "$out/lib/chatgpt/resources/rg"
    ln -sf ${lib.getExe nodejs-slim} "$out/lib/chatgpt/resources/cua_node/bin/node"

    install -Dm755 ${lib.getExe finalAttrs.passthru.launcher} "$out/bin/chatgpt"
  ''
  + lib.optionalString (isLinux && codexPackage != null) ''
    ln -sf ${lib.getExe codexPackage} "$out/lib/chatgpt/resources/codex"
    ln -sf ${codexPackage}/bin/codex-code-mode-host "$out/lib/chatgpt/resources/codex-code-mode-host"
  ''
  + ''
    runHook postInstall
  '';

  postFixup = lib.optionalString isLinux ''
    wrapProgram "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      "''${qtWrapperArgs[@]}" \
      --set CHATGPT_EXECUTABLE "$out/lib/chatgpt/ChatGPT" \
      --set CHATGPT_RESOURCES_SOURCE "$out/lib/chatgpt/resources" \
      --set CHATGPT_RESOURCES_CACHE_KEY ${lib.escapeShellArg "${finalAttrs.version}-${system}"} \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs-slim
          xdg-utils
          bubblewrap
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          libnotify
          libpulseaudio
          libsecret
          pipewire
          vulkan-loader
        ]
      } \
      --set-default CODEX_BROWSER_USE_NODE_PATH ${lib.getExe nodejs-slim} \
      --set-default NODE_REPL_NODE_PATH ${lib.getExe nodejs-slim} \
      ${lib.escapeShellArgs (
        lib.optionals (codexPackage != null) [
          "--set-default"
          "CODEX_CLI_PATH"
          (lib.getExe codexPackage)
        ]
      )}
  '';

  dontStrip = true;

  passthru = {
    updateScript = ./update.sh;
    sources = lib.importJSON ./source.json;
    source = finalAttrs.passthru.sources.${system} or (throw "chatgpt is not supported on ${system}");
    launcher = callPackage ./launcher.nix { };
  };

  meta = {
    description = "Desktop application for ChatGPT";
    homepage = "https://developers.openai.com/codex/app";
    changelog = "https://learn.chatgpt.com/docs/changelog";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      wattmto
      moraxyc
    ];
    platforms = lib.attrNames finalAttrs.passthru.sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = if isDarwin then "ChatGPT" else "chatgpt";
  };
})
