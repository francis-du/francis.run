---
title: "wcode：MCP 负责能力，Skill 只负责工作习惯"
date: 2026-08-26T03:16:00+08:00
draft: false
url: /blog/wcode-mcp-agent/
description: "我后来把两件事分开了：MCP 决定 Agent 真正能做什么，Skill 只告诉它我希望它按什么顺序做。"
tags:
  - MCP
  - AI Agent
  - wcode
  - Rust
images: []
---

第一版 wcode 基本是围着 MCP 写的。

那时候最核心的问题是：Web 端模型怎么安全访问本地代码。

现在 Software Intelligence、Verification、Reconciliation 都长出来以后，MCP 在项目里的位置反而更简单了。

它就是能力接口。

## 本地 Agent 没必要绕公网

如果 Agent 本身就在本机，比如 Claude Code、Codex、Grok Build 这类，没必要为了调用本地仓库先走一圈 Tunnel 和 OAuth。

直接：

```bash
wcode --workspace /absolute/path/to/repository mcp-stdio
```

stdio 和 HTTP 后面没有两套业务实现。

最终用的还是同一个：

```text
Workspace
Harness
Software Intelligence
Verification / Evidence
Tools
Prompts
Resources
Tasks
```

Transport 不一样，能力边界应该一样。

这件事我比较在意，因为很多工具做到后面会出现“本地模式一套，Remote 模式另一套”，最后修安全问题要修两遍。

## Web / Cloud 还是 HTTP + OAuth

ChatGPT、Grok Web、Claude Web 这类产品从云端访问本机，还是需要公网可达地址。

所以第一版里的 Streamable HTTP、OAuth、PKCE、Resource Binding、Quick Tunnel 都还在。

这些底层细节我在 [第一版文章](/blog/wcode/) 写过，这里不展开。

后面主要补的是协议兼容和长任务。

现代 MCP 请求可以声明 Tasks Extension。现在只把确实可能很慢的操作做成 Durable Task，例如：

```text
semantic_provider_refresh
verification_execute_stages
```

客户端声明 Tasks，就可以拿 Handle 后轮询；不声明，仍然走同步调用。

我不想为了跟最新协议，把还能正常工作的客户端全部逼着一起升级。

## Tool 现在也带 Product Scope 信息

这块是后来才加的。

wcode 自己的能力已经很多，如果 Agent 只看到几十个 Tool Name，很容易把它们理解成一张平面列表。

现在 Product Scope Registry 会同时用于源码分区、`software_context`、Semantic Scope 和 MCP Tool Metadata。

也就是说，Agent 不只知道有个 `risk_status`，还可以发现它属于哪些 Product Scope；`scope_status` 也能直接看当前仓库源码映射和未归类文件。

这不是为了给 Tool 多加标签。

主要是让 Agent 在开始做事之前先知道“我现在在哪个能力边界里”，不要动不动就全仓库搜索。

## Skill 不应该偷偷带执行权限

现在可以导出一个 Agent Plugin / Skill：

```bash
wcode --workspace "$PWD" agent-plugin --output wcode-agent-plugin
```

目录很小：

```text
wcode-agent-plugin/
├── plugin.json
├── .claude-plugin/
│   └── plugin.json
├── README.md
└── skills/
    └── wcode-software-intelligence/
        └── SKILL.md
```

我故意没往里面塞 Hook、JS/Python Script、Credential，也没把 Workspace 配置偷偷写进去。

我后来把这个边界总结成一句很普通的话：

```text
Skill = workflow
MCP = capability
```

Skill 可以告诉 Agent 我希望它先做：

```text
workspace_info
scope_status
design_status
project_context
software_context(scopes=...)
```

修改以后再走 Review、Impact、Risk、Verification。

但 Skill 自己不能因为“装上了”就突然得到 Shell、删除文件或者运行仓库程序的权限。

权限还是 Runtime 的事。

## Workspace 我一直要求显式

持久化 Agent 配置里，我更推荐写绝对路径：

```bash
wcode --workspace /absolute/path/to/repository mcp-stdio
```

而不是让 Plugin 根据当前 `cwd` 自动猜仓库。

这不是审美问题。

Agent 从子目录启动、Plugin 自己有工作目录、IDE 改了 Project Root，这些情况都很常见。自动向上找父目录一旦找错，影响的是权限边界，不只是路径显示不好看。

所以 Workspace 是 wcode Runtime 的显式参数。

Skill 不替我决定。

## 授权也不交给 Skill

现在 wcode 对高风险执行和删除都有本地 Authorization Flow。

例如一个 Language Server Refresh 如果没有预先通过 `--allow-risky-exec` 放开，可以先产生 Authorization Request；我在 TUI 里批准后，Agent 再重试。

Delete 则是 exact one-shot approval。

这些动作 Skill 都不会自动替我确认。

我觉得这一点很重要：Skill 可以告诉 Agent“遇到授权就说明原因并等待人处理”，但它不能为了让流程顺滑，顺手把信任边界也一起扩大。

## 换模型这件事因此变得没那么重

以前我会比较在意某个 Agent 有没有自己独特的 Memory、Rule、Project Context。

现在当然还是会在意模型能力，但项目状态不太想绑在它身上了。

Verification Plan、Evidence、Reconciliation、Graph History、Semantic Registry 这些长期状态都留在 wcode。

一个 Agent 只要能调用 MCP，就能接同一个 Workspace；安装同一份 Skill，只是更容易遵循同一套工作习惯。

从 Claude 换到 Codex，或者 Web 端换成本地 Agent，模型上下文会变，但项目本身不应该跟着清零。

这也是我现在比较满意的一点：MCP 没有越做越大，反而被压回了它最合适的位置。

最后还是会回到最底层的问题：这些 Agent 到底能在我的机器上做什么。Workspace、命令执行和授权的边界，我单独写在 [我还是不想给 Agent 一个 Shell](/blog/wcode-security/) 里。