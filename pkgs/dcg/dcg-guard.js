// filepath: ~/nixos-config/pkgs/dcg/dcg-guard.js
// opencode plugin adapter for dcg (Destructive Command Guard).
//
// 来源:aspiers/ai-config (.config/opencode/plugins/dcg-guard.js) 社区桥接
// dcg 无官方 opencode plugin(自身只支持 Claude Code PreToolUse JSON 协议);
// opencode 的 plugin 系统是纯进程内 JS,所以这里手动 spawn dcg 做协议翻译。
// ~40 行,协议稳定,直接内联进 pkgs/dcg 避免依赖无关 dotfiles repo。
//
// 协议:stdin 送 {"tool_name","tool_input"};dcg stdout 空=放行,
// 含 hookSpecificOutput.permissionDecision==="deny"=拦截(throw 中止 tool 调用)。

export const DcgGuard = async () => {
  const dcg = Bun.which("dcg");
  if (!dcg) return {};

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return;
      const payload = JSON.stringify({
        tool_name: "Bash",
        tool_input: { command: output.args.command },
      });
      const proc = Bun.spawn([dcg], {
        stdin: "pipe",
        stdout: "pipe",
        stderr: "pipe",
        env: { ...process.env, DCG_ROBOT: "1" },
      });
      proc.stdin.write(payload);
      proc.stdin.end();
      const [, out] = await Promise.all([
        proc.exited,
        new Response(proc.stdout).text(),
      ]);
      const last = out.trimEnd().split("\n").pop();
      if (!last) return;
      const result = JSON.parse(last);
      if (result?.hookSpecificOutput?.permissionDecision === "deny") {
        const reason =
          result.hookSpecificOutput.permissionDecisionReason ??
          "blocked by dcg";
        throw new Error(reason);
      }
    },
  };
};
