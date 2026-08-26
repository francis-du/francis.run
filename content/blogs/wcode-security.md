---
title: "wcode：我还是不想给 Agent 一个 Shell"
date: 2026-08-26T03:17:00+08:00
draft: false
url: /blog/wcode-security/
description: "功能越来越多以后，我反而更确定几条底层边界不能省：Root、Symlink、SHA、原子写入、动态授权，以及不经过 Shell 的命令执行。"
tags:
  - Security
  - Rust
  - MCP
  - wcode
images: []
---

wcode 第一版里，我花时间最多的其实不是 MCP。

是 Workspace。

因为把模型接到本地仓库以后，最危险的从来不是它看错一个函数，而是 Tool Runtime 的边界没守住。

上层现在已经有 Design State、Graph、Reconciliation、Verification，复杂了很多。但越往上加东西，我越不想动底下这几条线。

## Root 不是字符串前缀

最偷懒的 Workspace 隔离大概是：

```text
path.starts_with(workspace_root)
```

这当然不够。

wcode 启动时会先 Canonicalize Root，文件系统根目录、Home 这种过大的范围默认不接受，多个 Workspace 也不能随便父子重叠。

后续文件操作还会重新确认 Root。

Unix 上会记 Device / Inode，所以服务启动以后，如果同一个路径被换成了另一个目录，字符串虽然没变，身份已经变了，也会停下来。

模型传进来的路径只能是相对路径。

`..`、绝对路径、Windows Prefix、受保护的凭据和 VCS 路径，都是 Workspace 层直接挡，不靠 Agent 自觉。

## Symlink 是我早期低估过的坑

只拦 `..` 看起来像是做了 Path Traversal 防护，实际上一个 Symlink 就能把你带出去。

所以 Workspace Path 的 Component 里有 Symlink，直接拒绝。

已有文件和新文件还不能完全用同一种检查方式。

已有文件能解析最终目标；新文件的叶子还不存在，只能先确认父目录安全，再创建。

Unix 上写 Hard Link 也有限制，因为同一个 inode 可能从另一个名字被修改。

这些逻辑写起来比一个 `canonicalize()` 麻烦很多，但这是我不太愿意“简化”的地方。

## SHA 是防 Agent 和我互相踩代码

文件读出来以后，wcode 会给当前 SHA-256。

后面修改已有文件，必须把这个 SHA 带回来。

这个机制最常见的用途不是防攻击，而是防一个很普通的并发场景：Agent 读了版本 A，在它思考时我手动改成了版本 B，它最后还拿 A 的上下文回来写。

没有 SHA，很容易把我的 B 一起覆盖掉。

真正提交写入前还会拿锁、重新解析路径、重新读内容、再校一次 Hash。

最后用同目录临时文件做原子替换，而不是直接 `truncate` 原文件。

这层我实际遇到过几次救命的情况，所以一直保留得很死。

## Delete 后来加了，但故意做得很烦

第一版 wcode 干脆没有 Delete Tool。

后来实际 Coding Workflow 里确实有删除文件的需要，所以最终还是加了 `delete_path`。

但它不是普通 Write。

第一次调用只会产生一个本地 Authorization Request。我要在 TUI 或受保护的 Project Observatory 里批准这个**精确操作**，Agent 再重试。

而且授权是 one-shot。

普通文件删除要求当前 SHA；目录只能删空目录；递归删、Workspace Root、Protected Path、Symlink、Hard-linked File 都不开放。

这会让“帮我顺便清理十几个目录”没那么丝滑。

我接受这个麻烦。

恢复一个误删目录比多确认几次麻烦得多。

## `run_command` 还是不经过 Shell

这一条从第一版到现在没变。

命令执行是：

```text
program + args[]
```

不是：

```text
/bin/sh -c "..."
```

所以：

```text
&&
|
>
$(...)
```

这些语法根本没有解释器去理解。

默认预授权 Command Policy 仍然很窄，主要是受约束的 Git / ripgrep，以及 Harness 能确定形状的工程检查。

但现在“默认没授权”不等于“永远不能授权”。模型如果请求一个合法的裸可执行程序名，例如 `hugo`、`flutter`、`deno`、`mvn`，第一次会生成当前 Workspace 的 `CommandAccess` Pending Request。TUI 里可以用 ↑/↓ 选中某一条，`Y` 只批准选中的请求、`N` 只拒绝选中的请求；Project Observatory 的 Access Panel 也能处理同一批 Pending Request。

批准后只是把这个 Program 加进当前 Workspace 的运行时授权，不是开放 Shell。`bash`、`sh`、`pwsh`、`cmd` 这类 Shell Interpreter 和带路径 Program Name 仍然硬拒绝；Argument 继续经过 Workspace Escape、Protected Path 和具体 Command Policy 检查。

Git Mutation 会被挡，敏感环境变量会清掉，输出有限制，进程有 Timeout。

我一直不认同“既然模型已经能写代码，不如直接给它 Terminal”这种推导。

写代码能力和拿到一个继承了我所有环境的 Shell，不是一个权限级别。

## 高风险执行现在可以按操作授权

这一块和第一版相比变过。

以前要跑 Language Server、Runtime Executor 这类 repository-aware 操作，基本就是启动时加：

```text
--allow-risky-exec
```

这个开关现在还在，含义更像“这个 wcode 进程我整体信任，可以做这类执行”。

但我不一定每次都想放这么宽。

现在具体的 Risky Execution 也可以先触发本地 Authorization Request。我在 TUI 或受保护 WebUI 里批准当前 Session 的精确 operation，再让 Agent 重试。

例如我只想允许一次 Semantic Refresh，就不必顺便授权后面所有仓库执行。

这和 `CommandAccess` 是两层：前者决定“这个 Program 能不能在这个 Workspace 出现”，后者继续决定“当前这组 repository-aware 参数是否值得信任”。

这不是 OS Sandbox。

只是把“你信不信这个仓库里的代码会被执行”从一个粗开关拆得更细一点。

## 并发写入也不是谁先抢到锁谁赢

现在 `parallel_tools` 能处理一部分独立 Workspace Write，这又多了一个安全问题：两个任务到底能不能同时跑。

Scheduler 会先建立 Path Resource Model。

如果两个操作碰同一个文件，或者 Move / Delete / Create 之间有父子路径依赖，就排序，不硬并发。

同文件 `apply_edits` 只有 SHA 一样、Edit Range 不冲突时才会合并成一次原子提交。

我不想让“支持并发”最后变成“把 race condition 交给文件锁处理”。

能不能并发应该在执行前就尽量说清楚。

## Security 不能写在 Prompt 里

我还是会在 Skill 和 Agent Instructions 里写：不要逃出 Workspace，不要绕过授权，不要自己扩大 risky execution。

但这些只能算工作习惯。

真正的安全边界必须在 Tool Runtime。

模型理解错了、Prompt Injection 进来了、路径算错了，最后应该撞在 Workspace Policy / Authorization / Command Policy 上。

而不是靠一句：

> 请严格遵守安全规则。

上层功能越多，我越觉得这一点重要。

Agent 可以很聪明，也可以犯很离谱的错。底层权限最好对这两种情况都一样冷淡。

这一组文章从 [最新版总览](/blog/wcode-2026/) 开始。第一版关于 OAuth、Tunnel、MCP 请求链路和早期 Workspace 实现的记录还在 [这里](/blog/wcode/)。