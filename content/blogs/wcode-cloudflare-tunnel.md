---
title: "固定隧道的 MCP：Cloudflare Tunnel、Tailscale Funnel 和 wcode"
date: 2026-09-23T17:34:00+08:00
draft: false
url: /blog/wcode-cloudflare-tunnel/
translationKey: wcode-cloudflare-tunnel
description: "给 wcode 的 Remote MCP 一个固定公网入口：Cloudflare Tunnel 可以用自己的域名，Tailscale Funnel 可以直接拿稳定的 ts.net 地址。配好 --public-url 后，我也可以让 ChatGPT 通过 MCP 碰本地代码，尽量不再单独烧一份 API Token。"
tags:
  - wcode
  - Cloudflare Tunnel
  - Tailscale Funnel
  - MCP
  - ChatGPT
  - OAuth
  - Networking
---

wcode 自带 Tunnel，所以临时跑一个仓库时，我一般懒得配任何东西：启动以后拿公网 MCP 地址，丢进 ChatGPT、Claude 或其他支持 Remote MCP 的客户端就行。

真正开始长期用以后，我反而不想让 MCP 地址跟着每次 Tunnel 重启一起变。

原因很实际：地址一变，客户端配置要改，OAuth resource URL 也跟着变。对一个偶尔开的开发服务无所谓，对每天都用的本地代码入口就挺烦。

所以我现在会给常用的 wcode 留一个**固定隧道入口**。Cloudflare Tunnel 和 Tailscale Funnel 我都在用，结构其实一样：

~~~text
ChatGPT / Claude / other MCP client
               │
               │  stable HTTPS /mcp
               ▼
    Cloudflare Tunnel / Tailscale Funnel
               │
               ▼
        127.0.0.1:8765
               │
               ▼
             wcode
~~~

本机还是只监听 loopback，不开路由器端口，也不需要把 MCP Server 暴露给整个局域网。

wcode 只需要知道外面那个稳定的 HTTPS origin 是什么。

这个就是 <code>--public-url</code>。

## wcode 本地其实不用改什么

当前 wcode 的 Remote MCP 默认监听：

~~~text
127.0.0.1:8765
~~~

所以如果 <code>cloudflared</code> 和 wcode 跑在同一台机器上，Tunnel 的 origin 直接指：

~~~text
http://127.0.0.1:8765
~~~

就够了。

我反而不建议为了 Tunnel 把 wcode 改成监听 <code>0.0.0.0</code>。Cloudflare 可以直接访问 loopback，没有必要顺手把本地 MCP Server 暴露给整个局域网。

真正需要改的是启动参数。假设最后的域名是：

~~~text
https://mcp.example.com
~~~

启动 wcode：

~~~bash
wcode --public-url https://mcp.example.com
~~~

之后给 MCP Client 的地址就是：

~~~text
https://mcp.example.com/mcp
~~~

<code>--public-url</code> 的作用不是关掉 OAuth，也不是把一个 URL 单纯显示在 TUI 里。它告诉 wcode：这个地址是外部已经准备好的稳定入口，不要再替我启动随机的 managed tunnel，OAuth 和 MCP 对外都按这个 origin 工作。

## 这也是我拿 ChatGPT “白嫖模型”的一种方式

我做 wcode 最早其实就有一个很现实的动机：**我已经在 ChatGPT Web 端用模型了，就不想为了让它碰本地代码，再单独开一份 API Token 账单。**

固定隧道把这件事变得比较顺：

~~~text
ChatGPT
   │
   │ Remote MCP
   ▼
https://固定地址/mcp
   │
   ▼
wcode
   │
   ▼
本地仓库
~~~

严格说这当然不是真的“免费模型”。

如果我本来就在付 ChatGPT 的套餐，或者账户本来就有可用额度，那模型算力还是来自 ChatGPT；我省掉的是同一件 coding 工作再走一遍 OpenAI API、再按 API Token 计费。对我自己来说，这就是很朴素的“白嫖 Web 端模型”。

这里还有一个现在必须写清楚的限制。

截至 **2026 年 9 月 23 日**，OpenAI 的公开文档写的是：ChatGPT 连接的是 **remote MCP**，不能直接拿 <code>127.0.0.1</code> 当 MCP 地址；Pro 用户在 Developer Mode 里可以接 read/fetch 权限的 MCP，而完整的 write/modify MCP 仍然主要在 Business、Enterprise 和 Edu 的 beta 范围里。

所以“ChatGPT 能不能直接让 wcode 改代码”取决于你当前的套餐和 Workspace 权限，这个产品矩阵以后也肯定还会变。

但网络这一层是一样的：**ChatGPT 必须能稳定访问到 wcode 的 Remote MCP 地址。**

这就是固定 Tunnel 真正解决的问题。

## 我现在会优先用 Cloudflare Dashboard 管 Tunnel

Cloudflare 目前更推荐 remotely-managed tunnel。配置存在 Cloudflare 侧，本机拿一个 Tunnel Token 跑 connector，不需要自己维护 credentials JSON 和完整的 ingress 配置。

先装 <code>cloudflared</code>。macOS 最简单：

~~~bash
brew install cloudflared
~~~

然后去 Cloudflare Dashboard：

~~~text
Networking
  → Tunnels
  → Create Tunnel
~~~

名字随便，我一般会直接叫 <code>wcode</code>。

Tunnel 建好以后，加一个 Published application：

~~~text
Hostname
  mcp.example.com

Service
  http://127.0.0.1:8765
~~~

域名本身要已经托管在 Cloudflare。

这里有个我第一次用 Tunnel 时容易想复杂的地方：**不用自己再去 DNS 页面手搓一条记录。**

从 Tunnel 里添加 Published application 时，Cloudflare 会把 hostname 路由到这个 Tunnel，并建立对应的 DNS 记录。

接下来在跑 wcode 的机器上安装 connector。Dashboard 会直接给一条带 Token 的命令，形式大概是：

~~~bash
sudo cloudflared service install <TUNNEL_TOKEN>
~~~

Token 是凭据，别提交到 Git，也别顺手贴到博客、Issue 或终端截图里。

等 <code>cloudflared</code> 连上以后，再启动：

~~~bash
wcode --public-url https://mcp.example.com
~~~

到这里固定地址就有了。

## 如果我想把 Tunnel 配置留在本机

Dashboard 方式比较省心，但有时候我就是想看见完整配置，或者一台机器上还有别的本地服务需要一起挂。

这种情况我会用 locally-managed tunnel。

先登录：

~~~bash
cloudflared tunnel login
~~~

创建一个 named tunnel：

~~~bash
cloudflared tunnel create wcode
~~~

它会生成一个 Tunnel UUID，以及类似下面的 credentials 文件：

~~~text
~/.cloudflared/<TUNNEL-UUID>.json
~~~

然后写 <code>~/.cloudflared/config.yml</code>：

~~~yaml
tunnel: <TUNNEL-UUID>
credentials-file: /Users/your-name/.cloudflared/<TUNNEL-UUID>.json

ingress:
  - hostname: mcp.example.com
    service: http://127.0.0.1:8765

  - service: http_status:404
~~~

最后那个 404 不是装饰。Cloudflare 的 ingress 规则要求最后有一条 catch-all，不匹配前面 hostname 的请求就到这里结束。

先检查配置：

~~~bash
cloudflared tunnel ingress validate
~~~

再把域名路由到 Tunnel：

~~~bash
cloudflared tunnel route dns wcode mcp.example.com
~~~

然后运行：

~~~bash
cloudflared tunnel run wcode
~~~

这时候再开另一个终端：

~~~bash
wcode --public-url https://mcp.example.com
~~~

固定域名这条链就完整了。

## macOS 上我会直接让 cloudflared 常驻

如果每次都手动开一个 <code>cloudflared tunnel run wcode</code>，固定域名是固定了，但进程还是得自己记着启动。

本地管理的 Tunnel 在 macOS 上可以直接装成 LaunchAgent：

~~~bash
cloudflared service install
~~~

这种方式使用当前用户的：

~~~text
~/.cloudflared/config.yml
~~~

登录以后自动启动，对我这种开发机最合适。

如果需要开机就跑、不依赖用户登录，也可以装成系统 LaunchDaemon：

~~~bash
sudo cloudflared service install
~~~

但这时 Cloudflare 默认读取的是 <code>/etc/cloudflared</code> 下的配置，不是当前用户 Home 里的那份。这个区别挺容易把自己坑一下：明明 <code>config.yml</code> 写好了，一加 <code>sudo</code> 就提示找不到配置。

开发机上没必要把事情搞复杂，我一般就让它跟用户登录一起起来。

## Tailscale Funnel 更省事，固定的是 ts.net 地址

如果机器本来就在跑 Tailscale，我其实更喜欢 Funnel 这一条。

Cloudflare Tunnel 的优势是可以直接用自己的域名；Tailscale Funnel 的优势是基本不用碰 DNS，设备会拿到一个稳定的 <code>*.ts.net</code> 地址。

这里要说清楚：**Funnel 不能随便绑我自己的域名。** 它公开出来的 DNS 名必须在当前 tailnet 的 <code>ts.net</code> 域下面。

先保证这台机器已经登录 Tailscale，然后直接把 wcode 的本地端口公开出去：

~~~bash
tailscale funnel --bg 8765
~~~

当前 Funnel CLI 会把本机的：

~~~text
http://127.0.0.1:8765
~~~

代理成一个公网 HTTPS 地址，大概长这样：

~~~text
https://my-mac.my-tailnet.ts.net
~~~

看实际地址：

~~~bash
tailscale funnel status
~~~

然后启动 wcode：

~~~bash
wcode --public-url https://my-mac.my-tailnet.ts.net
~~~

MCP Client 填：

~~~text
https://my-mac.my-tailnet.ts.net/mcp
~~~

就可以了。

Tailscale 官方现在把 Funnel 的定位写得很直接：本地服务通过稳定的 HTTPS <code>ts.net</code> 地址公开到互联网，机器在线、Tailscale 在线，Funnel 就继续工作。

第一次跑时，如果 tailnet 还没开 HTTPS、MagicDNS 或 Funnel 权限，CLI 会带你去网页确认。

这条路对我最大的好处就是少配一层东西。没有 Tunnel Token，没有 Cloudflare DNS route，也没有 <code>config.yml</code>。

代价也很明确：域名是 Tailscale 的 <code>ts.net</code>，不是我自己的域名；而且 Funnel 是公网入口，不是只在 tailnet 里可见。只想让自己的设备访问，应该用的是 <code>tailscale serve</code>，不是 Funnel。

## 不管用哪种 Tunnel，我都会先看 /healthz

Cloudflare 的例子：

~~~bash
curl -sS https://mcp.example.com/healthz | jq
~~~

Tailscale 的例子：

~~~bash
curl -sS https://my-mac.my-tailnet.ts.net/healthz | jq
~~~

正常情况下能看到 <code>ok: true</code>，同时还有当前 wcode 实例的信息。

这个检查比直接拿 MCP Client 试省事很多：

~~~text
/healthz 都不通
    → Tunnel / DNS / origin 有问题

/healthz 正常，MCP Client 连不上
    → 再查 OAuth / Client 兼容
~~~

还有一个容易误判的地方。

直接访问：

~~~bash
curl -i https://mcp.example.com/mcp
~~~

在还没完成 OAuth 时看到 <code>401 Unauthorized</code> 不代表 Tunnel 坏了。

wcode 的 MCP endpoint 本来就受 OAuth 保护。Tunnel 只负责把请求送到本机，不会绕过认证。

## 一个 Tunnel 可以挂多个本地服务

Cloudflare Tunnel 不要求一个 Tunnel 只服务一个域名。

比如同一台机器还有别的东西：

~~~yaml
ingress:
  - hostname: mcp.example.com
    service: http://127.0.0.1:8765

  - hostname: dashboard.example.com
    service: http://127.0.0.1:3000

  - hostname: api.example.com
    service: http://127.0.0.1:8080

  - service: http_status:404
~~~

每个 hostname 再各自建 DNS route 就行。

不过 wcode 我还是会给它单独一个 hostname，不和其他 Web App 混 path。

原因不是 Cloudflare 做不到 path routing，而是 wcode 下面还有 OAuth metadata、authorize、token、health 和 MCP endpoint。独立 hostname 少很多“为什么这个 well-known 路径被前面的代理规则吃掉了”的问题。

## 真正要固定的是 public origin

wcode 不在乎外面到底是 Cloudflare 还是 Tailscale。

我现在常用的就是两种：

~~~text
Cloudflare Tunnel
https://mcp.example.com

Tailscale Funnel
https://my-mac.my-tailnet.ts.net
~~~

然后分别告诉 wcode：

~~~bash
wcode --public-url https://mcp.example.com
~~~

或者：

~~~bash
wcode --public-url https://my-mac.my-tailnet.ts.net
~~~

只要这个 public origin 能完整转发到本机 wcode，并且 HTTPS、Host、OAuth metadata 和 MCP 路径没被代理层改坏，后面的逻辑就是同一套。

Cloudflare 适合我想用自己域名的时候；Tailscale Funnel 适合机器本来就在 tailnet 里、我只想最快拿一个稳定 HTTPS 地址的时候。

Quick Tunnel 我也还是会留着。临时仓库一条命令拿随机地址最舒服。

但常用实例我更愿意固定下来。

尤其是当它后面接的是 ChatGPT 这种 Web 端模型时，我不想每次 wcode 重启以后再去改一次 MCP 配置。固定 Tunnel 以后，它才真的像一个长期存在的本地代码入口。

## 相关文档

- [Cloudflare Tunnel：Get started](https://developers.cloudflare.com/tunnel/get-started/)
- [Cloudflare：Create a locally-managed tunnel](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/create-local-tunnel/)
- [Cloudflare：Configuration file](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/configuration-file/)
- [Cloudflare：Run as a service on macOS](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/as-a-service/macos/)
- [Tailscale Funnel](https://tailscale.com/docs/features/tailscale-funnel)
- [Tailscale Funnel CLI](https://tailscale.com/docs/reference/tailscale-cli/funnel)
- [ChatGPT：Developer mode and MCP apps](https://help.openai.com/en/articles/12584461-developer-mode-and-mcp-apps-in-chatgpt)
- [wcode](https://github.com/francis-du/wcode)
