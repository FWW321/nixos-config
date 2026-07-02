# AI agent 公共工具函数
# 不强制使用，各 agent 按需 import
{ lib, pkgs }:

{
  # 从中立 MCP 格式提取 local secret（env var 名 = key，值 = secretFile 路径）
  extractLocalSecrets = servers:
    lib.foldl' (acc: s:
      if s ? local then
        acc // (lib.mapAttrs' (k: v:
          lib.nameValuePair k v.secretFile
        ) (lib.filterAttrs (_: v: v ? secretFile) (s.local.env or { })))
      else acc
    ) { } (lib.attrValues servers);

  # 包装包：symlinkJoin + makeWrapper，secret 通过 env 注入，不冲突 PATH
  mkWrappedPackage = { package, binary, secrets }:
    if secrets == { } then package
    else pkgs.symlinkJoin {
      name = "${binary}-wrapped";
      inherit package;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${binary} \
          ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v:
            "--run 'export ${k}=$(cat ${v})'"
          ) secrets)}
      '';
    };
}
