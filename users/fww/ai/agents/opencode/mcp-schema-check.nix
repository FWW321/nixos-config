# opencode2 MCP 渲染守护(挂 flake checks,`nix flake check` 构建运行)
#
# 守护对象 = 注释无法守护的版本依赖事实:opencode2 对 mcp.servers.<n> 的
# schema 是移动靶 —— beta 认 timeout、2.0.11~2.0.16 stable 拒收(带此键的
# server 整条被静默丢弃,仅日志一行 kind=invalid,2026-09-25 open-design
# MCP 失踪事故根因)、dev 线 schema 又重新收录。字段合法性只活在注释里,
# 版本 bump 后必然再次静默漂移 —— 这里让真二进制说话。
#
# 断言双向:
#   A. 渲染产物(HM 生成的 opencode.json)里每个 server 都在 `mcp list`
#      存活:被 schema 丢弃(诊断 $.mcp.servers.*)或名单缺失 = 红
#   B. timeout 探针与期望(expectTimeoutAccepted)一致:
#      stable 恢复收录时探针被接受 → 红灯 forcing 恢复
#      mcp-project.nix 的 timeout attr + settings.nix 渲染合并,再翻期望
#
# 隔离要点(均有实测出处):
#   - XDG_RUNTIME_DIR 必须指空目录:managed service 的端口锁读真实
#     /run/user/<uid> 时,隔离实例会反复抢真实服务占用的默认口直至超时
#   - `service set port` 写 $XDG_CONFIG_HOME/opencode/service.json;两阶段
#     独立根目录 + 独立端口,互不污染(服务是启动配置快照)
#   - OPENCODE_DISABLE_MODELS_FETCH / FILEWATCHER / PROJECT_CONFIG 全关,
#     nix build 沙箱无网络可跑;server 全部 disabled 化,不 spawn 不读密钥
#   - `mcp list` 输出含头部/空态,取"每行第二列"为名单,名单对不上即红
{
  pkgs,
  lib,
  renderedConfig,
}:
let
  inherit (pkgs) opencode2;

  # 期望 stable 当前对 mcp.servers.<n>.timeout 的态度(2026-09-25 实测
  # 2.0.11~2.0.16 拒收)。stable 恢复之日本检查红灯:恢复渲染后翻 true
  expectTimeoutAccepted = false;
in
pkgs.runCommand "opencode2-mcp-check"
  {
    nativeBuildInputs = [ pkgs.jq ];
    inherit renderedConfig;
    # 探针期望翻面后,提醒同时核对渲染侧已恢复(见 phase B 分支)
    passthru.expectTimeoutAccepted = expectTimeoutAccepted;
  }
  ''
    set -euo pipefail
    OC="${lib.getExe opencode2}"
    JQ="${pkgs.jq}/bin/jq"
    VER="${lib.getVersion opencode2}"

    iso_env() {
      export HOME="$1/home" \
        XDG_CONFIG_HOME="$1/home/.config" \
        XDG_DATA_HOME="$1/home/.local/share" \
        XDG_STATE_HOME="$1/home/.local/state" \
        XDG_RUNTIME_DIR="$1/run" \
        OPENCODE_DISABLE_MODELS_FETCH=1 \
        OPENCODE_DISABLE_FILEWATCHER=1 \
        OPENCODE_CONFIG_PROJECT_DISABLE=1
    }

    iso_root() {
      mkdir -p "$1/home/.config/opencode" "$1/home/.local/share" \
        "$1/home/.local/state" "$1/run"
    }

    fail() { echo "opencode2-mcp-check FAIL ($VER): $*" >&2; exit 1; }

    # ── 阶段 A:真渲染配置全量 disabled 喂给真二进制,名单必须完整存活 ──
    # {file:...} 密钥引用替换为占位串:GET /api/mcp 列举时服务端急切读密钥文件
    # (nix build 沙箱无 /run/secrets → 500,2026-09-25 实测);schema 只验形状
    iso_root "$PWD/phaseA"
    "$JQ" 'walk(if type == "string" and contains("{file:") then "stubbed-secret" else . end)
      | (.mcp.servers // {}) |= map_values(.disabled = true)' \
      "$renderedConfig" > "$PWD/phaseA/home/.config/opencode/opencode.json"
    iso_env "$PWD/phaseA"
    timeout 30 "$OC" service set port 17831 >/dev/null \
      || fail "service set port 失败(隔离环境异常)"

    expected="$("$JQ" -r '.mcp.servers // {} | keys[]' \
      "$PWD/phaseA/home/.config/opencode/opencode.json" | sort)"
    [ -n "$expected" ] || fail "渲染配置里没有任何 mcp server(上游渲染链断了?)"
    want=$(printf '%s\n' "$expected" | wc -l)

    listed=""
    for _ in 1 2 3 4 5; do
      timeout 60 "$OC" mcp list > "$PWD/phaseA/list.txt" 2> "$PWD/phaseA/list.err" || true
      listed="$(awk 'NF>=2{print $2}' "$PWD/phaseA/list.txt" | sort -u)"
      have=$(printf '%s\n' "$listed" | grep -c . || true)
      [ "$have" -ge "$want" ] && break
      sleep 3
    done

    logA="$PWD/phaseA/home/.local/share/opencode/log/opencode.log"
    dropped="$(grep 'kind=invalid' "$logA" 2>/dev/null \
      | grep -o '\$\.mcp\.servers\.[^ "]*' | sort -u || true)"
    [ -z "$dropped" ] \
      || fail "渲染产物被 opencode2 schema 静默丢弃:$dropped(对照 settings.nix toOpenCodeMcp)"
    [ "$listed" = "$expected" ] \
      || fail "mcp list 名单与渲染不符。期望:$(printf '%s ' $expected)实际:$(printf '%s ' $listed);list.err: $(head -c 500 "$PWD/phaseA/list.err" 2>/dev/null);服务日志尾部: $(tail -c 600 "$logA" 2>/dev/null)"

    # ── 阶段 B:timeout 探针 —— 二进制实际行为必须与期望一致 ──
    iso_root "$PWD/phaseB"
    cat > "$PWD/phaseB/home/.config/opencode/opencode.json" <<'PROBE'
    {
      "mcp": {
        "servers": {
          "timeout-probe": {
            "type": "local",
            "command": ["/bin/true"],
            "environment": {},
            "disabled": true,
            "timeout": 120000
          }
        }
      }
    }
    PROBE
    iso_env "$PWD/phaseB"
    timeout 30 "$OC" service set port 17832 >/dev/null \
      || fail "service set port 失败(阶段 B 隔离环境异常)"

    logB="$PWD/phaseB/home/.local/share/opencode/log/opencode.log"
    # 服务 HTTP 就绪早于 MCP 装载完成,首查可能空列表(2026-09-25 实测);
    # 注册(在列)=接受,丢弃(诊断)=拒收,两者都无 = 状态不明,重试后仍无则红
    probeAccepted=""
    for _ in 1 2 3 4 5; do
      timeout 60 "$OC" mcp list > "$PWD/phaseB/list.txt" 2> "$PWD/phaseB/list.err" || true
      listedB="$(awk 'NF>=2{print $2}' "$PWD/phaseB/list.txt" | sort -u)"
      if printf '%s\n' "$listedB" | grep -qx 'timeout-probe'; then
        probeAccepted=true
        break
      elif grep -q 'timeout-probe' "$logB" 2>/dev/null; then
        probeAccepted=false
        break
      fi
      sleep 3
    done
    [ -n "$probeAccepted" ] || {
      fail "timeout 探针状态不明:既未注册也无丢弃诊断\
    (list.txt:$(head -c 200 "$PWD/phaseB/list.txt" 2>/dev/null);\
    log 尾部:$(tail -c 300 "$logB" 2>/dev/null))"
    }

    renderedTimeouts="$("$JQ" -c '[.mcp.servers // {} | to_entries[] | select(.value.timeout? != null) | .key]' "$renderedConfig")"

    if [ "${lib.boolToString expectTimeoutAccepted}" = "false" ]; then
      [ "$probeAccepted" = "false" ] || {
        fail "opencode2 $VER 已重新接受 mcp.servers.<n>.timeout!\
    恢复:common/mcp-project.nix open-design 的 timeout attr + settings.nix \
    toOpenCodeMcp 渲染合并 + 本文件 expectTimeoutAccepted 翻 true\
    (调试:list.txt:$(head -c 200 "$PWD/phaseB/list.txt" 2>/dev/null);\
    cfgB:$(head -c 200 "$PWD/phaseB/home/.config/opencode/opencode.json" 2>/dev/null))"
      }
      [ "$renderedTimeouts" = "[]" ] || {
        fail "stable($VER)拒收 timeout 但渲染仍携带:$renderedTimeouts\
    (settings.nix 的 optionalAttrs 合并应已移除,回归?)"
      }
    else
      [ "$probeAccepted" = "true" ] \
        || fail "期望 timeout 被接受(已翻 expectTimeoutAccepted=true),\
    但 opencode2 $VER 实测拒收 —— 上游回退或版本判断有误,复核"
      [ "$renderedTimeouts" != "[]" ] || {
        fail "期望 timeout 已恢复渲染,但渲染产物里没有任何 server 带 timeout\
    (mcp-project.nix 的 attr 或 settings.nix 合并未恢复?)"
      }
    fi

    echo "opencode2-mcp-check OK ($VER):$(printf '%s ' $expected)"
    touch "$out"
  ''
