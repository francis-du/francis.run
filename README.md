[![hugo](https://github.com/francis-du/francis.run/actions/workflows/hugo.yml/badge.svg)](https://github.com/francis-du/francis.run/actions)

# New article

```shell
# Default language (zh-CN)
hugo new blogs/xxx.md

# English translation / article
hugo new blogs/xxx.en.md
```

# Local development

```shell
hugo serve
```

# Verification and production build

```shell
make check
```

`make check` runs a real minified Hugo build and asserts the bilingual wcode introduction routes, the shared bilingual About profile, and the Gallery shell/script stack. GitHub Pages deploys this verified output.

Profile facts used by both `/about/` and `/en/about/` live in `data/profile.toml`. Update that shared source instead of maintaining separate project/contribution lists in the two Markdown files.

The default language stays at the site root. English content is published under `/en/`. Repository behavior and editorial constraints are tracked under `.wcode/`.

# Cloudflare

The repository supports two public sites from the same Hugo source. The default/GitHub Pages build uses `https://francis.run/`; the Cloudflare build uses `https://francisdu.com/`. `SITE_BASE_URL` drives canonical URLs, sitemap/robots output, social metadata, share URLs, and Cloudflare AI Search. The matching endpoints are `https://ai.francis.run/` and `https://ai.francisdu.com/`. Configure each AI Search Public Endpoint's Authorized hosts for its browser origin.

For Cloudflare Pages, use:

```text
Production branch: master
Build command:     make cloudflare
Build directory:   public
Build system:      v3
HUGO_VERSION:      0.166.0
```

Set `HUGO_VERSION=0.166.0` in both **Production** and **Preview** environments, and enable Cloudflare **Build cache**. The `cloudflare` target restores full Git history when the checkout is shallow, initializes theme submodules recursively, reuses the same `make check` contract as GitHub Pages, writes Hugo's image cache below `.cache/hugo`, and copies Cloudflare-only `_headers` into the final output.

The default target remains `SITE_BASE_URL=https://francis.run/`; `make cloudflare` overrides it with `CLOUDFLARE_BASE_URL=https://francisdu.com/`. You can verify either target directly with `make check SITE_BASE_URL=https://francis.run/` or `make check SITE_BASE_URL=https://francisdu.com/`. Both builds emit a root sitemap index plus language sitemaps whose absolute URLs match the selected domain. Cloudflare's generated `*.pages.dev` hostnames remain `noindex`.