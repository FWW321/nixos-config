# filepath: ~/nixos-config/users/fww/desktop/blender.nix
# Blender(CUDA)+ blender-mcp 部署:归属 desktop(AI 是叠加的控制接口,非本体域)
#
# N 卡门控同 koharu.nix:宿主声明 nvidia 驱动才部署(CUDA 渲染依赖它);
# 求值期纯判断,HM standalone 视为无 N 卡。额外排除 vmtest:其 params.gpu="nvidia"
# 是 initrd 模块测试的夹具产物(hosts/vmtest/default.nix 126-129),QEMU 内无真实
# GPU——不排除的话装机彩排循环会拖进小时级 CUDA blender 编译。
# MCP 接线在 ai/common/mcp-project.nix 的 "blender-mcp" 条目(项目级 opt-in,
# 按名引用 bin/blender-mcp,不走 store path 插值——避免非 N 卡主机也被牵进
# 闭包)。使用序:启动 Blender(脚本树自动启用 addon,上游 auto_start 自动
# 监听 TCP 9876,零手动 UI)→ 项目 manifest 声明 blender-mcp + agent sync。
#
# 3d-init:建模项目脚手架(Blender 生态无 cargo init 等价物,自补)。
# 目录约定见 ~/Projects/3d/(总目录 + library 跨项目资产库):
#   3d-init <name>   →  ~/Projects/3d/<name>/ 完整骨架 + git init
# 幂等:目标已存在即拒,不覆盖不半途
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  # 同 koharu:宿主声明了 nvidia 驱动才部署;HM standalone 时视为无 N 卡
  videoDrivers = osConfig.services.xserver.videoDrivers or [ ];
  hasNvidia = builtins.elem "nvidia" videoDrivers;
  # vmtest 夹具排除(见头注释)。不探测 virtualisation.vmVariant:raw 类型
  # option,判断即强迫嵌套 VM 配置求值(HM 侧引爆);夹具点名最直白
  isRehearsalVm = osConfig.networking.hostName == "vmtest";

  # 项目骨架生成器:目录 + agent 接线 + 不变量预写(AGENTS.md 从第一秒
  # 就在,AI 不用靠犯错学约定)。gitignore 只列可重建产物;blend1 是
  # Blender 自动备份(~ 的 swp 同科)
  init3d = pkgs.writeShellScriptBin "3d-init" ''
    set -euo pipefail
    [ $# -eq 1 ] || { echo "usage: 3d-init <project-name>"; exit 1; }
    ROOT="''${XDG_PROJECTS_DIR:-$HOME/Projects}/3d"
    PROJ="$ROOT/$1"
    [ -e "$PROJ" ] && { echo "refuse: $PROJ already exists"; exit 1; }

    mkdir -p "$PROJ"/{assets,scenes,renders,exports,cache,scripts,snapshots} \
             "$PROJ"/.agents

    echo '{"mcp": ["blender-mcp", "blender-lab"]}' > "$PROJ/.agents/manifest.json"

    cat > "$PROJ/AGENTS.md" <<'EOF'
    # 建模项目约定

    - 渲染输出统一放项目根 renders/。脚手架 .blend 在 scenes/,故写
      scene.render.filepath = '//../renders/hero_v1.png'(// 展开为 .blend
      所在目录,//../ 即项目根)。禁止 //renders/(= scenes/renders/)、
      绝对路径、裸文件名;不确定时先读 scene.render.filepath 确认再渲。
      出图后核对文件落在项目根 renders/ 才算完成
    - 渲染时长分两路:预计 <10s 的预览可同步 bpy.ops.render.render();
      更长的必须后台渲,且 Popen 只能经 execute_blender_code 在 Blender
      进程内发起(实测:Blender 内 Popen+start_new_session=True 的子进程
      连 Blender 退出都不死;而在 agent 的 shell 里 Popen 会被命令环境
      在命令结束时回收——ChatGPT app 里实测起即被杀,渲染 0 字节)。
      写法:bpy.ops.wm.save_mainfile() 后 subprocess.Popen(
      [bpy.app.binary_path,'--python-use-system-env','-b',
      bpy.data.filepath,'-f','1'],start_new_session=True)
      不等待,轮询输出文件出现再继续。binary_path 直起=绕过包装器,
      子进程不跑 bootstrap 不抢 MCP 端口;--python-use-system-env 必带,
      无它嵌入式 Python 无视 PYTHONPATH,import numpy 等第三方库当场炸
      (实测扩展管理器报缺 cattrs 即此因)。同步渲染会冻结 Blender
      主线程(GUI/MCP 全堵),且 OptiX 满载会挤垮桌面合成器导致 app 崩溃
    - 渲染进行中不要向 Blender 发其他 MCP 命令(主线程忙,只会排队超时);
      后台渲模式下可正常发
    - 后台渲染(blender -b)读的是 .blend 文件里存的渲染设置。GPU 钉住
      需两个不同字段,缺一必回退 CPU(实测 2240% CPU 打满整机):
        scene.cycles.device = 'GPU'        # 场景级,决定性,存于 .blend
        prefs.compute_device_type = 'OPTIX' # 全局后端,另设
        prefs.get_devices() 后 device.use = (d.type=='OPTIX')
      三步全做 → bpy.ops.wm.save_mainfile() 存进文件 → 再 Blender 内
      Popen。只钉 compute_device_type 不设 scene 字段 = 仍 CPU(场景字段赢)
    - 渲染负载分档,由用户当下指令决定,默认降载:挂机/无人用桌面时全速;
      用户正在用桌面时先设 scene.cycles.pixel_size = 2 再 Popen(渲完无需
      还原,该字段不持久)。全速 OptiX 满载会挤垮同卡桌面合成器(实测
      打字卡顿、Chromium 系 app 闪退),pixel_size=2 留出桌面所需的 GPU 余量
    - 新贴图先拷进 `assets/<name>/textures/` 再以 `//` 相对路径引用,禁止绝对路径
    - scenes/ 只 link 引用组装(GEO-/MAT-/COL-/LGT- 前缀命名);资产本体回
      assets/ 改,单处修改全场景同步;可复用资产精修后进 ~/Projects/3d/library/
    - 大改前先另存 .blend 快照到 snapshots/
    - blender-mcp 工具一次只发一个,等结果再发下一个(上游单 socket 锁串行,
      并发不会交错但会在锁上排队,表现是长时间"加载中";两套 Blender MCP 同此纪律)
    - 两套 MCP 分工:blender-mcp(ahujasid)管建模/PolyHaven 资产;
      blender-lab(官方)管 bpy 文档检索与场景分析——写 bpy 代码拿不准 API
      时先用 blender-lab 查,不要凭记忆编
    - PolyHaven/Hyper3D 是 Scene 级开关,每个 .blend 默认关。报"disabled"时
      不要绕路手写下载脚本,先 execute_code 翻开关再用专用工具:
      bpy.context.scene.blendermcp_use_polyhaven = True (Hyper3D 同理)
    - blender-lab execute 的 code 必须把返回值赋给 `result`(且是 dict),
      裸表达式/只打印 stdout 都返回空
    - RNA enum_items 是滞后快照,不反映同批新 enable 的 addon;探测能力
      直接赋值试错+读回(赋值抛错本身就是答案),别信枚举列表
    - 本机 Blender UI 是中文,所有节点树(材质/世界/合成/几何)的节点名都是
      本地化文本(实测:「原理化 BSDF」「背景」「世界输出」),按名字寻址必坏;
      一律 bl_idname 寻址(ShaderNodeBsdfPrincipled/ShaderNodeBackground/
      ShaderNodeOutputWorld);nodes.new() 返回的引用直接拿在手里,别再按名找回
    - execute 脚本一段抛错全盘皆丢(整发报废须重跑):版本不确定的属性
      访问各自 try/except;探 addon 的设置项走活实例路径(如 scene.cycles),
      别查 bpy.types 注册表(5.2 Cycles 类型已不在 bpy.types)
    - bpy 节点等 RNA 对象不收自定义 Python 属性(实测 5.2 直接
      AttributeError '…' object has no attribute …);挂标记走 IDProperty
      方括号语法 node["tag"]=…(可持久化进 .blend),或 Python 侧自建 dict
    - image.unpack() 只写回 filepath 指的原路径,无目标参数;原路径不合
      预期(如插件导入的 /tmp)时静默 no-op,不抛异常,try/except 探不到。
      落盘贴图可靠做法:手写 img.packed_file.data 字节 → 改 img.filepath
      相对路径 → unpack(method='REMOVE') 仅作清理 packed 状态
    - 节点插座类型即赋值契约:RGBA(Color)插座必须 4 元组 (r,g,b,a),
      标量 TypeError;VALUE 插座才是标量。按 inputs[i].type 分支处理
    - 新材质默认树已含 Principled BSDF + Material Output:要么复用默认
      节点直接接线(推荐),要么先删光默认节点再搭——另建第二套输出必静默
      败北(Python 新建输出节点不自动激活,渲染只认 is_active_output 那套,
      默认的纯白 BSDF 永远赢)。需换输出:out.is_active_output = True(可写,
      互斥切换)。材质搭完自检:输出节点数==1 且 Surface 链路来自你的 BSDF
    EOF

    cat > "$PROJ/.gitignore" <<'EOF'
    renders/
    exports/
    cache/
    snapshots/
    *.blend1
    EOF

    # LFS track 从第一提交就位(事后 migrate 要重写历史,贵);blend/贴图
    # 全是二进制大件,git diff 本就无意义,走指针+去重
    cat > "$PROJ/.gitattributes" <<'EOF'
    *.blend filter=lfs diff=lfs merge=lfs -text
    *.png filter=lfs diff=lfs merge=lfs -text
    *.exr filter=lfs diff=lfs merge=lfs -text
    *.hdr filter=lfs diff=lfs merge=lfs -text
    EOF

    git -C "$PROJ" init -q
    git lfs install >/dev/null 2>&1 || true # 本机全局钩子,幂等;缺 lfs 不挡建项目
    echo "created: $PROJ"
    echo "next: cd $PROJ && agent sync   # 启用 blender-mcp(opencode renderer)"
  '';
in
{
  home.packages = lib.mkIf (hasNvidia && !isRehearsalVm) ([ pkgs.blender-cuda ] ++ [ init3d ]);
}
