---
title: "我把 wcode 写代码这条链又压快了一轮"
date: 2026-08-26T23:40:00+08:00
draft: false
url: /blog/wcode-performance/
image: https://wcode.francis.run/assets/img.png
description: "真实项目里试用以后，我发现瓶颈不只在模型：写文件 fsync、项目扫描串行、搜索先收集全目录、工具往返和批量写法都会直接影响 Agent 写代码的体感。"
tags:
  - wcode
  - Rust
  - Performance
  - AI Agent
images:
  - https://wcode.francis.run/assets/img.png
---

最近我拿 wcode 去几个别的项目里实际写代码，最明显的感受不是“功能还缺什么”，而是：**还是不够快。**

这个“慢”很容易全甩给模型。

但我看了一轮调用链以后，发现里面有不少完全是 Runtime 自己造成的等待。

模型可能已经知道要改哪几个文件了，结果后面还在重复遍历、重复强制落盘、串行扫描，或者一个一个发 Tool Call。

这些东西单次看都不大，Agent 连续改几十个文件时就很明显。

所以这一轮我没有继续加新的 Intelligence 能力，先把写代码的热路径压了一遍。

![wcode 最新终端实时面板](https://wcode.francis.run/assets/img.png)

## 第一处：每个小编辑都 `fsync` 太贵了

wcode 的文件写入一直比较保守。

已有文件不是原地 `truncate`，而是：

```text
read + verify SHA
      ↓
create temp file in same directory
      ↓
write content
      ↓
atomic replace
```

这个设计我不准备改。

真正拖速度的是之前为了追求磁盘级耐久性，还会做：

```text
temp file sync_all
rename
parent directory sync_all
```

也就是说，一个很小的 `apply_edits` 也可能触发两次强制刷盘。

在本地 SSD 上偶尔看不明显，但到了 macOS APFS、虚拟机、网络盘或者 Windows，一连串小 edit 的 latency 会直接堆起来。

这里我重新看了 Design State 的约束。

wcode 真正必须保证的是：

```text
SHA stale-write protection
same-directory atomic replacement
create-new cannot overwrite raced target
path / symlink / hardlink safety
```

它不是数据库，也没有承诺“每一个 Agent 小编辑在机器突然断电后都必须已经物理落盘”。

所以现在交互式 Coding Path 去掉了每个小写入的强制 data + directory fsync。

Atomic Replace 还在。

这两个概念不要混在一起：**原子性保留了，强制持久化延迟拿掉了。**

## 第二处：`project_context` 原来有两个串行全仓库扫描

Agent 进入一个新项目以后，我通常希望它先跑 `project_context`。

这里会做不少事情：

- 找 Manifest；
- 读 Repository Guidance；
- 推导 Verification Checks；
- 跑 Convention；
- 跑 Language Quality Matrix。

Profile 本身已经有 Cache。

但 Convention 和 Language Quality 之前还是串行执行。

这两个操作都可能扫一遍仓库。

```text
Convention Scan
      ↓
Language Quality Scan
```

其实它们之间没有数据依赖。

现在直接 `rayon::join`：

```text
        ┌─ Convention Scan
context ┤
        └─ Language Quality Scan
```

结果语义不变，但大仓库第一次进入时的 wall-clock 更合理。

## 第三处：搜索不应该先收集完整文件列表

以前 `search_code/search_many` 的逻辑大致是：

```text
WalkDir 整个目录
      ↓
收集 Vec<PathBuf>
      ↓
Rayon 并行读文件
      ↓
搜索
```

这意味着哪怕我要的前几十条结果很快就能找到，也要先把目录完整走完并分配一个 Path Vec。

现在改成了边遍历边送给 Rayon Worker：

```text
WalkDir → par_bridge → read/search
```

一旦结果数量够了，后续 Worker 可以尽早退出。

大仓库里这类改动比在小 Fixture 上测出来的数字更有意义。

## 第四处：同文件多个 Edit 不应该重复建 Line Index

`apply_edits` 支持一次对同一个原始 SHA 做多处编辑。

如果每个 Edit 都带 `start_line/end_line`，以前每一条都会重新遍历整份内容去算行首 Byte Offset。

也就是 N 个 Edit，可能做 N 次 Line Scan。

现在只要这一批里有人用了 Line Bound，就先建一次 Line Start Index，所有 Edit 共享。

对于几千行文件一次改很多位置，这属于很便宜但应该做的优化。

## 第五处：`read_file` 不需要为整份文件保存 `Vec<&str>`

读取工具有 1 MiB 上限，所以以前直接：

```rust
let lines: Vec<&str> = content.lines().collect();
```

功能完全没问题。

但 Agent 大多数时候只拿 100～500 行。

现在先算总行数，再只对需要返回的 Range 做 `skip/take`。

不是一个惊人的 Benchmark，但这是典型的 Runtime Hot Path：每一次都跑，能少一次完整分配就少一次。

## 第六处：默认并行度再往上提

之前默认值是：

```text
logical CPU × 8
clamp 64..128
```

现在改成：

```text
logical CPU × 12
clamp 96..192
```

Harness 的硬上限仍然是 256，CLI 还是可以显式：

```bash
wcode -j 256
```

为什么不直接默认 256？

因为这个 Semaphore 不只有小文件 IO，还会承载一部分 CPU 和外部进程任务。

我希望默认更激进，但不是把所有机器都当成 32 核工作站。

8 核现在默认 96，10 核 120，16 核及以上最多到 192。

这个档位更适合 Agent 一次并行导航和修改多个文件。

## 第七处：连“统计响应有多大”也不该复制整份 JSON

TUI 会展示请求、响应和 Token Economy，所以 Tool Runtime 要知道每次调用大概传了多少字节。

以前这个指标是这样算的：

```text
Value
  ↓
serde_json::to_vec
  ↓
拿 Vec.len()
  ↓
Vec 丢掉
```

也就是说，真正响应以后，为了统计长度又临时分配并序列化了一份 JSON。

小结果没什么感觉，但 `parallel_tools`、Graph、Project Context 这类 `structuredContent` 大时，这就是纯粹的额外内存和 CPU。

现在改成一个只实现 `Write` 的 Byte Counter，让 `serde_json::to_writer` 流过去，只累加字节数，不保存第二份 Buffer。

协议内容完全不变，Monitor 指标也不变，但每个 Tool Call 少一次只为计数存在的临时分配。

## 更重要的是：让模型少发 Tool Call

Runtime 再快，如果 Agent 还是：

```text
read A
edit A
read B
edit B
read C
edit C
```

MCP Round Trip 一样会浪费很多时间。

所以 Project Context 的 Workflow 现在会明确提示：

```text
同文件多个修改 → apply_edits
多个已知现有文件 → apply_file_edits
多个新文件 → create_files
已知互不依赖的任务 → parallel_tools
一次遍历能解决 → search_many / read_files
```

我越来越觉得 Tool Harness 的性能不是单个函数跑多快。

它至少有三层：

```text
模型要不要一次提出足够完整的操作
            ↓
Tool Runtime 能不能批量/并行调度
            ↓
底层文件和索引操作有没有多余工作
```

只优化最后一层，体感还是会卡。

## 安全检查没有为了速度删掉

性能优化最容易走到另一个极端：觉得 `canonicalize`、SHA、Symlink Check、Lock 都贵，干脆少查一点。

这轮我没有这么做。

保留的边界包括：

- Workspace Root；
- Protected Path；
- Parent Traversal；
- Symlink Component；
- Unix Hard Link Write；
- SHA-256 stale revision；
- 写锁后的路径重新解析；
- Atomic Replace；
- No-shell Command；
- Pending Authorization。

我拿掉的是重复工作和不必要的同步，不是安全模型。

## 现在还剩什么可以继续优化

这一轮之后，我觉得还有几块值得继续盯：

1. `project_context` 的两个仓库扫描虽然并行了，但未来最好共享一次 File Inventory，而不是各走一遍目录。
2. MCP Tool Result 为兼容 `content + structuredContent` 本身仍会保留两种表示；这和已经去掉的“仅为统计字节数再序列化一次”不是一回事，大结果仍有进一步优化空间。
3. Software Graph 第一次建立时，Language/Tree-sitter Parser 初始化和目录候选选择还可以继续做更细的缓存。
4. Monitor 的指标必须保持便宜，不能为了展示吞吐量反过来拖 Tool Call。
5. 多 Workspace 同时工作时，需要继续观察 Rayon、Tokio `spawn_blocking` 和全局 Semaphore 三层调度会不会互相争资源。

我不准备为了追一个漂亮 Benchmark 把这些全部一次性复杂化。

更实际的标准还是：**拿它去真实项目写代码，哪一步明显在等，就把那一步拆出来。**

这也是我现在优化 wcode 的方式。

v0.3 的整体变化见 [wcode v0.3：从本地代码桥到 Software Intelligence Runtime](/blog/wcode-v0-3/)。
