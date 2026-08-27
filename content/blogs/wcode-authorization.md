---
title: "wcode 的授权中心：模型可以提权限，但不能替我批准"
date: 2026-08-26T23:35:00+08:00
draft: false
url: /blog/wcode-authorization/
image: /img/wcode/wcode-access-management.png
description: "模型遇到未授权命令、高风险执行、Runtime Executor 或删除操作时，不再只有永久拒绝和全局放开两个选项；wcode 把它们变成可选择的 Pending Authorization。"
tags:
  - wcode
  - Security
  - MCP
  - AI Agent
images:
  - /img/wcode/wcode-access-management.png
---

我一直不想给 Agent 一个 Shell。

但实际用久了以后，我也越来越不喜欢另一个极端：只要一个工具不在默认列表里，就永久拒绝；真要用的时候，只能重启进程加一个很宽的 Trust Flag。

这两个选择都太粗：

```text
完全不许
   或
整个进程都信任
```

最近我把 wcode 的授权做成了真正的 Pending Authorization Queue。

核心原则很简单：

> **模型可以提出权限请求，但决定权必须留在用户手里。**

![wcode 授权与访问控制界面](/img/wcode/wcode-access-management.png)

## 为什么 `Y/N` 以前看起来没用

TUI 其实早就有 `Y/N` 的 Key Handler。

问题是 UI 只在 Footer 里塞了一个 Pending 数字。

用户看不到：

```text
到底是谁在申请？
申请哪个 Workspace？
要跑什么？
这是普通命令还是删除？
Y 到底会批准哪一条？
```

所以从人的角度看，`Y/N` 就像两个没有上下文的快捷键。

现在 Pending Request 会直接显示成一个列表。

大概是这种信息：

```text
AUTHORIZATION REQUIRED                         3 PENDING

› AUTH-00000021 [COMMAND]      web   · authorize command: hugo
  AUTH-00000020 [RISKY EXEC]   api   · allow repository-aware command: cargo metadata
  AUTH-00000019 [DELETE]       api   · delete file: src/obsolete.rs

↑/↓ select request   Y approve selected   N deny selected
```

`Y` 不再是“批准最新一条”。

它只批准当前选中的 Request。

`N` 也一样。

当多个 Agent / Tool 同时工作时，这个区别很重要。

## 命令授权不再被默认 Catalog 封死

最开始 wcode 有一份固定 Command Catalog：

```text
cargo
rustc
git
rg
npm
pnpm
yarn
bun
node
python3
pytest
go
make
```

它很适合作为**默认预授权集合**。

但把它当成“用户永远只能授权这些命令”的上限，就会变得很别扭。

真实项目会用：

```text
hugo
flutter
deno
mvn
gradle
swift
mix
```

甚至公司内部还有自己的 Build Tool。

所以现在语义变成：

```text
默认安全集合 → 直接进入后续 Command Policy

其他合法 bare executable
        ↓
CommandAccess Pending Request
        ↓
用户批准
        ↓
只加入当前 Workspace 的运行时 allowlist
        ↓
模型重试
```

这不是让模型自己扩权。

第一次请求仍然失败。

真正改变权限的是本地用户的批准动作。

## 为什么我还是不让它授权 `bash`

“用户可以授权模型请求的命令”不等于“所有字符串都应该变成可授权请求”。

wcode 仍然有一层不能被 UI 点掉的硬边界。

Program 必须是合法的裸可执行程序名：

```text
hugo        ✓
flutter     ✓
gradle      ✓

./tool      ✗
../tool     ✗
/usr/bin/x  ✗
foo/bar     ✗
```

Shell Interpreter 也永久拒绝：

```text
sh
bash
zsh
fish
pwsh
powershell
cmd
```

原因还是同一个。

wcode 的 Command Contract 是：

```text
program + args[]
```

而不是：

```text
shell -c arbitrary_string
```

如果允许模型拿到 Shell，前面的 Argument Inspection、Protected Path Check 和 No-shell 边界都会变得很容易绕。

我宁愿让用户授权更多具体 Program，也不想把整个模型重新变成远程 Terminal。

## `CommandAccess` 和 `RiskyExecution` 是两层

这个地方容易混。

假设模型第一次想跑：

```text
hugo --minify
```

如果 `hugo` 还没被当前 Workspace 授权，先得到的是：

```text
CommandAccess
```

它回答：

> 这个 Program 能不能出现在这个 Workspace？

但对已经有专门 Policy 的命令，例如 Cargo / Go / Package Manager，某些参数可能会执行 Repository-controlled Code。

这时即使 Program 已经允许，仍可能得到：

```text
RiskyExecution
```

它回答的是另一件事：

> 这组具体 repository-aware Operation 是否值得信任？

所以权限不是一个 Boolean。

更接近：

```text
Program Access
      ↓
Argument / Path Policy
      ↓
Risky Operation Trust
      ↓
Execute
```

## 现在有四类 Authorization

当前我把它们分成四种。

### 1. CommandAccess

模型请求当前 Workspace 尚未授权的 Program。

批准以后，这个 Program 加进当前 Workspace 的运行时 allowlist。

### 2. RiskyExecution

Program 本身允许，但这组参数可能加载或执行仓库控制的代码、配置或插件。

批准的是精确 Operation Fingerprint 的 Session Grant。

### 3. RuntimeExecutor

Property / Mutation / Fuzz / Runtime Canary 等 Verification Executor 可能来自仓库配置。

它们是另一条显式 Trust Boundary。

### 4. DestructiveDelete

这是最严格的。

只能删除一个普通文件或空目录，文件要求当前 SHA，批准是 exact one-shot，用一次就失效。

我不想让一个“同意删除”自动变成当前 Session 后续所有 Delete 都合法。

## WebUI 也必须能处理同一批 Request

只在 TUI 做授权有个现实问题：我可能正盯着浏览器里的 Project Observatory，而不是 Terminal。

所以现在 WebUI 的 `Manage access` 里有三块：

```text
Authorized projects
Authorized commands
Pending authorizations
```

Project 可以在运行时添加。

Command 可以手动授权或撤销。

Pending Request 则逐条显示 Approve / Deny。

WebUI 并不是另开了一套权限状态。

它和 TUI 操作的是同一个 Authorization Manager。

也就是说：

```text
Model Request
      ↓
one shared Pending Queue
   ↙              ↘
TUI               WebUI
Y / N         Approve / Deny
   ↘              ↙
 same runtime authorization state
```

WebUI 的这些 API 仍然需要原有的 Local UI Token 和 Origin Validation。

不能因为它是“管理页面”，就变成一个没有保护的本地管理接口。

## 多 Workspace 时，授权必须跟着项目走

我还顺手修了一个容易忽略的问题。

如果同一个进程同时暴露：

```text
backend
frontend
website
```

`CommandAccess` 必须知道自己属于哪个 Registry Workspace ID。

不能只根据目录 basename 猜，也不能批准一次以后给三个项目一起放开。

所以现在授权 Request 会带精确 Workspace ID。

批准 `website` 的 `hugo`，不会顺手让 `backend` 也能跑 `hugo`。

这是我想要的权限粒度。

## 授权以后仍然不是 OS Sandbox

最后还是要强调这一点。

这些授权机制解决的是：

```text
谁可以请求什么
谁决定放行
放行到什么粒度
```

它不是操作系统级 Sandbox。

一个用户批准的 Program 本身仍可能做很多事情。

wcode 能继续保证的是它自己的边界：

- 不经过 Shell；
- Workspace-relative CWD；
- Program Name 不允许路径；
- Argument 不允许 Workspace Escape；
- Protected Path 继续拒绝；
- 敏感环境变量继续清理；
- Git Helper / Mutation 等专门 Policy 继续生效；
- Timeout 和输出上限继续存在。

所以授权按钮的含义不是：

> 这个命令绝对安全。

而是：

> 我知道模型为什么需要它，我愿意把这一层权限交给当前 Workspace。

这个语义对我来说更诚实。

v0.3 的完整变化见 [wcode v0.3：从本地代码桥到 Software Intelligence Runtime](/blog/wcode-v0-3/)，底层安全边界继续看 [我还是不想给 Agent 一个 Shell](/blog/wcode-security/)。
