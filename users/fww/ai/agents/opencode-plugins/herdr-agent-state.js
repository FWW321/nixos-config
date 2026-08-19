// herdr agent-state plugin — OpenCode v2 port
//
// 上游 herdr 只带 v1 adapter;v2 plugin API 不兼容,此文件是本地移植,
// 上游发布 v2 版后切回 inputs.herdr 的 src/integration/assets/opencode/。
//
// beta-17577 实测约束(与官方文档不一致处):
//   - 导出形状必须是 {id, setup} 裸对象;不能 import "@opencode-ai/plugin"
//     (本地插件不装 npm 依赖,import 即加载失败)
//   - 配置声明用 v1 单数键 plugin(v2 复数键 plugins 会把 server 打进崩溃循环)
//   - setup 内严禁 await 无限事件流(会堵死激活管线,server 无法完成启动)
//
// 与 v1 版行为等价:向 herdr pane 汇报 agent 会话与 working/blocked/idle 状态,
// 子会话(subagent)事件只投影状态、不抢占 pane 的根会话。
import net from "node:net"

const SOURCE = "herdr:opencode"
const AGENT = "opencode"
let reportSeq = Date.now() * 1000
let requestChain = Promise.resolve()
let reportedRootSessionID

// Track child sessions so their events cannot replace the pane's root session.
// Their user prompts still project state without attaching the child session id.
const childSessions = new Set()
const CHILD_EVENT_STATES = new Map([
  ["permission.asked", "blocked"],
  ["question.asked", "blocked"],
  ["permission.replied", "working"],
  ["question.replied", "working"],
  ["question.rejected", "working"],
])

function nextReportSeq() {
  reportSeq += 1
  return reportSeq
}

function sessionIDFromProperties(properties) {
  return typeof properties?.sessionID === "string" && properties.sessionID
    ? properties.sessionID
    : undefined
}

// v2 session.status = { type: "idle" | "busy" | "retry", ... }
function stateFromSessionStatus(status) {
  const kind = typeof status === "string" ? status : status?.type
  if (kind === "idle") return "idle"
  if (kind === "busy" || kind === "retry") return "working"
  return undefined
}

function request(method, params) {
  const pending = requestChain.then(() => requestOnce(method, params))
  requestChain = pending.catch(() => {})
  return pending
}

function requestOnce(method, params) {
  const paneId = process.env.HERDR_PANE_ID
  const socketPath = process.env.HERDR_SOCKET_PATH

  if (!paneId || !socketPath) {
    return Promise.resolve()
  }

  const socketEndpoint =
    process.platform === "win32" ? `\\\\.\\pipe\\${socketPath}` : socketPath

  const requestId = `${SOURCE}:${Date.now()}:${Math.floor(Math.random() * 1_000_000)
    .toString()
    .padStart(6, "0")}`
  const request = {
    id: requestId,
    method,
    params: {
      pane_id: paneId,
      source: SOURCE,
      agent: AGENT,
      seq: nextReportSeq(),
      ...params,
    },
  }

  return new Promise((resolve) => {
    const client = net.createConnection(socketEndpoint, () => {
      client.write(`${JSON.stringify(request)}\n`)
    })

    const finish = () => {
      client.destroy()
      resolve()
    }

    client.setTimeout(500, finish)
    client.on("data", finish)
    client.on("error", finish)
    client.on("end", finish)
    client.on("close", resolve)
  })
}

function reportSession(sessionID) {
  if (!sessionID) {
    return Promise.resolve()
  }
  return request("pane.report_agent_session", { agent_session_id: sessionID })
}

function reportState(state, sessionID) {
  const params = { state }
  if (sessionID) {
    reportedRootSessionID = sessionID
    params.agent_session_id = sessionID
  }
  return request("pane.report_agent", params)
}

async function handleEvent(event) {
  const type = event?.type
  const properties = event?.properties ?? {}
  const sessionID = sessionIDFromProperties(properties)

  // 子会话识别:v2 仅 session.created/updated 携带完整 info(含 parentID)
  const info = properties.info
  if (info?.id && info.parentID) {
    childSessions.add(info.id)
  }
  if (sessionID && childSessions.has(sessionID)) {
    const state = CHILD_EVENT_STATES.get(type)
    if (state) {
      await reportState(state)
    }
    return
  }

  switch (type) {
    case "session.created":
      // Creation is server-global, so an attached client may own it. The
      // TUI plugin separately reports the root selected in this pane.
      reportedRootSessionID = sessionID
      break
    case "session.updated":
      if (sessionID && sessionID !== reportedRootSessionID) {
        await reportSession(sessionID)
      }
      break
    case "session.status": {
      const state = stateFromSessionStatus(properties.status)
      if (state) {
        await reportState(state, sessionID)
      } else {
        await reportSession(sessionID)
      }
      break
    }
    case "message.updated":
      // 用户消息进入会话 = 开始干活(v1 的 chat.message 等价物;
      // 模型 dispatch 由 session.hook("context") 覆盖)
      if (properties.info?.role === "user") {
        await reportState("working", sessionID)
      }
      break
    case "tool.execute.before":
    case "tool.execute.after":
    case "permission.replied":
    case "question.replied":
    case "question.rejected":
    case "session.compacted":
      await reportState("working", sessionID)
      break
    case "permission.asked":
    case "question.asked":
    case "session.error":
      await reportState("blocked", sessionID)
      break
    case "session.idle":
      await reportState("idle", sessionID)
      break
    case "session.deleted":
      break
    default:
      break
  }
}

export default {
  id: "herdr.agent-state",
  setup: async (ctx) => {
    if (
      process.env.HERDR_ENV !== "1" ||
      !process.env.HERDR_SOCKET_PATH ||
      !process.env.HERDR_PANE_ID
    ) {
      return
    }

    // 模型 dispatch 前 → working(v1 chat.message 的主信号)
    await ctx.session.hook("context", (event) => {
      if (childSessions.has(event.sessionID)) return
      void reportState("working", event.sessionID)
    })

    // 工具执行前后 → working(v1 的 tool.execute.* 事件)
    const toolWorking = (event) => {
      const sessionID = event.sessionID
      if (sessionID && childSessions.has(sessionID)) {
        void reportState("working")
        return
      }
      void reportState("working", sessionID)
    }
    await ctx.tool.hook("execute.before", toolWorking)
    await ctx.tool.hook("execute.after", toolWorking)

    // 公共事件流驱动状态机(setup 内不得 await 无限流,后台消费)
    const controller = new AbortController()
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({
          signal: controller.signal,
        })) {
          await handleEvent(event)
        }
      } catch {
        // 流断开/abort 时静默退出
      }
    })()

    return () => controller.abort()
  },
}
