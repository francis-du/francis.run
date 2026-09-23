---
title: "A Stable MCP Tunnel for wcode: Cloudflare or Tailscale Funnel"
date: 2026-09-23T17:35:00+08:00
draft: false
url: blog/wcode-cloudflare-tunnel/
translationKey: wcode-cloudflare-tunnel
description: "I keep long-lived wcode Remote MCP endpoints behind a stable tunnel. Cloudflare gives me my own hostname, Tailscale Funnel gives me a stable ts.net URL, and --public-url makes OAuth and MCP use that origin. It also lets me use the model quota I already have in ChatGPT instead of opening a second API-token bill for the same coding work."
tags:
  - wcode
  - Cloudflare Tunnel
  - Tailscale Funnel
  - MCP
  - ChatGPT
  - OAuth
  - Networking
---

wcode can create its own public tunnel, and for a temporary repository that is still the easiest path.

For something I use every day, I do not want the MCP address to change whenever the tunnel is recreated. A hostname change means updating the client and changing the OAuth resource origin as well.

So I now keep long-lived wcode instances behind a **stable tunnel endpoint**. I use both Cloudflare Tunnel and Tailscale Funnel:

~~~text
ChatGPT / Claude / other MCP client
               │
               │ stable HTTPS /mcp
               ▼
    Cloudflare Tunnel / Tailscale Funnel
               │
               ▼
        127.0.0.1:8765
               │
               ▼
             wcode
~~~

wcode still stays on loopback. I do not open a router port or expose the local MCP server to the LAN.

The only thing wcode needs is the stable public HTTPS origin.

That is what <code>--public-url</code> is for.

## The local wcode side barely changes

The current Remote MCP server listens on:

~~~text
127.0.0.1:8765
~~~

by default.

If <code>cloudflared</code> runs on the same machine, I point the Tunnel origin directly at:

~~~text
http://127.0.0.1:8765
~~~

I do not change wcode to <code>0.0.0.0</code> just because I am using a tunnel. Cloudflare can reach the loopback service locally, so there is no reason to expose the MCP server to the rest of the LAN.

Assume the stable hostname is:

~~~text
https://mcp.example.com
~~~

I start wcode with:

~~~bash
wcode --public-url https://mcp.example.com
~~~

and configure the AI client with:

~~~text
https://mcp.example.com/mcp
~~~

<code>--public-url</code> does not disable wcode's OAuth layer. It tells wcode that an external stable entry point already exists, so wcode should use that origin instead of starting a random managed tunnel.

## This is also how I reuse the model quota I already have in ChatGPT

One of the practical reasons I built wcode was simple: if I am already using ChatGPT in the browser, I do not want the same coding task to require a second API bill just so the model can touch my local repository.

A stable Remote MCP path gives me this shape:

~~~text
ChatGPT
   │
   │ Remote MCP
   ▼
https://stable-host/mcp
   │
   ▼
wcode
   │
   ▼
local repository
~~~

This is not literally free compute.

If I already pay for a ChatGPT plan or have model usage available there, the model is still being paid for through ChatGPT. What I avoid is sending the same workflow through the OpenAI API and paying separately by API token. That is the part I care about.

There is an important product limitation to keep honest.

As of **September 23, 2026**, OpenAI's public documentation says ChatGPT connects to **remote MCP** servers rather than directly to a localhost endpoint. Pro users can connect MCPs with read/fetch permissions in Developer Mode, while full write/modify MCP support is still rolling out for Business, Enterprise, and Edu.

So whether ChatGPT can let wcode actually edit code depends on the current plan and workspace permissions. That matrix will change over time.

The network requirement does not: ChatGPT needs a reachable, stable Remote MCP origin.

That is the problem the tunnel solves.

## I prefer the Cloudflare-managed tunnel for this

Cloudflare currently recommends remotely-managed tunnels for most cases. The configuration lives on Cloudflare, and the machine only needs a Tunnel token to run the connector.

On macOS:

~~~bash
brew install cloudflared
~~~

Then in the Cloudflare dashboard:

~~~text
Networking
  → Tunnels
  → Create Tunnel
~~~

I normally just name it <code>wcode</code>.

Add a Published application route:

~~~text
Hostname
  mcp.example.com

Service
  http://127.0.0.1:8765
~~~

The domain must already be on Cloudflare.

One useful detail: when the hostname is added from the Tunnel's Published application screen, Cloudflare creates the DNS routing for it. I do not need to create a second hand-written CNAME for the normal full-DNS setup.

The dashboard then gives me the connector command. It looks roughly like this:

~~~bash
sudo cloudflared service install <TUNNEL_TOKEN>
~~~

The token is a credential. I do not put it in a repository, an issue, or a terminal screenshot.

Once the connector is online:

~~~bash
wcode --public-url https://mcp.example.com
~~~

That is enough to give wcode a stable public MCP origin.

## The fully local config is still useful

Sometimes I want the entire Tunnel configuration on the machine, especially if the same connector publishes several local services. In that case I use a locally-managed tunnel.

Authenticate:

~~~bash
cloudflared tunnel login
~~~

Create a named tunnel:

~~~bash
cloudflared tunnel create wcode
~~~

That creates a Tunnel UUID and a credentials file under something like:

~~~text
~/.cloudflared/<TUNNEL-UUID>.json
~~~

Then I create <code>~/.cloudflared/config.yml</code>:

~~~yaml
tunnel: <TUNNEL-UUID>
credentials-file: /Users/your-name/.cloudflared/<TUNNEL-UUID>.json

ingress:
  - hostname: mcp.example.com
    service: http://127.0.0.1:8765

  - service: http_status:404
~~~

The final 404 rule matters. An ingress configuration needs a catch-all rule at the end.

I validate the file before starting anything:

~~~bash
cloudflared tunnel ingress validate
~~~

Create the DNS route:

~~~bash
cloudflared tunnel route dns wcode mcp.example.com
~~~

Run the tunnel:

~~~bash
cloudflared tunnel run wcode
~~~

and start wcode separately:

~~~bash
wcode --public-url https://mcp.example.com
~~~

At that point the path is stable from the client all the way to the local runtime.

## On macOS I let cloudflared stay running

A fixed hostname is less useful if I still have to remember to launch the tunnel manually.

For a locally-managed tunnel, macOS can install <code>cloudflared</code> as a per-user LaunchAgent:

~~~bash
cloudflared service install
~~~

That uses:

~~~text
~/.cloudflared/config.yml
~~~

and starts when I log in, which is usually what I want on a development machine.

There is also a boot-level LaunchDaemon:

~~~bash
sudo cloudflared service install
~~~

The important difference is that the system service expects its configuration under <code>/etc/cloudflared</code>, not the user's home directory. This is an easy way to end up wondering why a perfectly good <code>~/.cloudflared/config.yml</code> suddenly cannot be found after adding <code>sudo</code>.

For my laptop, the login LaunchAgent is simpler.

## Tailscale Funnel is even less configuration

If the machine already runs Tailscale, Funnel is the other path I like.

Cloudflare Tunnel is better when I want my own domain. Tailscale Funnel is better when I just want a stable public HTTPS endpoint without touching DNS.

The important limitation is that Funnel does **not** let me choose an arbitrary custom hostname. Its public DNS name lives under the tailnet's <code>ts.net</code> domain.

Once the machine is logged into Tailscale, I can publish wcode's local port in the background:

~~~bash
tailscale funnel --bg 8765
~~~

That proxies:

~~~text
http://127.0.0.1:8765
~~~

to a public HTTPS name similar to:

~~~text
https://my-mac.my-tailnet.ts.net
~~~

I can inspect the actual endpoint with:

~~~bash
tailscale funnel status
~~~

Then I start wcode with that origin:

~~~bash
wcode --public-url https://my-mac.my-tailnet.ts.net
~~~

and give the MCP client:

~~~text
https://my-mac.my-tailnet.ts.net/mcp
~~~

Tailscale describes Funnel as a way to expose a local service through a predictable, stable <code>ts.net</code> HTTPS name. The machine and Tailscale still need to be online, but there is no separate DNS record or Cloudflare Tunnel token to manage.

On first use, the CLI may ask me to enable the tailnet requirements for Funnel, including HTTPS and the relevant Funnel permission.

Funnel is public internet access. If I only want the service reachable inside my tailnet, the right command is <code>tailscale serve</code>, not Funnel.

## I check /healthz before debugging OAuth, whichever tunnel I use

Cloudflare:

~~~bash
curl -sS https://mcp.example.com/healthz | jq
~~~

Tailscale:

~~~bash
curl -sS https://my-mac.my-tailnet.ts.net/healthz | jq
~~~

A healthy response includes <code>ok: true</code> and identifies the current wcode instance.

This splits debugging into two smaller problems:

~~~text
/healthz fails
    → Tunnel / DNS / origin problem

/healthz works, MCP client fails
    → OAuth / client interoperability problem
~~~

Before OAuth is complete, this:

~~~bash
curl -i https://mcp.example.com/mcp
~~~

can return <code>401 Unauthorized</code>.

That does not mean the tunnel is broken. wcode's MCP endpoint is supposed to be protected. The tunnel provides reachability; it does not bypass authentication.

## One tunnel can publish more than wcode

A single Cloudflare Tunnel can route several hostnames:

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

I still give wcode its own hostname instead of hiding it under a path on another application.

wcode has more than <code>/mcp</code>: OAuth discovery and authorization endpoints, token handling, health checks, and the MCP transport all share the same public origin. A dedicated hostname removes a whole class of proxy path-rewrite problems.

## The stable public origin is the actual requirement

wcode does not care whether that origin comes from Cloudflare or Tailscale.

These are the two shapes I use:

~~~text
Cloudflare Tunnel
https://mcp.example.com

Tailscale Funnel
https://my-mac.my-tailnet.ts.net
~~~

Then I pass the matching origin to wcode:

~~~bash
wcode --public-url https://mcp.example.com
~~~

or:

~~~bash
wcode --public-url https://my-mac.my-tailnet.ts.net
~~~

As long as the public origin forwards the complete wcode surface without breaking HTTPS, Host handling, OAuth metadata, or the MCP path, the rest of the runtime is the same.

Cloudflare is what I use when I want my own domain. Tailscale Funnel is what I use when the machine is already in my tailnet and I want the shortest path to a stable HTTPS address.

I still keep Quick Tunnel for disposable sessions.

For a long-lived instance, especially one connected to a browser model such as ChatGPT, I would rather configure the MCP URL once and stop touching it.

## References

- [Cloudflare Tunnel: Get started](https://developers.cloudflare.com/tunnel/get-started/)
- [Cloudflare: Create a locally-managed tunnel](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/create-local-tunnel/)
- [Cloudflare: Configuration file](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/configuration-file/)
- [Cloudflare: Run as a service on macOS](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/as-a-service/macos/)
- [Tailscale Funnel](https://tailscale.com/docs/features/tailscale-funnel)
- [Tailscale Funnel CLI](https://tailscale.com/docs/reference/tailscale-cli/funnel)
- [ChatGPT: Developer mode and MCP apps](https://help.openai.com/en/articles/12584461-developer-mode-and-mcp-apps-in-chatgpt)
- [wcode](https://github.com/francis-du/wcode)
