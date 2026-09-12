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

The repository also supports a secondary Cloudflare static build without changing Hugo's canonical `baseURL`.

For Cloudflare Pages, use:

```text
Production branch: master
Build command:     make cloudflare
Build directory:   public
Build system:      v3
HUGO_VERSION:      0.166.0
```

Set `HUGO_VERSION=0.166.0` in both **Production** and **Preview** environments, and enable Cloudflare **Build cache**. The `cloudflare` target restores full Git history when the checkout is shallow, initializes theme submodules recursively, reuses the same `make check` contract as GitHub Pages, writes Hugo's image cache below `.cache/hugo`, and copies Cloudflare-only `_headers` into the final output.

`https://francis.run/` remains the canonical site even for Cloudflare preview/mirror builds. Do not add `-b $CF_PAGES_URL` unless Cloudflare becomes the canonical public host. The generated Cloudflare headers mark `*.pages.dev` deployment URLs as `noindex`. Custom-domain indexing is intentionally left unchanged; canonical URLs still point to `francis.run`.

If Cloudflare becomes the primary public host, attach the custom domain in the Cloudflare dashboard and redirect the production `*.pages.dev` hostname to it with a Bulk Redirect.
