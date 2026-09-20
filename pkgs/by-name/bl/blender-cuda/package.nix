# filepath: ~/nixos-config/pkgs/by-name/bl/blender-cuda/package.nix
# blender-cuda:CUDA Blender + 双 MCP(addon 与 server 一体化组装件)
#
# 第一套 ahujasid mcp-for-blender 2.0.0(PyPI sdist,原 blender-mcp;2.0.0 起
# 上游改名,旧名沦为装新包的兼容壳 —— 本仓直接钉真身),两个半边出自同一
# derivation:
#   - MCP server:buildPythonPackage → bin/mcp-for-blender(上游 bin 改名,
#     组装层补旧名 blender-mcp symlink,下游 mcp-project/manifest 零改动)。
#     依赖不变:mcp(>=1.9,<2)+ httpx;consent_prompt 直接 import pydantic,
#     显式声明(上游 requires_dist 仍未列)。src/ 布局沿用 1.9.1;sdist 完整
#     自洽(含 config.py)。重构后的命令分发仍走 addon 内 BlenderMCPServer.
#     execute_command(bootstrap hook 点不变),TCP 9876 不变
#   - Blender addon:上游以 package-data 内嵌 bundled/addon.py,从 server 的
#     site-packages 提取 → BLENDER_SYSTEM_SCRIPTS 脚本树(Blender 官方部署机制,
#     deploying_blender:$SYSTEM_SCRIPTS/addons/ 放插件 + startup/ 启动期启用)。
#     addon/server 版本一致性由构造保证;卸载本包 = 环境变量指向的树一起消失,
#     不存在 ~/.config 里的孤儿拷贝(addon 纯 stdlib,无需 withPackages)
#
# 第二套 Blender Lab 官方(blender-lab-mcp 包):server bin/blender-lab-mcp 直通;
# addon 走同一条 SYSTEM_SCRIPTS 树,端口钉 9877 避开 ahujasid 的 9876。分工:
# ahujasid 管建模/资产(PolyHaven 等),官方管 bpy 文档检索与场景分析(捆绑
# API/手册 rst)。两 addon 的 TCP server 同持锁串行语义,跨套并发同样会在
# addon 侧排队——调用纪律不变:一次一个。
#
# Blender 本体 = blender.override { cudaSupport = true; }(Cycles CUDA + OptiX;
# OptiX 使 license 含 unfree,依赖 modules/nixos/nix.nix 的 allowUnfree)。
# cuda 变体不在 cache.nixos.org:首次构建/nixpkgs bump 后本机源码编译(小时级,
# 可先 nix build .#blender-cuda 后台预热)。无三方 cachix 可挂:adithyagenie 缓存
# 钉其自建 nixpkgs-25.05 pin,与本仓 unstable 的 derivation hash 必然不同。
{
  lib,
  blender,
  blender-lab-mcp,
  fetchurl,
  makeWrapper,
  python3Packages,
  runCommand,
}:

let
  server = python3Packages.buildPythonPackage rec {
    pname = "mcp-for-blender";
    version = "2.0.0";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/f0/6d/eb915b4ed7c19e5ec6a1d0c7a757771be8f809ca85bf558d89b88d793db7/mcp_for_blender-2.0.0.tar.gz";
      hash = "sha256-xB07CDrHc1GY3kahlcmSKdifoxT74i5yeWCPieJMFYw=";
    };

    build-system = [ python3Packages.setuptools ];

    dependencies = with python3Packages; [
      httpx
      mcp
      pydantic
    ];

    # server 模块树不 import bpy(trajectory 仅懒加载)——此检查兼作 sdist 自洽性
    # 断言(config.py 在位、无已移除依赖的硬 import)
    pythonImportsCheck = [ "blender_mcp.server" ];

    meta = {
      description = "Blender integration through the Model Context Protocol";
      homepage = "https://github.com/ahujasid/mcp-for-blender";
      license = lib.licenses.mit;
      mainProgram = "mcp-for-blender";
    };
  };

  cudaBlender = blender.override {
    cudaSupport = true;
    rocmSupport = false;
  };

  # Blender 官方 SYSTEM 级脚本树:LOCAL/USER 之外的第三棵只读脚本目录
  systemScripts = runCommand "blender-mcp-scripts" { } ''
    # 注意:BLENDER_SYSTEM_SCRIPTS 指向的目录 = LOCAL 的 scripts/ 层级本身
    # (addon_utils.paths() 对非 LOCAL 条目直接拼 addons/,再套 scripts/ 必然
    # 扫描落空——首版即栽在此,headless 实测 paths() 才定位)
    mkdir -p $out/addons
    # addon 从 server 包内提取(bundled/addon.py);路径缺失即构建失败,隐式断言
    cp ${server}/${python3Packages.python.sitePackages}/blender_mcp/bundled/addon.py \
      $out/addons/blender_mcp.py
    # Blender Lab 官方 addon:blender-lab-mcp 包已注入 bl_info(转 legacy 格式),
    # 这里原样收录;模块名 blender_lab_mcp(避开 ahujasid 的 blender_mcp)
    cp -r ${blender-lab-mcp}/share/blender-lab-mcp/addon $out/addons/blender_lab_mcp
    # 自有 policy addon:纯 GPU 渲染默认。为何独立 addon 而非 startup 脚本:
    # 实测 startup 脚本(顶层或 register)注册的 load_post handler 会在启动
    # 收尾被清退,addon register() 才是 persistent handler 的规范载体(lab
    # addon 的 autostart timer 同机制在生产验证)。相位:timer 兜 GUI 启动
    # (load_post 不随启动文件加载 fire),load_post 兜文件打开/新建;background
    # 裸启动不覆盖(bpy timers 不 fire)——后台渲染走带文件路径的调用即可
    mkdir -p $out/addons/blender_cuda_defaults
    cat > $out/addons/blender_cuda_defaults/__init__.py <<'PYEOF'
    bl_info = {
        "name": "Blender CUDA Defaults",
        "author": "nixos-config",
        "version": (1, 0, 0),
        "blender": (5, 1, 0),
        "location": "Automatic (BLENDER_SYSTEM_SCRIPTS policy addon)",
        "description": "Pure-GPU (OptiX) render defaults; escape via BLENDER_MIXED_RENDER=1",
        "category": "Render",
    }

    import os

    import bpy


    def _dbg(msg):
        # 生命周期日志:仅 BLENDER_POLICY_DEBUG=路径 时写(生产零副作用)
        p = os.environ.get("BLENDER_POLICY_DEBUG")
        if p:
            try:
                with open(p, "a") as f:
                    f.write(msg + "\n")
            except Exception:
                pass


    def _gpu_pin(*_args):
        # 出厂三重非默认须全部钉住(实测 --factory-startup):
        # compute_device_type=NONE / 新场景 cycles.device=CPU / 设备列表同卡
        # CUDA+OptiX 双开。混合模式 CPU 仅添 3~10% 且抽干整机 CPU(渲染期间
        # AI 工作流全卡),双 BVH 费显存。逃生舱 BLENDER_MIXED_RENDER=1;
        # 逐启动重置 = nix 会话级默认,会话内 GUI 改动当次有效
        try:
            cp = bpy.context.preferences.addons["cycles"].preferences
            if cp is not None:
                cp.compute_device_type = "OPTIX"
                try:
                    cp.get_devices()
                except Exception:
                    pass
                for d in cp.devices:
                    d.use = (d.type == "OPTIX")
            n = 0
            for sc in bpy.data.scenes:
                try:
                    if sc.cycles.device != "GPU":
                        sc.cycles.device = "GPU"
                        n += 1
                except Exception:
                    pass
            _dbg(f"pin scenes_set={n} fp={os.path.basename(bpy.data.filepath)!r}")
        except Exception as e:
            print("blender-cuda GPU pin failed:", e)


    # handler 持久化只有一种官方写法:bpy.app.handlers.persistent(fn) 标记
    # (特殊类,C 层按类型判定;裸 fn.persistent=True 是布尔,过不了类型
    # 检查,受控实验证实必被文件加载清除)。在模块级标记一次,处处生效
    bpy.app.handlers.persistent(_gpu_pin)


    def _boot_pin():
        # timer 回调 = 启动彻底完成后的全上下文:钉一次,兜 argv 文件加载
        # 把 scene 打回的时序(--python 先于 argv 文件执行,实测 0.9s 加载)
        _dbg("boot_pin fire")
        _gpu_pin()
        if not any(h == _gpu_pin for h in bpy.app.handlers.load_post):
            bpy.app.handlers.load_post.append(_gpu_pin)
        return None  # one-shot


    def register():
        _dbg("register")
        if os.environ.get("BLENDER_MIXED_RENDER"):
            return
        # timer 的 persistent=True 是 bpy.app.timers.register 自己的关键字
        # 参数(与 addon_utils.enable 的 persistent 同名不同物):默认 False
        # 的 timer 会被文件加载拔掉——argv 加载在 --python 后 ~0.4s,未 fire
        # 的 timer 必死。幂等:文件加载重激活会再次 register
        if not any(h == _gpu_pin for h in bpy.app.handlers.load_post):
            bpy.app.handlers.load_post.append(_gpu_pin)
        if not bpy.app.timers.is_registered(_boot_pin):
            bpy.app.timers.register(_boot_pin, first_interval=1.0, persistent=True)


    def unregister():
        _dbg("unregister")
        try:
            bpy.app.handlers.load_post.remove(_gpu_pin)
        except Exception:
            pass
    PYEOF
    # 载入车辆(全部经 netns 隔离舱实测,别凭直觉改):
    #   - startup/ 脚本:argv 带 .blend 时整个不跑(双击文件打开 = MCP 全灭)→ 弃用
    #   - wrapper 注入 --python bootstrap.py:-P 脚本在任何模式下都执行
    #     (GUI/背景/argv 文件),运行时序:startup 文件加载之后、argv 文件加载
    #     之前(实测 GUI argv 加载于 ~0.9s)
    #
    # 三条同名 persistent 的机制(本次排障全部踩过,受控实验定案):
    #   1. addon_utils.enable(persistent=...) → enable 能否活过文件加载(文件
    #      加载只重激活 default/persistent addon,其余回滚+unregister);与
    #      userpref 落盘无关(落盘只由 default_set 决定)
    #   2. bpy.app.timers.register(..., persistent=True) → timer 不被文件加载
    #      拔掉(默认 False 必死,argv 加载时未 fire 的 timer 来不及救场)
    #   3. bpy.app.handlers.persistent(fn) 装饰器 → handler 持久化唯一合法
    #      写法(特殊类,C 层类型判定;裸 fn.persistent=True 是布尔,必被清除)
    #
    # Blender Lab addon 两处差异(均实测):
    #   1. online 门:其 TCP server 被 bpy.app.online_access 门禁(上游对
    #      localhost 也一刀切),背后开关在 preferences.system.use_online_access,
    #      启动期声明式拨开(只读投影 bpy.app.online_access 不可直接写)
    #   2. default_set 建 AddonPreferences 内存条目(register 与端口写入都依赖
    #      它);端口 9877 与 mcp-project.nix 的 BLENDER_MCP_PORT 对齐
    cat > $out/bootstrap.py <<'EOF'
    import importlib
    import os
    import sys

    _addons = os.path.join(os.path.dirname(os.path.abspath(__file__)), "addons")
    if _addons not in sys.path:
        sys.path.insert(0, _addons)
    importlib.invalidate_caches()

    import addon_utils
    import bpy

    # persistent 语义(源码 addon_utils.py:345,曾弄反踩坑):它管的是
    # "enable 能否活过文件加载"(文件加载时 Blender 只重激活 default/
    # persistent addon,会话级 enable 全回滚+unregister),不是"是否写
    # userpref"——写盘只由 default_set 触发。argv .blend 加载发生在
    # --python 之后(实测 0.9s),persistent=False 的 addon 在双击文件打开
    # 时全灭。故一律 persistent=True:会话级、活过任何文件加载、不落盘
    # ── MCP 日志落盘 ──────────────────────────────────────────────
    # 动机(2026-08 实战):桌面启动的 Blender stdout/stderr 全进 /dev/null,
    # addon 两次无声死掉(端口消失/半死不应答)后零线索,排查全靠进程考古。
    # 方案:本模块提供 append 型文件 logger,对两个 addon 各挂一个钩子——
    # 不改上游文件(升级免疫),monkey-patch 只包公开入口。日志归 XDG state
    import os
    import sys
    import time
    import traceback

    _LOG = os.path.join(
        os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
        "blender", "mcp.log",
    )

    def _mcp_log(tag, msg):
        try:
            os.makedirs(os.path.dirname(_LOG), exist_ok=True)
            with open(_LOG, "a") as f:
                f.write("{:s} [{:s}] {:s}\n".format(
                    time.strftime("%H:%M:%S"), tag, msg))
        except Exception:
            pass

    _mcp_log("boot", "bootstrap logging armed → " + _LOG)

    bpy.context.preferences.system.use_online_access = True

    try:
        addon_utils.enable("blender_mcp", default_set=False, persistent=True)
        # ahujasid 命令分发唯一入口(单文件 addon,类 BlenderMCPServer):
        # 包装记耗时/非成功响应/异常——死亡时刻与死因本体
        try:
            from blender_mcp import BlenderMCPServer as _BMS
            _orig_exec = _BMS.execute_command

            def _logged_exec(self, command):
                t0 = time.monotonic()
                cmd = command.get("type", "?") if isinstance(command, dict) else "?"
                try:
                    r = _orig_exec(self, command)
                    ms = int((time.monotonic() - t0) * 1000)
                    st = r.get("status", "?") if isinstance(r, dict) else "?"
                    if st != "success":
                        _mcp_log("ahujasid", "{:s} → {:s} ({}ms) {!s:.160}".format(
                            cmd, st, ms, r))
                    return r
                except Exception as ex:
                    _mcp_log("ahujasid", "EXC {:s}: {!s}\n{:s}".format(
                        cmd, ex, traceback.format_exc()))
                    raise

            _BMS.execute_command = _logged_exec
            _mcp_log("ahujasid", "execute_command hook installed")
        except Exception as ex:
            _mcp_log("ahujasid", "hook failed: {!s}".format(ex))
    except Exception as e:
        print("blender-mcp autostart failed:", e)
        _mcp_log("ahujasid", "enable failed: {!s}".format(e))

    try:
        addon_utils.enable("blender_lab_mcp", default_set=True, persistent=True)
        _lab_prefs = bpy.context.preferences.addons["blender_lab_mcp"].preferences
        _lab_prefs.port = 9877
        # lab 自带 use_log(逐请求打印),但打 stderr——桌面启动即黑洞。
        # 开关打开 + 把模块级 print 函数替换为落盘版(签名兼容 file= kwarg)
        try:
            import blender_lab_mcp.mcp_to_blender_server as _lab_srv
            _lab_prefs.use_log = True

            def _lab_print(*args, file=None, **kw):
                _mcp_log("lab", " ".join(str(a) for a in args)[:2000])

            _lab_srv.print = _lab_print
            _lab_srv.use_log = True
            _mcp_log("lab", "use_log → file redirect installed")
        except Exception as ex:
            _mcp_log("lab", "log redirect failed: {!s}".format(ex))
    except Exception as e:
        print("blender-lab-mcp autostart failed:", e)
        _mcp_log("lab", "enable failed: {!s}".format(e))

    try:
        # 纯 GPU(OptiX)渲染默认 addon。钉住要覆盖两个时序:
        #   - bootstrap 本身先于 argv .blend 加载执行:直钉一次会被随后的
        #     文件加载打回(background 无 timer 可救)→ 这里直接补挂 load_post
        #     (--python 阶段晚于启动收尾的 handler 清退,实测可存活),文件
        #     加载完 fire 即钉;GUI 的 1s timer 兜无文件裸启动,幂等防重
        addon_utils.enable("blender_cuda_defaults", default_set=False, persistent=True)
        if not os.environ.get("BLENDER_MIXED_RENDER"):
            from blender_cuda_defaults import _gpu_pin

            _gpu_pin()
            bpy.app.handlers.persistent(_gpu_pin)
            if not any(h == _gpu_pin for h in bpy.app.handlers.load_post):
                bpy.app.handlers.load_post.append(_gpu_pin)
    except Exception as e:
        print("blender-cuda defaults failed:", e)
    EOF
  '';
in
runCommand "blender-cuda-${cudaBlender.version}"
  {
    nativeBuildInputs = [ makeWrapper ];

    passthru = {
      inherit server systemScripts;
    };

    meta = (builtins.removeAttrs cudaBlender.meta [ "outputsToInstall" ]) // {
      description = "Blender (CUDA) with blender-mcp addon preloaded via BLENDER_SYSTEM_SCRIPTS";
      mainProgram = "blender";
    };
  }
  ''
    mkdir -p $out/bin $out/share/applications
    # desktop 入口直拷(Exec=blender 与本包 bin 名一致;图标目录符号链接)
    cp ${cudaBlender}/share/applications/blender.desktop $out/share/applications/
    ln -s ${cudaBlender}/share/icons $out/share/icons
    # CLI 与 GUI 同路径:wrapper 注入 SYSTEM_SCRIPTS + bootstrap 脚本。
    # --python 载入是命脉:argv 带 .blend 时(双击文件)startup 脚本整个
    # 不跑,-P 却总是执行——没有它,文件管理器打开的 Blender 没有 MCP
    makeWrapper ${cudaBlender}/bin/blender $out/bin/blender \
      --set BLENDER_SYSTEM_SCRIPTS ${systemScripts} \
      --add-flags "--python ${systemScripts}/bootstrap.py"
    # MCP server 半边直通(项目级 MCP 条目按名引用,见 common/mcp-project.nix)。
    # 旧名 blender-mcp symlink 必须保住:mcp-project.nix 的 command 与项目
    # manifest.json 都按旧名 PATH 解析;新名并存,向前兼容
    ln -s ${server}/bin/mcp-for-blender $out/bin/mcp-for-blender
    ln -s ${server}/bin/mcp-for-blender $out/bin/blender-mcp
    ln -s ${blender-lab-mcp}/bin/blender-lab-mcp $out/bin/blender-lab-mcp
  ''
