# filepath: ~/nixos-config/users/fww/ai/dsh/search.nix
# 网页能力(web 缝):search + fetch 两侧,选择器形态(nixdsh README
# 「网页搜索」「网页抓取」节)。
# search 选中 zhipu(FWW321/dsh-web-search-zhipu):web_search_prime MCP,
#   Bearer + 会话握手;零内置配置。
# fetch 选中 zhipu(FWW321/dsh-web-fetch-zhipu):web_reader MCP 委托抓取
#   —— SSRF 面零(抓取在 Zhipu 网络侧,本机只出站 MCP 端点);
#   tool-web fetch:true 保险丝由模块代开。
# exa 备案待命(声明未选中 = 合法,切后端改一个字符串)。
# 凭据:secretFile 声明内桥 —— wrapper 现读文件 export ZHIPU_API_KEY
#   (文件名大写约定;search/fetch/providers 三处声明同 env 同文件去重)。
{ pkgs, inputs, ... }:

{
  programs.dsh = {
    # 能力开关 + provider 选择器二合一;选中才启用,base 的
    # deepseek 后端行随之禁用(无 DEEPSEEK_API_KEY,留着只有死卡)
    webSearch = "zhipu";

    webSearchProviders.zhipu = {
      row = {
        name = "@fww/dsh-web-search-zhipu"; # 行 id 缺省 = web-search-zhipu
        secretFile = "/run/secrets/zhipu_api_key"; # 派生 apiKeyEnv=ZHIPU_API_KEY
        # 其余走包默认:mcpURL=web_search_prime / tool / count=5
      };
    };

    webSearchProviders.exa = {
      row = {
        name = "@tonydua/dsh-web-search-exa";
        secretFile = "/run/secrets/exa_api_key"; # 派生 apiKeyEnv=EXA_API_KEY
      };
    };

    # fetch 缝(对称选择器):委托型 reader,无 SSRF 面
    webFetch = "zhipu";

    webFetchProviders.zhipu = {
      row = {
        name = "@fww/dsh-web-fetch-zhipu"; # 行 id 缺省 = web-fetch-zhipu
        secretFile = "/run/secrets/zhipu_api_key"; # 同 env 同文件,与 search 去重
      };
    };

    # preset:roster 接管(nixdsh README「roster 接管」节)—— farm 全量
    # 重放,shipped standard 本体即带 fetch:true,无需换名 fork(fww 化石
    # 已清)。liangshen:dsh-tui excludedPresets 黑名单,不接管不进 farm。

    # 默认 preset:全局 standard,所有 face 树回落它(tui 不再特化)
    defaultPreset = "standard";

    # 新会话默认权限(宿主组合层行):全局 workspace-write,所有 face 一致
    permissionMode = "workspace-write";
  };
}
