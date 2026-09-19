BUILD_DIR ?= target-hugo-check
HUGO_CACHE_DIR ?=
CLOUDFLARE_FILE_LIMIT ?= 20000
CLOUDFLARE_MAX_FILE_BYTES ?= 26214400
HUGO_CACHE_FLAG = $(if $(HUGO_CACHE_DIR),--cacheDir "$(HUGO_CACHE_DIR)",)
HUGO_BUILD_FLAGS = --gc --minify $(HUGO_CACHE_FLAG)

.PHONY: check build cloudflare social-cards

# Authoring helper for the committed social preview cards. Uses macOS system
# fonts so Chinese and English titles render without bundling font binaries.
social-cards:
	swift tools/generate-social-cards.swift

check:
	test -f hugo.toml
	test ! -e config.toml
	! grep -Fq 'enableInlineShortcodes = true' hugo.toml
	grep -Fq 'description = "💻 Data Engineer | 🦀 Rustacean | 📷 Photographer | 🤖 Vibe Coder"' hugo.toml
	grep -Fq 'avatar = "https://avatars.githubusercontent.com/u/25944814?s=132&v=4"' hugo.toml
	test "$$(grep -F 'description = "💻Data Engineer | 🦀 Rustacean | 📷 Photographer | 🤖Vibe Coder"' hugo.toml | wc -l | tr -d ' ')" -eq "2"
	grep -Fq "dir = ':cacheDir/images'" hugo.toml
	grep -Fq "min = '0.165.0'" hugo.toml
	grep -Fq 'span[style*="color:#00f"]' assets/css/dark.css
	grep -Fq 'span[style*="color:#a31515"]' assets/css/dark.css
	grep -Fq 'span[style*="color:#2b91af"]' assets/css/dark.css
	grep -Fq 'limit = 20' hugo.toml
	test -f deploy/cloudflare/_headers
	grep -Fq '/js/search.*' deploy/cloudflare/_headers
	grep -Fq '/js/code-copy.*' deploy/cloudflare/_headers
	grep -Fq '/index.json' deploy/cloudflare/_headers
	grep -Fq '/en/index.json' deploy/cloudflare/_headers
	grep -Fq 'max-age=300, must-revalidate' deploy/cloudflare/_headers
	test -z "$$(find static content -type f -name '*.webp' -print -quit)"
	grep -Fq '/*.webp' deploy/cloudflare/_headers
	grep -Fq 'https://:project.pages.dev/*' deploy/cloudflare/_headers
	hugo $(HUGO_BUILD_FLAGS) --cleanDestinationDir --destination $(BUILD_DIR)
	test -f $(BUILD_DIR)/blog/what-is-wcode/index.html
	test -f $(BUILD_DIR)/en/blog/what-is-wcode/index.html
	! test -e $(BUILD_DIR)/search/index.html
	! test -e $(BUILD_DIR)/en/search/index.html
	test -s $(BUILD_DIR)/index.json
	test -s $(BUILD_DIR)/en/index.json
	grep -q 'id=site-search-dialog' $(BUILD_DIR)/index.html
	grep -q 'id=site-search-dialog' $(BUILD_DIR)/en/index.html
	grep -q 'id=site-search-dialog' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'class=search-overlay hidden role=dialog aria-modal=true' $(BUILD_DIR)/index.html
	! grep -q '<dialog id=site-search-dialog' $(BUILD_DIR)/index.html
	grep -Fq '.search-overlay[hidden]' assets/css/search.css
	grep -Fq 'html.dark .search-overlay' assets/css/search.css
	grep -Fq '.search-palette' assets/css/search.css
	grep -q 'data-index-url=/index.json' $(BUILD_DIR)/index.html
	grep -q 'data-index-url=/en/index.json' $(BUILD_DIR)/en/index.html
	grep -q 'role=search' $(BUILD_DIR)/index.html
	grep -q 'aria-live=polite' $(BUILD_DIR)/index.html
	grep -q '/js/search.' $(BUILD_DIR)/index.html
	grep -q '/js/search.' $(BUILD_DIR)/blog/what-is-wcode/index.html
	! grep -q 'href=/search/' $(BUILD_DIR)/index.html
	! grep -q 'href=/en/search/' $(BUILD_DIR)/en/index.html
	grep -Fq 'event.key === "/"' assets/js/search.js
	grep -Fq 'event.metaKey || event.ctrlKey' assets/js/search.js
	grep -Fq 'event.key === "Escape"' assets/js/search.js
	grep -Fq 'event.key === "ArrowDown"' assets/js/search.js
	grep -Fq 'event.key === "ArrowUp"' assets/js/search.js
	grep -Fq '$$css = $$css | fingerprint' layouts/partials/header.html
	grep -Fq '$$search = $$search | fingerprint' layouts/partials/header.html
	grep -q '"url":"/blog/what-is-wcode/"' $(BUILD_DIR)/index.json
	grep -q '"url":"/en/blog/what-is-wcode/"' $(BUILD_DIR)/en/index.json
	grep -q '"content":' $(BUILD_DIR)/index.json
	! grep -q '"url":"/en/blog/' $(BUILD_DIR)/index.json
	! grep -q '"url":"/blog/' $(BUILD_DIR)/en/index.json
	! grep -q '"url":"/gallery/' $(BUILD_DIR)/index.json
	! grep -q '"url":"/about/' $(BUILD_DIR)/index.json
	grep -q 'rel=canonical href=https://francis.run/' $(BUILD_DIR)/index.html
	grep -q 'rel=canonical href=https://francis.run/en/' $(BUILD_DIR)/en/index.html
	grep -q 'rel=canonical href=https://francis.run/blogs/page/2/' $(BUILD_DIR)/blogs/page/2/index.html
	! grep -q 'hreflang=' $(BUILD_DIR)/blogs/page/2/index.html
	grep -q 'meta name=robots content="max-image-preview:large"' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'meta name=robots content="noindex,follow,max-image-preview:large"' $(BUILD_DIR)/gallery/index.html
	grep -q '"@type":"BreadcrumbList"' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '"@type":"BreadcrumbList"' $(BUILD_DIR)/tags/wcode/index.html
	grep -q 'Francis Du 关于 Wcode 的技术文章、工程实践与项目笔记。' $(BUILD_DIR)/tags/wcode/index.html
	! grep -q '<loc>https://francis.run/gallery/</loc>' $(BUILD_DIR)/zh-cn/sitemap.xml
	! grep -q '^Disallow: /gallery/$$' $(BUILD_DIR)/robots.txt
	grep -q '^Disallow: /gallery/images/$$' $(BUILD_DIR)/robots.txt
	grep -q 'meta name=description' $(BUILD_DIR)/index.html
	grep -q 'Francis Du 的个人技术博客' $(BUILD_DIR)/index.html
	grep -q "Francis Du's engineering notes" $(BUILD_DIR)/en/index.html
	grep -q 'Francis Du 的个人技术博客' $(BUILD_DIR)/index.xml
	grep -q "Francis Du's engineering notes" $(BUILD_DIR)/en/index.xml
	grep -q 'meta name=description' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'meta name=description' $(BUILD_DIR)/en/blog/what-is-wcode/index.html
	grep -q 'class=skip-link href=#main-content' $(BUILD_DIR)/index.html
	grep -q '<main id=main-content' $(BUILD_DIR)/index.html
	grep -q '<main id=main-content' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '<header class=header' $(BUILD_DIR)/index.html
	grep -q '<footer class="footer wrapper"' $(BUILD_DIR)/index.html
	grep -q '<h1 class=page-title>Blogs</h1>' $(BUILD_DIR)/blogs/index.html
	grep -q 'class=pagination-nav aria-label=' $(BUILD_DIR)/blogs/index.html
	! grep -Rqs 'pages.dev' $(BUILD_DIR) --exclude='_headers'
	test -f $(BUILD_DIR)/gallery/index.html
	test -f $(BUILD_DIR)/404.html
	test -f $(BUILD_DIR)/en/404.html
	grep -q '<html lang=zh-CN' $(BUILD_DIR)/404.html
	grep -q '<html lang=en-US' $(BUILD_DIR)/en/404.html
	grep -q '没有找到这个页面' $(BUILD_DIR)/404.html
	grep -q 'Page not found' $(BUILD_DIR)/en/404.html
	! grep -q '/search/' $(BUILD_DIR)/sitemap.xml
	grep -q 'meta name=robots content="noindex,follow"' $(BUILD_DIR)/404.html
	grep -q '<main id=main-content' $(BUILD_DIR)/404.html
	! grep -q 'background:#202020' $(BUILD_DIR)/404.html
	! test -f $(BUILD_DIR)/js/gallery.js
	test -f $(BUILD_DIR)/about/index.html
	test -f $(BUILD_DIR)/en/about/index.html
	grep -q 'icon-github' $(BUILD_DIR)/index.html
	grep -q 'theme-icon-sun' $(BUILD_DIR)/index.html
	grep -q '<button type=button id=scheme-toggle' $(BUILD_DIR)/index.html
	! grep -q '<a href=# id=scheme-toggle' $(BUILD_DIR)/index.html
	grep -q 'rel=preload href=/css/bundle.min.' $(BUILD_DIR)/index.html
	grep -q 'rel=preload href=/css/bundle.min.* as=style' $(BUILD_DIR)/index.html
	grep -q 'data-cfasync=false' $(BUILD_DIR)/index.html
	! grep -q 'data-cf-async' $(BUILD_DIR)/index.html
	grep -q 'family=Inter:wght@400..750' $(BUILD_DIR)/index.html
	grep -q 'Playfair+Display:wght@700&amp;text=0123456789&amp;display=swap' $(BUILD_DIR)/index.html || grep -q 'Playfair+Display:wght@700&text=0123456789&display=swap' $(BUILD_DIR)/index.html
	! grep -q 'Playfair' $(BUILD_DIR)/blog/what-is-wcode/index.html
	! grep -q 'feather.min' $(BUILD_DIR)/index.html
	grep -q '"@type":"ProfilePage"' $(BUILD_DIR)/about/index.html
	grep -q '"@type":"ProfilePage"' $(BUILD_DIR)/en/about/index.html
	grep -q '"@type":"BlogPosting"' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '"@type":"BlogPosting"' $(BUILD_DIR)/en/blog/what-is-wcode/index.html
	grep -q '"url":"https://francis.run/about/"' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '"url":"https://francis.run/en/about/"' $(BUILD_DIR)/en/blog/what-is-wcode/index.html
	grep -q '"sameAs":\["https://github.com/francis-du"' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'class=article-toc' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '本文目录' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'On this page' $(BUILD_DIR)/en/blog/what-is-wcode/index.html
	grep -q 'id=TableOfContents' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'class=heading-anchor href=#' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '章节链接：' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'Permalink to section:' $(BUILD_DIR)/en/blog/what-is-wcode/index.html
	! grep -q 'class=heading-anchor' $(BUILD_DIR)/about/index.html
	grep -q 'data-copy-code=' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '/js/code-copy.' $(BUILD_DIR)/blog/what-is-wcode/index.html
	test -n "$$(find $(BUILD_DIR)/js -type f -name 'code-copy.*.js' -print -quit)"
	! grep -q '/js/code-copy.' $(BUILD_DIR)/about/index.html
	! grep -q '/js/code-copy.' $(BUILD_DIR)/gallery/index.html
	! grep -q 'class=article-toc' $(BUILD_DIR)/blog/ruchong/index.html
	! grep -q 'class=article-toc' $(BUILD_DIR)/about/index.html
	! grep -q '"keywords":\[null\]' $(BUILD_DIR)/blog/April/index.html
	grep -q '<generator>Hugo ' $(BUILD_DIR)/index.xml
	test "$$(grep -o '<item>' $(BUILD_DIR)/index.xml | wc -l | tr -d ' ')" -le "20"
	test "$$(grep -o '<item>' $(BUILD_DIR)/tags/wcode/index.xml | wc -l | tr -d ' ')" -le "20"
	grep -q 'Deciding what the assistant can access' $(BUILD_DIR)/en/index.xml
	grep -q '<copyright>© Francis Du</copyright>' $(BUILD_DIR)/index.xml
	! grep -q 'Source Themes Academic' $(BUILD_DIR)/index.xml
	! grep -q 'Ink theme on Hugo' $(BUILD_DIR)/index.xml
	grep -Eq 'property="og:image" content="https://francis.run/img/share/what-is-wcode\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -Eq 'property="og:image" content="https://francis.run/img/share/what-is-wcode\.en\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/en/blog/what-is-wcode/index.html
	test -f $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	test -f $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'property="og:type" content="article"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'property="og:site_name" content="Francis Du"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'property="og:locale" content="en_US"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq 'property="og:image" content="https://francis.run/img/share/jev-wcode-scopwis\.en\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq 'property="og:image:secure_url" content="https://francis.run/img/share/jev-wcode-scopwis\.en\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'property="og:image:type" content="image/png"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'property="og:image:width" content="1200"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'property="og:image:height" content="630"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'property="og:image:alt" content="Using Jev in wcode and Scopwis"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'name=twitter:card content="summary_large_image"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'name=twitter:site content="@francis_run"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq 'name=twitter:image content="https://francis.run/img/share/jev-wcode-scopwis\.en\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -q 'name=twitter:image:alt content="Using Jev in wcode and Scopwis"' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq '"image":\["https://francis.run/img/share/jev-wcode-scopwis\.en\.[0-9a-f]{64}\.png"\]' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq 'sharer/sharer\.php\?u=https%3A%2F%2Ffrancis\.run%2Fen%2Fblog%2Fjev-wcode-scopwis%2F%3Fshare%3D[0-9]+' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq 'twitter\.com/intent/tweet\?text=.*url=https%3A%2F%2Ffrancis\.run%2Fen%2Fblog%2Fjev-wcode-scopwis%2F%3Fshare%3D[0-9]+' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq 'linkedin\.com/sharing/share-offsite/\?url=https%3A%2F%2Ffrancis\.run%2Fen%2Fblog%2Fjev-wcode-scopwis%2F%3Fshare%3D[0-9]+' $(BUILD_DIR)/en/blog/jev-wcode-scopwis/index.html
	grep -Eq 'itemprop=image content="https://francis.run/img/share/jev-wcode-scopwis\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	grep -Eq 'rel=image_src href=https://francis.run/img/share/jev-wcode-scopwis\.[0-9a-f]{64}\.png' $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	grep -q 'service.weibo.com/share/share.php?' $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	grep -q 'aria-label=分享到微博' $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	grep -q 'data-native-share' $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	grep -q 'aria-label=分享到微信、QQ、小红书等' $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	grep -q '/js/social-share.' $(BUILD_DIR)/blog/jev-wcode-scopwis/index.html
	! grep -q '/js/social-share.' $(BUILD_DIR)/about/index.html
	test -n "$$(find $(BUILD_DIR)/js -type f -name 'social-share.*.js' -print -quit)"
	test -f $(BUILD_DIR)/img/share-default.png
	for source in content/blogs/*wcode*.md; do \
		card="$$(basename "$$source" .md).png"; \
		test -f "static/img/share/$$card" && \
		cmp "static/img/share/$$card" "$(BUILD_DIR)/img/share/$$card" || exit 1; \
	done
	test -f $(BUILD_DIR)/blog/wiki-graph/index.html
	grep -Eq 'property="og:image" content="https://francis.run/img/share-default\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/blog/wiki-graph/index.html
	grep -q 'name=twitter:card content="summary_large_image"' $(BUILD_DIR)/blog/wiki-graph/index.html
	grep -Eq 'name=twitter:image content="https://francis.run/img/share-default\.[0-9a-f]{64}\.png"' $(BUILD_DIR)/blog/wiki-graph/index.html
	grep -Eq '"image":\["https://francis.run/img/share-default\.[0-9a-f]{64}\.png"\]' $(BUILD_DIR)/blog/wiki-graph/index.html
	grep -Fq '.markdown figure.content-image' assets/css/main.css
	for image in architecture evidence access activity; do \
		test ! -L "static/img/wcode/wcode-intro-$$image.png" && \
		cmp "static/img/wcode/wcode-intro-$$image.png" "$(BUILD_DIR)/img/wcode/wcode-intro-$$image.png" || exit 1; \
	done
	for diagram in intelligence-stack engineering-loop verification-mesh security-boundary; do \
		for lang in "" ".zh-CN"; do \
			test ! -L "static/img/wcode/wcode-intro-$$diagram$$lang.svg" && \
			cmp "static/img/wcode/wcode-intro-$$diagram$$lang.svg" "$(BUILD_DIR)/img/wcode/wcode-intro-$$diagram$$lang.svg" || exit 1; \
		done; \
		grep -q "/img/wcode/wcode-intro-$$diagram.zh-CN.svg" $(BUILD_DIR)/blog/what-is-wcode/index.html && \
		grep -q "/img/wcode/wcode-intro-$$diagram.svg" $(BUILD_DIR)/en/blog/what-is-wcode/index.html || exit 1; \
	done
	grep -q 'alt="wcode Architecture" loading=lazy decoding=async' $(BUILD_DIR)/blog/wcode-v0-6/index.html
	grep -q 'srcset=' $(BUILD_DIR)/blog/wcode-v0-6/index.html
	grep -q '960w' $(BUILD_DIR)/blog/wcode-v0-6/index.html
	grep -q '1800w' $(BUILD_DIR)/blog/wcode-v0-6/index.html
	grep -q 'width=3232 height=1932' $(BUILD_DIR)/blog/wcode-v0-6/index.html
	test -f $(BUILD_DIR)/img/wcode/wcode-architecture.png
	grep -q 'sharer/sharer.php?u=https' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'twitter.com/intent/tweet?text=' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'linkedin.com/sharing/share-offsite/?url=https' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q 'mailto:?body=' $(BUILD_DIR)/blog/what-is-wcode/index.html
	! grep -qi 'sharer/sharer.php?u%3d' $(BUILD_DIR)/blog/what-is-wcode/index.html
	! grep -qi 'twitter.com/intent/tweet?text%3d' $(BUILD_DIR)/blog/what-is-wcode/index.html
	! grep -qi 'sharing/share-offsite/?url%3d' $(BUILD_DIR)/blog/what-is-wcode/index.html
	! grep -qi 'mailto:?body%3d' $(BUILD_DIR)/blog/what-is-wcode/index.html
	grep -q '/js/comments.' $(BUILD_DIR)/blog/what-is-wcode/index.html
	! grep -q '/js/comments.' $(BUILD_DIR)/about/index.html
	test -n "$$(find $(BUILD_DIR)/js -type f -name 'comments.*.js' -print -quit)"
	! grep -q '0001-01-01' $(BUILD_DIR)/about/index.html
	! grep -q '0001-01-01' $(BUILD_DIR)/en/about/index.html
	! grep -q 'id=share-buttons' $(BUILD_DIR)/about/index.html
	! grep -q 'id=share-buttons' $(BUILD_DIR)/en/about/index.html
	! grep -q 'article-meta' $(BUILD_DIR)/about/index.html
	! grep -q 'article-meta' $(BUILD_DIR)/en/about/index.html
	! grep -q 'id=utteranc' $(BUILD_DIR)/about/index.html
	! grep -q 'id=utteranc' $(BUILD_DIR)/en/about/index.html
	grep -Fq '{{< profile-about >}}' content/about.md
	grep -Fq '{{< profile-about >}}' content/about.en.md
	grep -q 'data-profile-id=data-agent' $(BUILD_DIR)/about/index.html
	grep -q 'data-profile-id=data-agent' $(BUILD_DIR)/en/about/index.html
	grep -q 'data-profile-id=wcode' $(BUILD_DIR)/about/index.html
	grep -q 'data-profile-id=wcode' $(BUILD_DIR)/en/about/index.html
	grep -q 'DataFusion Python' $(BUILD_DIR)/about/index.html
	grep -q 'DataFusion Python' $(BUILD_DIR)/en/about/index.html
	! grep -qi 'wiki-graph' $(BUILD_DIR)/about/index.html
	! grep -qi 'wiki-graph' $(BUILD_DIR)/en/about/index.html
	grep -q 'class=gallery-page' $(BUILD_DIR)/gallery/index.html
	grep -q '/css/gallery.min.' $(BUILD_DIR)/gallery/index.html
	! grep -q '/css/gallery.min.' $(BUILD_DIR)/index.html
	! grep -q '/js/gallery.js' $(BUILD_DIR)/gallery/index.html
	grep -q 'data-rel=gallery-' $(BUILD_DIR)/gallery/index.html
	grep -q 'data-cfasync=false src=/shortcode-gallery/jquery-3.7.1.min.js' $(BUILD_DIR)/gallery/index.html
	grep -q 'data-cfasync=false src=/shortcode-gallery/swipebox/js/jquery.swipebox.min.js' $(BUILD_DIR)/gallery/index.html
	grep -q 'fetchpriority=high' $(BUILD_DIR)/gallery/index.html
	grep -q 'loading=lazy decoding=async' $(BUILD_DIR)/gallery/index.html
	grep -q 'E-M1MarkIII' $(BUILD_DIR)/gallery/index.html
	grep -q 'iPhone 16 Pro' $(BUILD_DIR)/gallery/index.html
	grep -q '03CA6601-3101-4025-9EC7-04118AF9A746' $(BUILD_DIR)/gallery/index.html
	grep -q 'width=540 height=720' $(BUILD_DIR)/gallery/index.html
	! grep -q '251773/37217mm' $(BUILD_DIR)/gallery/index.html
	! test -f $(BUILD_DIR)/gallery/images/xilinhot/P7050002.jpg
	! grep -q '<style>.jg-entry img' $(BUILD_DIR)/gallery/index.html
	grep -q 'shortcode-gallery/justified_gallery/jquery.justifiedGallery.min.js' $(BUILD_DIR)/gallery/index.html
	test -f $(BUILD_DIR)/shortcode-gallery/justified_gallery/jquery.justifiedGallery.min.js
	! test -f $(BUILD_DIR)/shortcode-gallery/justified_gallery/jquery.justifiedGallery.js
	! test -f $(BUILD_DIR)/shortcode-gallery/lazy/jquery.lazy.js
	! test -f $(BUILD_DIR)/shortcode-gallery/lazy/jquery.lazy.min.js
	! grep -q 'jquery.lazy.min.js' $(BUILD_DIR)/gallery/index.html
	! test -f $(BUILD_DIR)/shortcode-gallery/swipebox/js/jquery.swipebox.js
	! grep -q 'id=share-buttons' $(BUILD_DIR)/gallery/index.html
	! grep -q 'related-posts' $(BUILD_DIR)/gallery/index.html
	test "$$(find $(BUILD_DIR) -type f | wc -l | tr -d ' ')" -le "$(CLOUDFLARE_FILE_LIMIT)"
	test -z "$$(find $(BUILD_DIR) -type f -size +$(CLOUDFLARE_MAX_FILE_BYTES)c -print -quit)"

build:
	hugo $(HUGO_BUILD_FLAGS) --cleanDestinationDir --destination public

cloudflare:
	@if [ "$$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then git fetch --unshallow; fi
	git submodule update --init --recursive
	$(MAKE) check BUILD_DIR=public HUGO_CACHE_DIR=$(CURDIR)/.cache/hugo
	cp deploy/cloudflare/_headers public/_headers
	test -f public/_headers
