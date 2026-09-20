// scope-shim.cjs — OpenDesign daemon 子进程卫生 shim(NODE_OPTIONS --require 预加载)
//
// 文件名必须是 .cjs:OD 根 package.json 带 "type": "module",.js 会被当 ESM
// 解析而 require 不可用;--require 只吃 CommonJS。
//
// 问题(2026-09-20 进程考古):daemon 用裸 child_process fork 子进程,cgroup 按
// 出生地继承且 daemon 常驻不重启——凡从 OD 里启动过的常驻进程(容器、postgres、
// electron、setsid 守护)永久堆积在 open-design.service 名下,会话结束也不清。
//
// 本文件是「纯 argv 重定向」:不执行任何进程、不调用任何外部命令,只把每个
// 异步 spawn 的目标改写为同包的 od-scope-exec(收养门)。门以被 spawn 的身份
// 自我收养进命名 scope(od-spawn-*.scope),成员性屏障通过后原位 exec 回真实
// 命令——pid/stdio/cwd/env/退出检测/kill 语义全部原样,命令 fork 出的整棵
// 子树落在 scope 里;命令退出后门的看门狗 sweep 收割 setsid/nohup 出走的
// 孙进程。全部 systemd 交互(busctl/systemctl)都在 shell helper 内完成。
//
// ⚠ node v24 拦截点(2026-09-21 实测,这是本文件成立的前提):ChildProcess
// 构造器把规范化结果放进 options 传给 prototype.spawn —— 命令在
// options.file,参数在 options.args(不含 file 头),环境在 options.envPairs
// (KEY=VALUE 字符串数组)。此时 this.spawnfile 尚为 null、且会在 origSpawn
// 内部被赋值覆盖,options.env 也已被消费 —— 改这两处全是无效靶点,必须改
// options 本身。node 大版本升级若重构此处,shim 会静默失效(症状:无
// od-spawn-*.scope 产生),本头注释即排障入口。
//
// 安全说明:本文件无任何进程执行、无 shell、无字符串进命令行;唯一的动态
// 值是 scope 名(白名单字符构成)与被 spawn 方原生的 file/args 透传。
//
// 边界(刻意不覆盖):
//   - *Sync 变体(spawnSync/execFileSync)走独立 C++ 路径,原型 patch 不及;
//     sync 调用按语义是短探测,泄漏面小
//   - fork()(ipc 通道)旁路:stdio 含 'ipc' 直接放行,门会破坏 IPC fd 传递
//   - exec 失败形态变化:命令不存在时以 exit 127 呈现而非 spawn 'error'
//     (node 原生 ENOENT 事件不再触发);OD 的可执行解析在 spawn 前完成
//     (executables.ts),实际影响面极小
//
// 启用(NIX:modules/home/open-design.nix 注入):
//   NODE_OPTIONS=--require <pkg>/lib/open-design/scope-shim.cjs
//   OD_SCOPE_ROLE=daemon        # 仅 daemon 本进程 patch;子代环境被改写为
//                               # 'child' 防止嵌套 shim(agent CLI 的 bash 工具
//                               # 调用靠 cgroup 继承归入 run scope,不重复开 scope)
// 临时关闭:systemctl --user edit open-design 清掉 NODE_OPTIONS,或
//   OD_SCOPE_ROLE 置非 daemon 值后手动重启单元。
'use strict';

const GATE_ROLE = 'daemon';
const CHILD_ROLE = 'child';
const PREFIX = 'od-spawn';

function sanitizeUnitFragment(s) {
  return String(s).replace(/[^A-Za-z0-9_.-]/g, '_').slice(0, 24) || 'cmd';
}

if (process.env.OD_SCOPE_ROLE !== GATE_ROLE) {
  // 非目标进程(子代 node/bun):什么都不做
} else {
  const fs = require('node:fs');
  const path = require('node:path');
  const ownPid = String(process.pid);

  // 门固定位于本包 bin/ 下(本脚本安装于 <pkg>/lib/open-design/)
  const gate = path.resolve(__dirname, '..', '..', 'bin', 'od-scope-exec');

  if (!fs.existsSync(gate)) {
    console.error(`[${PREFIX}-shim] disabled: gate not found at`, gate);
  } else {
    const ChildProcess = require('node:child_process').ChildProcess;
    const origSpawn = ChildProcess.prototype.spawn;
    let seq = 0;

    ChildProcess.prototype.spawn = function odScopeSpawn(options) {
      // 非常规路径(无规范化 file)与 fork/IPC 通道无法穿门,原样放行
      if (!options || typeof options.file !== 'string') {
        return origSpawn.call(this, options);
      }
      const stdio = options.stdio;
      if (Array.isArray(stdio) && stdio.includes('ipc')) {
        return origSpawn.call(this, options);
      }
      const file = options.file;
      const args = Array.isArray(options.args) ? options.args : [];
      const base = sanitizeUnitFragment(path.basename(file));
      seq += 1;
      const scope = `${PREFIX}-${base}-${ownPid}-${seq}.scope`;
      // envPairs 替换(环境数组里重复键以先出现者为准,必须去旧再添新):
      // ROLE=child 防嵌套,NAME 告知门自己的 scope 名
      const pairs = (Array.isArray(options.envPairs) ? options.envPairs : [])
        .filter((pair) => !pair.startsWith('OD_SCOPE_ROLE=') && !pair.startsWith('OD_SCOPE_NAME='));
      pairs.push(`OD_SCOPE_ROLE=${CHILD_ROLE}`, `OD_SCOPE_NAME=${scope}`);
      // 纯 argv 重定向:门收到 [file, ...args],屏障后原位 exec 回真实命令
      return origSpawn.call(this, {
        ...options,
        file: gate,
        args: [file, ...args],
        envPairs: pairs,
      });
    };

    console.error(`[${PREFIX}-shim] enabled (pid ${ownPid}): spawns gated → ${PREFIX}-*.scope`);
  }
}
