# providers-schema 的守护测试(挂 flake checks,`nix flake check .` 触发)
#
# 守护对象 = schema 里唯一无法被类型系统自证的部分:
#   删 throwIf → 一致性静默失效;删 deepSeq → 形状检查退化为惰性。
# 两者都是"看起来无害"的重构(没输出、像句废话),恰好是测试哲学里
# "类型系统覆盖不了的属性"。
#
# 断言用浅 tryEval 且不包外层 deepSeq:浅层求值只触发 schema 内部的
# 强制(deepSeq/throwIf 都在输出 WHNF 之前发生)。若内部 deepSeq 被删,
# 类型坏数据会浅层通过 → 期望 throw 的用例失败 → 回归被察觉。
# 一旦外面包 deepSeq,强制发生在测试侧,内部删除就测不出来了。
pkgs: lib:
let
  schema = import ./providers-schema.nix;

  # 测试数据自解释,不从真实数据派生(真实数据变化不该牵动测试)
  thinkingBlock = {
    default = "high";
    levels = { off = null; high = "adaptive"; };
  };
  baseModel = {
    contextWindow = 128000;
    maxOutput = 8192;
  };

  cases = [
    {
      # 一致性层:shape 合法,只有 throwIf 能拦(删 throwIf 会漏)
      name = "default 越档";
      expect = "throw";
      data = {
        p.endpoints.anthropic = "https://e";
        p.apiKey.secretFile = "/run/secrets/x";
        p.models."m1" = baseModel // { thinking.anthropic = thinkingBlock // { default = "max"; }; };
        p.defaultModel = "m1";
      };
    }
    {
      name = "defaultModel 悬空";
      expect = "throw";
      data = {
        p.endpoints.anthropic = "https://e";
        p.apiKey.secretFile = "/run/secrets/x";
        p.models."m1" = baseModel;
        p.defaultModel = "m2";
      };
    }
    {
      name = "thinking 挂幽灵端点";
      expect = "throw";
      data = {
        # 只有 openai 端点,thinking 却声明在 anthropic 上
        p.endpoints.openai = "https://e";
        p.apiKey.secretFile = "/run/secrets/x";
        p.models."m1" = baseModel // { thinking.anthropic = thinkingBlock; };
        p.defaultModel = "m1";
      };
    }
    {
      # deepSeq 层:一致性代码只读 models 的 attrNames,不触碰字段值,
      # 此类型错误唯有 deepSeq 能前移(删 deepSeq 会漏)
      name = "contextWindow 类型错";
      expect = "throw";
      data = {
        p.endpoints.anthropic = "https://e";
        p.apiKey.secretFile = "/run/secrets/x";
        p.models."m1" = baseModel // { contextWindow = "128k"; };
        p.defaultModel = "m1";
      };
    }
    {
      # happy path:防 schema 过严误伤合法声明
      name = "合法最小 provider";
      expect = "ok";
      data = {
        p.endpoints.anthropic = "https://e";
        p.apiKey.secretFile = "/run/secrets/x";
        p.models."m1" = baseModel // { thinking.anthropic = thinkingBlock; };
        p.defaultModel = "m1";
      };
    }
  ];

  run = c:
    let r = builtins.tryEval (schema lib c.data); in
    lib.optional (r.success != (c.expect == "ok"))
      "「${c.name}」期望${c.expect},实际${if r.success then "通过" else "被拒"}";

  failures = lib.concatMap run cases;
in
lib.throwIf (failures != [ ])
  ("providers-schema 守护测试失败:\n  " + lib.concatStringsSep "\n  " failures)
  (pkgs.runCommand "providers-schema-check" { } "touch $out")
