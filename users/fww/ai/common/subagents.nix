# 跨端子 agent 定义(意图级,中立层)
#
# schema 最小集:只收"换一个客户端也必须一致"的字段——
#   description  委派路由信号,注入所有会话的 system prompt,多端必须逐字一致
#   model        意图不拼写:{ provider = common.providers 键; model = 模型 id }
#               各端翻译成自己的引用格式(zcode: custom:<urlencoded>;opencode: <provider-id>/<model>)
#   prompt       正文,单一真源
#
# 端特有字段(mode/color/steps/tools 白名单等)不进本层:在适配器按 agent 名挂
# extras,common 不知道有哪些客户端。判据:"换客户端还需要存在吗?"——需要才进
# (能力型,如 vision);端工作流型留适配器。
#
# 静默漂移是对账动机:providers 配错是响的(404),子 agent 的 prompt/模型漂移
# 无任何报错,两端各自正常只是行为渐偏 —— 必须同源。
# codex 不消费本层:主模型自带多模态,无识图委派需求(客户端能力,决策在适配器)。
{
  # 识图子 agent:MiniMax M3 原生视觉(GLM 无视觉)
  # 消费端:opencode(frontmatter)、zcode(结构化定义)
  vision = {
    description = "识图专用视觉 agent:OCR 转录、报错截图诊断、UI 审查与设计稿对比、图表读数、架构图解读。主模型无视觉,凡图像/截图理解一律委托本 agent";
    model = {
      provider = "minimax";
      model = "MiniMax-M3";
    };
    prompt = ''
      你是视觉分析专家。

      职责与准则:

      - **精确转述,不脑补**:只报告图像中确实可见的内容。文字、数字、颜色、布局要逐字/如实引用,不确定就说不确定。
      - **场景适配输出**:
        - 报错截图 → 完整转录错误文本 + 指出关键行
        - UI 截图 → 布局结构、组件状态、异常元素(溢出/遮挡/错位)
        - 图表/数据 → 数值与趋势的精确读数
        - 设计稿对比 → 差异清单,按显著度排序
      - **多图任务**:逐图分析再给汇总,保持图序与指代清晰。
      - **输出语言**跟随用户提问语言;引用界面文字时保留原文,不翻译。
      - 你是只读分析者:不改文件、不跑命令,专注把"看见的"变成"可用的文字"。
    '';
  };
}
