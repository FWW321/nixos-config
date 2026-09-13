# filepath: ~/nixos-config/users/fww/desktop/godot.nix
# Godot 4 + godot-mcp 部署:游戏开发与 AI 集成(headless CLI 桥,无编辑器内插件)
#
# 与 blender.nix 的根本差异:三个部件全部直接用 nixpkgs 缓存二进制,
# 零自建组装件 —— blender 需要 blender-cuda 的原因是 CUDA override +
# addon 注入运行中的编辑器(SYSTEM_SCRIPTS 时序考古);Godot 的 MCP 走
# spawn CLI(场景 CRUD 用 --headless --script 桥,调试运行用 -d),两个
# 问题都不存在。Godot 4 单二进制原生 --headless(godot3 时代要单独
# server 构建),GUI/导入/导出同一个包。
#
# 导出模板:Godot"模板版本必须精确匹配编辑器版本"的经典痛点,在 Nix 下
# 构造性消解 —— nixpkgs 的 godot/4.x/default.nix 单文件原子 bump
# version + exportTemplatesHash,编辑器与模板永不漂移。接线 = 整目录
# symlink(~/.local/share/godot/export_templates → store),版本子目录名
# 由 tpz 内 version.txt 权威给出,本仓零版本字符串可漂移。副作用:编辑器
# "管理导出模板 → Download and Install"写只读 symlink 必失败(报错而非
# 静默污染,是想要的行为)—— 模板升级 = 升级本仓 nixpkgs pin,原子换代,
# game-init 脚手架的 AGENTS.md 同步禁用该按钮。
#
# 彩排夹具排除(动机同 blender.nix 的 isRehearsalVm):vmtest/na-rehearsal
# 均 QEMU 夹具,永不跑 Godot;不排除则每次夹具构建无谓拖 1GB 模板下载。
# 与 blender 不同处:Godot 纯 CPU 也完整可用,不做 nvidia 门控,所有
# 真实主机部署(含未来无 N 卡的)。
#
# MCP 接线在 ai/common/mcp-project.nix 的 "godot-mcp" 条目(项目级
# opt-in);使用序:game-init 建项目 → agent sync → run_project(-d
# 调试运行)→ get_debug_output 读回运行时报错 → 修复重跑。
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  # 两台 QEMU 夹具点名排除(blender.nix 注释同款理由:探测 vmVariant 会
  # 强迫嵌套 VM 配置求值,HM 侧引爆,夹具点名最直白)
  isRehearsalVm = builtins.elem osConfig.networking.hostName [
    "vmtest"
    "na-rehearsal"
  ];

  # 项目骨架生成器:目录 + 最小可跑场景 + agent 接线 + 不变量预写
  # (AGENTS.md 从第一秒就在,AI 不用靠犯错学约定)。
  # 目录约定 ~/Projects/games/<name>/;幂等:目标已存在即拒不覆盖
  initGame = pkgs.writeShellScriptBin "game-init" ''
    set -euo pipefail
    [ $# -eq 1 ] || { echo "usage: game-init <project-name>"; exit 1; }
    ROOT="''${XDG_PROJECTS_DIR:-$HOME/Projects}/games"
    PROJ="$ROOT/$1"
    [ -e "$PROJ" ] && { echo "refuse: $PROJ already exists"; exit 1; }

    mkdir -p "$PROJ"/{scenes,scripts,assets,builds} \
             "$PROJ"/.agents

    # 最小 project.godot:只写决定行为的三项(名字/主场景/版本),渲染器
    # 等其余字段交给引擎默认 —— 骨架保持可被任意 4.x 直接打开的最小面
    cat > "$PROJ/project.godot" <<EOF
    ; Engine configuration file.
    config_version=5

    [application]

    config/name="$1"
    run/main_scene="res://scenes/main.tscn"
    EOF

    # 主场景:两行 tscn 是稳定格式(format=3 自 4.0 未变),挂 hello 脚本
    # 让 run_project 的调试输出闭环从第一秒可验证。uid 字段故意不写:
    # 引擎首次打开自动分配并回写,手造 uid 有撞号风险
    cat > "$PROJ/scenes/main.tscn" <<'EOF'
    [gd_scene load_steps=2 format=3]

    [ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]

    [node name="Main" type="Node2D"]
    script = ExtResource("1_main")
    EOF

    cat > "$PROJ/scripts/main.gd" <<'EOF'
    extends Node2D

    # 入口脚本:run_project 调试输出闭环的最小可跑验证
    func _ready() -> void:
    	print("main scene ready: ", ProjectSettings.get_setting("application/config/name"))
    EOF

    # Linux 导出预设:格式经 4.7.2 实测导出+运行验证,三个坑(全踩过):
    #   - platform 必须是 "Linux"(4.3 起),"Linux Desktop" 是 UI 显示名,
    #     配置里写它 → load_config 匹配不到平台静默跳过(零报错零 preset,
    #     只留一句 Invalid export preset name)
    #   - include_filter/exclude_filter 必写:loader 无默认值 get_value,
    #     缺键直接 ERROR Cannot export
    #   - binary_format/architecture 是普通字符串 "x86_64",别被 4.2 多架构
    #     导出的 PackedStringArray 误导 —— ConfigFile 写 PSA 文本进来,
    #     导出时会整串拼进模板名 linux_release.["x86_64"] 找不到文件
    # 可选键(export_filter 的 patches/encrypt 等)省略安全:loader 全有默认
    cat > "$PROJ/export_presets.cfg" <<EOF
    [preset.0]

    name="Linux"
    platform="Linux"
    runnable=true
    dedicated_server=false
    custom_features=""
    export_filter="all_resources"
    include_filter=""
    exclude_filter=""
    export_path="builds/$1.x86_64"
    encryption_include_filters=""
    encryption_exclude_filters=""
    encrypt_pck=false
    encrypt_directory=false
    script_export_mode=2

    [preset.0.options]

    custom_template/debug=""
    custom_template/release=""
    binary_format/embed_pck=false
    texture_format/s3tc_bptc=true
    texture_format/etc2_astc=false
    binary_format/architecture="x86_64"
    EOF

    echo '{"mcp": ["godot-mcp"]}' > "$PROJ/.agents/manifest.json"

    cat > "$PROJ/AGENTS.md" <<'EOF'
    # 游戏项目约定(Godot 4.x)

    - 反馈闭环:改 .gd/.tscn 后用 godot-mcp 的 run_project(-d 调试模式,
      开真窗口)跑起来 → get_debug_output 读 stdout/stderr(脚本解析错/
      运行时报错直接回流)→ 修复 → 重跑。这比静态检查可靠,是本项目的主
      验证手段
    - run_project 上游写死 -d 无 headless 开关,总会开窗口;无人值守验证
      用 godot --headless --import(资产导入)+ godot --headless
      --check-only --script <路径>(GDScript 语法)组合
    - .tscn/.tres/.god 是文本格式:直接读写文件是合法且常用的操作(比
      Blender 的 .blend 二进制生态强一个量级),但 uid:// 引用不手改 ——
      用 get_uid 工具查,手改错位 = 场景引用断链且报错位置离谱
    - 改动/新增资产(png/glb/字体/音频)后必须先 godot --headless --import
      再 --export-release,否则导出烘焙的是 .godot/ 里的旧导入缓存
    - 导出:godot --headless --export-release "Linux" --path <项目根>;
      出口在 builds/<name>.x86_64,导完核对文件存在且 mtime 更新才算完成
    - 永远不要点编辑器里"管理导出模板 → Download and Install":模板由
      nix symlink 提供(~/.local/share/godot/export_templates → /nix/store
      只读),按钮必失败;模板升级 = 升级 nixpkgs pin,原子换代,无需手动装
    - .godot/ 是导入缓存(.gitignore 已列),可随时删,重建 = 一次
      --headless --import
    - godot-mcp 场景工具(create_scene/add_node/load_sprite/save_scene)
      适合脚手架级操作与拿不准格式时的探路;批量结构改动直接编辑 .tscn
      文本更快,改完 run_project 或编辑器打开验证
    - 新资产放 assets/<分类>/,场景在 scenes/、脚本在 scripts/,资源引用
      统一 res:// 前缀;脚本 attach 走 .tscn 的 ExtResource 引用
    - Godot API 拿不准时先查 context7(godotengine 文档在列)再写,
      不要凭记忆编
    EOF

    cat > "$PROJ/.gitignore" <<'EOF'
    .godot/
    builds/
    EOF

    # LFS track 从第一提交就位(同 3d-init 动机:事后 migrate 要重写历史,
    # 贵);游戏二进制资产同样 diff 无意义,走指针+去重
    cat > "$PROJ/.gitattributes" <<'EOF'
    *.png filter=lfs diff=lfs merge=lfs -text
    *.ogg filter=lfs diff=lfs merge=lfs -text
    *.wav filter=lfs diff=lfs merge=lfs -text
    *.glb filter=lfs diff=lfs merge=lfs -text
    *.ttf filter=lfs diff=lfs merge=lfs -text
    EOF

    git -C "$PROJ" init -q
    git lfs install >/dev/null 2>&1 || true # 本机全局钩子,幂等;缺 lfs 不挡建项目
    echo "created: $PROJ"
    echo "next: cd $PROJ && agent sync   # 启用 godot-mcp(opencode renderer)"
  '';
in
{
  home.packages = lib.mkIf (!isRehearsalVm) (
    with pkgs;
    [
      # godot_4 别名钉主版本(nixpkgs 换默认大版本不随波);bin 名 = godot
      godot_4
      # Coding-Solo MCP server(nixpkgs 收编);GODOT_PATH 不设:上游探测
      # 顺序 PATH 里裸名 godot 排第一,与本 profile 同源即中
      godot-mcp
      initGame
    ]
  );

  # 导出模板 symlink:HM 建 ~/.local/share/godot/export_templates → store。
  # Godot 只读此树,引擎自己的 editor_data(~/.local/share/godot/ 其余
  # 子目录)不受影响。mkIf 提到 attrset 层:.source 上挂 mkIf 时条件为
  # false 会留下"已声明无值"的 option,xdg 模块仍强制求值 → eval 报错
  # (flake check 夹具主机上实证)
  xdg.dataFile = lib.mkIf (!isRehearsalVm) {
    "godot/export_templates".source =
      "${pkgs.godot_4-export-templates-bin}/share/godot/export_templates";
  };
}
