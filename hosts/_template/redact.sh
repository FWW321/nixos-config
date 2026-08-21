#!/usr/bin/env bash
# facter.json 隐私脱敏(幂等,可重复执行)
#
# 背景:仓库公开,而 nixos-facter 无 scrub 选项(上游 #255 拒绝默认脱敏、
# #642 过滤愿望单无进展,0.4.x 无相关 flag)。facter 模块只消费
# PCI/USB vendor:product ID 做推导,序列号/UUID 不参与(REDACTED 后
# 推导等价性已实测:initrd 36 模块/微码/hostPlatform 全一致)。
#
# 用法:
#   ./redact.sh          脱敏(重生成 facter.json 后必跑;幂等)
#   ./redact.sh --check  校验模式:已脱敏则退出 0,否则 1(CI 用)
#
# 覆盖:所有 serial*/uuid 字段值 → "REDACTED"(保留结构,便于 diff 与上游演进)
set -euo pipefail
cd "$(dirname "$0")"

F=.facter.json
[ -f "$F" ] || { echo "no $F here" >&2; exit 2; }

scrub='walk(if type == "object" then with_entries(if ((.key | test("serial"; "i")) or (.key | ascii_downcase == "uuid")) and (.value | type == "string") then .value = "REDACTED" else . end) else . end)'

if [ "${1:-}" = "--check" ]; then
  jq -e "$scrub" "$F" | diff -q - "$F" >/dev/null 2>&1 && { echo "OK: $F already redacted"; exit 0; }
  echo "FAIL: $F contains unredacted serial/uuid values. Run: $0" >&2
  exit 1
fi

jq "$scrub" "$F" > "$F.tmp" && mv "$F.tmp" "$F"
echo "redacted: $F"
