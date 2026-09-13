# 模型能力数据来源：opencode models zhipuai-coding-plan --verbose
{
  zhipu = {
    # 各 agent 按自己使用的协议取对应 endpoint
    endpoints = {
      anthropic = "https://open.bigmodel.cn/api/anthropic"; # Claude Code 等
      openai = "https://open.bigmodel.cn/api/coding/paas/v4"; # opencode 等(chat completions)
      responses = "https://open.bigmodel.cn/api/v1"; # codex 等(responses API,见 docs.bigmodel.cn/cn/coding-plan/tool/codex)
    };
    apiKey.secretFile = "/run/secrets/zhipu_api_key";
    models =
      let
        # glm-5.3 与 glm-5.3-highspeed 共体:Highspeed 是高速档变体(同家族
        # 另有 glm-5.2-highspeed),能力与 glm-5.3 完全一致 —— 引用同一
        # attrset,数据永不漂移
        glm53 = {
          contextWindow = 1000000;
          maxOutput = 131072;
          supportsVision = false;
          # 思考控制(按端点独立;default = 省略参数时端点行为,官方文档+实测):
          # anthropic(Claude Code 通路): wire = thinking.type=adaptive +
          #   output_config.effort,实档仅 low/high/max;medium→high、xhigh→max
          #   官方自动转换不单列;GLM-5.3 强制思考,disabled 被端点转 low(无法真关)
          #   (2026-08-21 差分实测:low→0 思考块/high 1491 字/max 2333 字)
          # openai(coding paas): wire = thinking.type=enabled + reasoning_effort
          #   (官方 API 文档;2026-08-21 mainland 端点差分实测生效:
          #   low→0 reasoning tokens/max→322,推翻 6 月 z.ai 国际端"无效"
          #   的 glm-for-copilot#7 结论 —— 那是不同端点且可能已修);
          #   GLM-5.3 仅 low/high/max(none/minimal 是 5.2 语义),无 off
          # responses(/api/v1): wire = reasoning.effort(Responses API);
          #   档位同 openai,来源 = 官方 codex 接入文档(codex.nix 同源消费)
          thinking = {
            anthropic = {
              default = "max";
              levels = {
                off = "disabled"; # 端点转 low 轻思考(5.3 不能真关)
                low = "low";
                high = "high";
                max = "max";
              };
            };
            openai = {
              default = "max";
              levels = {
                low = "low";
                high = "high";
                max = "max";
              };
            };
            responses = {
              default = "max";
              levels = {
                low = "low";
                high = "high";
                max = "max";
              };
            };
          };
        };
      in
      {
        "glm-5.3" = glm53;

        # GLM-5.3 Highspeed:glm-5.3 的高速档(models.dev 与 opencode2
        # beta-18684 内置目录均已收录,标 text-only/1M/131072/思考常开
        # low-high-max,逐字段同 glm-5.3),同端点同套餐;思考 wire 未
        # 独立实测,沿 5.3 侧结论
        "glm-5.3-highspeed" = glm53;

        # GLM-5.3-Flash(2026-08-26 发布)≈ 8/20-27 stealth 预览"Ox Alpha"真身
        # (OpenRouter stealth/ox-alpha / OpenCode Zen x-preview-f-free;tokenizer
        #  指纹恒 +75 偏移、[1210] 错误码契约、视频编码器三参数、泄露的
        #  com.wd.paas 堆栈四处证据指向 Z.ai,Z.ai 8/26 向 Bloomberg 确认 GLM 系)
        # 架构:总参 320B/激活 18B/45 层(对比 glm-4.5:355B/32B/92 层),首个
        #  稀疏+线性注意力混合架构的开源前沿模型(IndexPool 4 缓存向量压 1
        #  + mHC);较 glm-5.3 注意力计算量 ↓3.01x、KV 缓存 ↓4.44x;
        #  国产芯片集群 + EPD 分离式推理(端到端较基线 3x)
        # 能力:GLM-5 系首个原生多模态(图/视频/文件输入),视觉进 coding 闭环
        #  (前端/游戏/Blender/CAD 复刻-渲染-检查迭代;BUA/CUA),Office 成品
        #  交付(PPTX/PDF/DOCX/XLSX 带渲染自检),金融/法律工作流,视频理解剪辑
        # 套餐:已全量进 Coding Plan,额度 = glm-5.3 的 3 倍(新版积分制,非高峰
        #  时段仅耗 50% 积分)—— 轻任务/高并发首选,重活仍走 glm-5.3
        # 官方推荐参数:temperature 1 / top_p 0.95 / reasoning_effort max /
        #  clear_thinking false / stream+tool_stream 同开
        "glm-5.3-flash" = {
          contextWindow = 1000000; # 官方文档:文本参数与 glm-5.3 一致,支持 1M
          maxOutput = 131072;
          supportsVision = true;
          # 思考常开:thinking.type 仅 enabled 不能关(ox 期发 disabled/none 即
          # [1210] 拒绝);档位仅 low/high/max,同 glm-5.3。
          # 三端点 wire 与 glm-5.3 同源(同端点设施),anthropic disabled 端点
          # 转 low 的行为沿 5.3 侧 2026-08-21 实测结论,flash 未独立复测
          thinking = {
            anthropic = {
              default = "max";
              levels = {
                off = "disabled"; # 端点转 low 轻思考(flash 同 5.3 不能真关)
                low = "low";
                high = "high";
                max = "max";
              };
            };
            openai = {
              default = "max";
              levels = {
                low = "low";
                high = "high";
                max = "max";
              };
            };
            responses = {
              default = "max";
              levels = {
                low = "low";
                high = "high";
                max = "max";
              };
            };
          };
        };
      };
    defaultModel = "glm-5.3";
    smallModel = "glm-5.3"; # opencode 标题生成等轻任务用(与 defaultModel 同款,5.2 已下线)
  };

  # MiniMax Token Plan(官方名,非 coding plan):订阅 Key(sk-cp- 前缀)与按量 Key 不通用,
  # 仅推理端点可用(models 列表 401);国内域 minimaxi.com,国际版是 minimax.io(勿混)
  # anthropic 端点官方推荐(有 prompt cache 主动缓存,支持 thinking/interleaved thinking,
  # M3 thinking 默认关需 {"type":"adaptive"} 显式开);温度建议 1.0,top_p 默认 0.95
  # 额度:5 小时+周双窗口;maxOutput 128K 出自 models.dev,官方模型表只列 context 1M
  minimax = {
    endpoints = {
      anthropic = "https://api.minimaxi.com/anthropic"; # Claude Code 等
      openai = "https://api.minimaxi.com/v1"; # opencode 等(chat completions)
      responses = "https://api.minimaxi.com/v1"; # codex 等(responses API,与 openai 同 base 不同路由,均实测通)
    };
    apiKey.secretFile = "/run/secrets/minimax_api_key";
    models = {
      "MiniMax-M3" = {
        contextWindow = 1000000;
        maxOutput = 128000;
        supportsVision = true;
        # 思考控制(按端点独立;default = 省略参数时端点行为,官方文档):
        # 三端点默认各不相同 —— anthropic 省略=关、openai 省略=开、
        # responses 省略=关(官方三段 Thinking/reasoning 控制原文),
        # 跨端点迁移时最易踩的坑
        # anthropic: adaptive=开/disabled=关;无 effort 档(与 glm 的
        #   output_config.effort 语义不同);Claude Code 内默认开是客户端
        #   行为(Claude Code 主动发参数),裸 SDK 省略即关
        # openai: 另有 reasoning_split 只控输出拆分(reasoning_content/
        #   reasoning_details)不控开关;M2.x 系列不可关(非本路由模型,备注)
        # responses: wire = reasoning.effort;none=关(默认),
        #   minimal/low/medium/high 兼容接收但**不调深度**(纯开关)——
        #   单开档取 low(最弱语义,不虚标深度);effort=none 显式关
        thinking = {
          anthropic = {
            default = "off";
            levels = {
              off = null; # 不发参数 = 关(端点默认)
              on = "adaptive";
            };
          };
          openai = {
            default = "on";
            levels = {
              off = "disabled";
              on = "adaptive";
            };
          };
          responses = {
            default = "off";
            levels = {
              off = "none";
              low = "low"; # 四个开启值等价,low 语义最弱不虚标
            };
          };
        };
      };
    };
    defaultModel = "MiniMax-M3";
  };

  # SiliconFlow(硅基流动):OpenAI 兼容平台,代金券抵扣
  # 唯一消费者 jcode 已移除(其 embedding backend 硬编码读 OPENAI_API_KEY),
  # 暂留数据与 key 待复用;长期无消费者则连同 secret 一并删
  siliconflow = {
    endpoints.openai = "https://api.siliconflow.cn/v1";
    apiKey.secretFile = "/run/secrets/siliconflow_api_key";
    embedding = {
      model = "Qwen/Qwen3-Embedding-8B"; # MTEB 榜首;代金券覆盖
      dim = 4096;
    };
  };
}
