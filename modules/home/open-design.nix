# filepath: ~/nixos-config/modules/home/open-design.nix
# OpenDesign 的 Home Manager 服务模块 — 上游 nix/module-common.nix +
# nix/home-manager.nix @open-design-v0.21.1 的本仓瘦身版(上游 #7644 退役
# 官方 Nix 分发后自持;原文见 tag)。
#
# 瘦身边界:Linux-only(砍 launchd/NixOS 变体/autoStart 断言/文档字符串),
# 但 option 名逐字保留 —— 消费方(users/fww/ai/open-design.nix、
# common/mcp-project.nix)对 services.open-design.* 的派生引用是硬契约,
# 改名即断;上游模块新增 option 时按需抄名。
#
# 架构:daemon(open-design CLI,:7457,JSON API)+ 可选 caddy(:5174,静态 SPA +
# /api、/artifacts、/frames 三段反代,SSE 安全)。数据落 dataDir(SQLite +
# projects/<id>/ + artifacts/)。daemon 扫描 PATH 发现 agent CLI —— unit
# 的 PATH 注入是"能否发现 agent"的承重点。
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.open-design;

  daemonExe = lib.getExe cfg.package;

  # 静态服务器选 caddy:单二进制、SPA 深链回退、SSE 反代配置简单
  inherit (pkgs) caddy;

  # SPA 构建期 OD_DAEMON_URL="" → 浏览器发相对 /api/* 请求,caddy 同源
  # 反代回 daemon。/api/* 必须 SSE 安全:flush_interval -1 立即冲刷、不
  # encode(gzip 会把 chunked SSE 缓冲 ~80s,浏览器侧
  # ERR_INCOMPLETE_CHUNKED_ENCODING)。站点地址显式 http://(裸 host:port
  # 会让 caddy 按端口猜协议,与 auto_https off 打架出 TLS 错)。
  caddyfile = pkgs.writeText "open-design-web.Caddyfile" ''
    {
      auto_https off
      admin off
      persist_config off
    }

    http://${cfg.webFrontend.host}:${toString cfg.webFrontend.port} {
      handle /api/* {
        reverse_proxy 127.0.0.1:${toString cfg.port} {
          flush_interval -1
          transport http {
            read_timeout 86400s
            write_timeout 86400s
          }
        }
      }
      handle /artifacts/* {
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
      handle /frames/* {
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
      handle {
        root * ${cfg.webFrontend.package}
        try_files {path} {path}/ /index.html
        file_server
        encode gzip
      }
    }
  '';

  # systemd --user 起在最小 PATH 上,不含 HM/系统 profile —— daemon 靠
  # process.env.PATH 扫 agent CLI,不注入则 UI 报 "no agents detected"。
  # HM profile 目录覆盖 standalone(~/.nix-profile)与 as-NixOS-module
  # (/etc/profiles/per-user/<u>) 两种形态;opencode2 就住在后者。
  daemonPathEntries = [
    "${config.home.profileDirectory}/bin"
  ]
  ++ [
    "/run/wrappers/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ]
  ++ cfg.extraBinPaths;

  daemonEnv = {
    OD_PORT = toString cfg.port;
    OD_DATA_DIR = toString cfg.dataDir;
    PATH = lib.concatStringsSep ":" daemonPathEntries;
    # ── 子进程卫生(2026-09-21,根治「万能父进程」泄漏)──────────────────
    # 机制与证据链见 pkgs/by-name/op/open-design/ 各文件头注释。三件事:
    #   1. daemon 的每个异步 spawn 经 NODE_OPTIONS 预加载 shim 重定向到
    #      收养门(od-scope-exec):整棵子树落进 od-spawn-*.scope,命令退出
    #      后看门狗 sweep 收割 daemonized 泄漏(容器/postgres/electron 类)
    #   2. 集成终端经 SHELL 外壳(od-term-shell)进 od-term-*.scope,
    #      终端关闭即整树清理
    #   3. OD_SCOPE_ROLE=daemon 门禁:仅 daemon 本进程生效,子代环境被改写
    #      为 child,agent CLI 的工具调用靠 cgroup 继承归入 run scope
    # 临时关闭:systemctl --user edit open-design 清掉 NODE_OPTIONS 与 SHELL。
    # ⚠ 必须用 --require=<path> 等号形式:值含空格会被 systemd Environment=
    # 切成两个赋值,NODE_OPTIONS 只剩光杆 --require,node 秒退 exit 9,
    # Restart=always 下无限崩溃循环(2026-09-21 02:05 实测 180+ 次,
    # 症状:UI 连接中断/项目列表空/代理未检测 —— daemon 从未起来)
    NODE_OPTIONS = "--require=${cfg.package}/lib/open-design/scope-shim.cjs";
    OD_SCOPE_ROLE = "daemon";
    SHELL = "${cfg.package}/bin/od-term-shell";
    OD_REAL_SHELL = "${pkgs.bashInteractive}/bin/bash";
  }
  // lib.optionalAttrs cfg.webFrontend.enable {
    # 告知 daemon 同源白名单 caddy 端口,否则 SPA 的 PUT/POST 被
    # /api 中间件 403(apps/daemon/src/server.ts buildAllowedOrigins)
    OD_WEB_PORT = toString cfg.webFrontend.port;
  }
  // lib.optionalAttrs (cfg.webFrontend.allowedOrigins != [ ]) {
    # 非回环暴露的逃生口:逗号连接,origin-validation.ts 解析
    OD_ALLOWED_ORIGINS = lib.concatStringsSep "," cfg.webFrontend.allowedOrigins;
  }
  // cfg.extraEnv;

  envToList = e: lib.mapAttrsToList (k: v: "${k}=${v}") e;
in
{
  options.services.open-design = {
    enable = lib.mkEnableOption "OpenDesign — local-first design product daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.open-design;
      defaultText = lib.literalExpression "pkgs.open-design";
      description = "The OpenDesign daemon package providing the `open-design` binary.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7457;
      description = "TCP port the daemon API binds to. Passed to `open-design --port`.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/.od";
      defaultText = lib.literalExpression "\${config.home.homeDirectory}/.od";
      description = ''
        Runtime state: SQLite database, per-project working trees under
        `projects/<id>/`, saved artifact bundles under `artifacts/`.
      '';
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Register a service that starts the daemon automatically.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        KEY=VALUE lines file for the daemon service environment
        (sops templates fit here; secrets never inline in Nix).
      '';
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables for the daemon service.";
    };

    extraBinPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra absolute directories prepended to the daemon service PATH.";
    };

    webFrontend = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run the bundled caddy static server for the SPA.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5174;
        description = "TCP port the static file server binds to.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Interface the static server binds to. Non-loopback additionally
          requires `allowedOrigins`(daemon 同源门是 fail-closed)。
        '';
      };

      allowedOrigins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "External origins the daemon should accept as same-site.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.open-design-web;
        defaultText = lib.literalExpression "pkgs.open-design-web";
        description = "Built static export to serve (Next.js out/ tree).";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ];

        # 数据目录先行建好,首启幂等
        home.activation.openDesignDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${lib.escapeShellArg (toString cfg.dataDir)}
        '';
      }

      (lib.mkIf cfg.autoStart {
        systemd.user.services.open-design = {
          Unit = {
            Description = "OpenDesign daemon (user service)";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Install.WantedBy = [ "default.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${daemonExe} --port ${toString cfg.port} --no-open";
            Environment = envToList daemonEnv;
            # Restart=always:daemon 是任意退出都该复活的常驻编排器(原
            # on-failure 会放过正常退出路径的意外终结)。配合 RuntimeMaxSec
            # 构成卫生兜底:即使 scope 机制全部旁路,7 天一次的单元重启也会
            # 清空 cgroup(KillMode=control-group 默认值),泄漏堆积有界
            # (2026-09-20 考古:上一次清理前堆积 894 tasks/内存峰值 18.9G)
            Restart = "always";
            RestartSec = 3;
            RuntimeMaxSec = "7d";
          }
          // lib.optionalAttrs (cfg.environmentFile != null) {
            EnvironmentFile = toString cfg.environmentFile;
          };
        };
      })

      (lib.mkIf cfg.webFrontend.enable {
        systemd.user.services.open-design-web = {
          Unit = {
            Description = "OpenDesign web frontend (static file server)";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Install.WantedBy = [ "default.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${lib.getExe caddy} run --config ${caddyfile} --adapter caddyfile";
            Restart = "on-failure";
            RestartSec = 3;
          };
        };
      })
    ]
  );
}
