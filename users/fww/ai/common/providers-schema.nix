# 中立 provider 数据的 schema + 一致性检查
# 接线(common/default.nix): providers = import ./providers-schema.nix lib (import ./providers.nix)
#
# 三步缺一不可:evalModules(形状)→ 一致性(跨字段)→ deepSeq(全量严格化)。
# 设计原则(2026-08-21 grilling 定稿):
#   - 校验不变形:输出 ≡ 输入 + 类型默认值,本文件不是第五个 adapter
#   - 闭集用 option:端点名 = 消费者的协议词汇表(dsh 只说 anthropic、
#     codex 只说 responses),拼错即报全路径;开集用 attrsOf:供应商/
#     模型/档名 = 现实世界自由命名(off/on/none/low/high/max...),不 enum
#   - 一致性检查每条绑定一个真实失败模式,不防御性编程
#   - 结构约束写这里;wire 语义/实测数据写 providers.nix(单一事实源)
#
# 副作用:结构性默认值让 endpoints/thinking/models/apiKey 键恒在
# (未声明 = null/{}),消费者的存在性探测(`?`)语义必须换成值判断
lib: raw:
let
  inherit (lib) mkOption types;

  endpointNames = [ "anthropic" "openai" "responses" ];

  # 档位块:levels 键 = 中立档名(开放集);值 = 端点 wire 拼写,
  # null = "不发参数"(glm/M3 的 anthropic off 档即此义)
  endpointThinking = types.submodule {
    options = {
      default = mkOption {
        type = types.str;
        description = "省略参数时的端点行为档名;须为 levels 键(一致性检查)";
      };
      levels = mkOption {
        type = types.attrsOf (types.nullOr types.str);
        description = "中立档名 → 端点 wire 拼写;null = 不发参数";
      };
    };
  };

  modelType = types.submodule {
    options = {
      contextWindow = mkOption {
        type = types.ints.positive;
        description = "必填:codex/zcode 无条件读取";
      };
      maxOutput = mkOption {
        type = types.ints.positive;
        description = "必填:同上";
      };
      supportsVision = mkOption {
        type = types.bool;
        default = false;
      };
      thinking = {
        anthropic = mkOption { type = types.nullOr endpointThinking; default = null; };
        openai = mkOption { type = types.nullOr endpointThinking; default = null; };
        responses = mkOption { type = types.nullOr endpointThinking; default = null; };
      };
    };
  };

  providerType = types.submodule {
    options = {
      endpoints = {
        anthropic = mkOption { type = types.nullOr types.str; default = null; };
        openai = mkOption { type = types.nullOr types.str; default = null; };
        responses = mkOption { type = types.nullOr types.str; default = null; };
      };
      apiKey.secretFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "null = 无鉴权端点(本地推理 provider 预留)";
      };
      models = mkOption {
        type = types.attrsOf modelType;
        default = { };
      };
      defaultModel = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "models 非空时必填(一致性检查)";
      };
      smallModel = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "轻任务档(端无关的通用模式);须为 models 键(一致性检查)";
      };
      embedding = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            model = mkOption { type = types.str; };
            dim = mkOption { type = types.ints.positive; };
          };
        });
        default = null;
      };
    };
  };

  # ── 第一步:形状。submodule 拒收未声明键,字段拼写错误在这里死,
  # 报错带全路径:"The option `providers.zhipu.models.glm-5.3.contextWindw' does not exist."
  shape =
    (lib.evalModules {
      modules = [
        { options.providers = mkOption { type = types.attrsOf providerType; }; }
        { providers = raw; }
      ];
    }).config.providers;

  # ── 第二步:一致性。submodule 看不到自己的键名,带路径的报错只能在这层做;
  # 违约先积累后一次报全,不逐个 throw
  violations =
    let
      # 自闭包读模型(而非收 m 参数):保证 map/concatMap 喂到 name/p/mid
      # 后没有残余函数参 —— 四参版在 map 下会残留半个 lambda 混进列表
      perModel = name: p: mid:
        let m = p.models.${mid}; in
        lib.concatMap
          (ep:
            let t = m.thinking.${ep}; in
            lib.optionals (t != null) (
              (lib.optional (p.endpoints.${ep} == null)
                "${name}.models.${mid}: 声明了 thinking.${ep},但 provider 无 ${ep} 端点")
              ++ (lib.optional (t.levels == { })
                "${name}.models.${mid}.thinking.${ep}: levels 为空")
              ++ (lib.optional (!(builtins.hasAttr t.default t.levels))
                "${name}.models.${mid}.thinking.${ep}: default \"${t.default}\" 不在 levels(${lib.concatStringsSep "," (builtins.attrNames t.levels)})中")
            ))
          endpointNames;
      perProvider = name: p:
        let modelIds = builtins.attrNames p.models; in
        (lib.optional (modelIds != [ ] && lib.all (ep: p.endpoints.${ep} == null) endpointNames)
          "${name}: 有 models 但三端点全无")
        ++ (lib.optional (modelIds != [ ] && p.defaultModel == null)
          "${name}: 有 models 但无 defaultModel")
        ++ (lib.optional (p.defaultModel != null && !(lib.elem p.defaultModel modelIds))
          "${name}: defaultModel \"${p.defaultModel}\" 不是 models(${lib.concatStringsSep "," modelIds})的键")
        ++ (lib.optional (p.smallModel != null && !(lib.elem p.smallModel modelIds))
          "${name}: smallModel \"${p.smallModel}\" 不是 models 的键")
        # concatMap(不是 map):perModel 返回字符串列表,这里必须压平,
        # 否则嵌套空列表让 violations != [] 恒真 → 无差别 throw
        ++ lib.concatMap (perModel name p) modelIds;
    in
    lib.concatLists (lib.mapAttrsToList perProvider shape);
in
# ── 第三步:deepSeq 全量严格化(module system 惰性,不逼到底,
# 校验覆盖就取决于消费者碰巧读了哪些字段)+ 违约总报
lib.throwIf (violations != [ ])
  ("中立 provider 数据违约(common/providers.nix):\n  " + lib.concatStringsSep "\n  " violations)
  (builtins.deepSeq shape shape)
