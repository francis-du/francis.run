#!/usr/bin/env python3
"""Verify bilingual exhibition routes, artwork coverage and published assets."""
import json
import sys
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

root = Path(sys.argv[1])
data = {name: json.loads(Path(f"data/photography/{name}.json").read_text())
        for name in ("rooms", "works", "guide")}
rooms = data["rooms"]
all_ids = [str(i) for room in rooms for i in room["ids"]]
assert len(rooms) == 3
assert len(all_ids) == 175 and len(set(all_ids)) == 175
assert set(all_ids) == set(data["works"])
assert len({work["file"] for work in data["works"].values()}) == 175

class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.tags = []
        self.text = path.read_text()
        self.feed(self.text)

    def handle_starttag(self, tag, attrs):
        self.tags.append((tag, dict(attrs)))

    def matching(self, tag, key=None, value=None):
        return [attrs for name, attrs in self.tags if name == tag
                and (key is None or (key in attrs and
                     (value is None or attrs[key] == value)))]

    def assets_exist(self):
        for tag, attrs in self.tags:
            url = attrs.get("src", "")
            if tag == "a" and "data-viewer" in attrs:
                url = attrs["href"]
            if url.startswith("/"):
                assert (root / unquote(urlsplit(url).path).lstrip("/")).is_file(), url

for prefix, language in [("", "zh-CN"), ("en/", "en-US")]:
    entrance = Page(root / prefix / "gallery/index.html")
    assert entrance.matching("html", "lang", language)
    assert entrance.matching("body", "class", "exhibition")
    assert entrance.matching("img", "fetchpriority", "high")
    assert len(entrance.matching("img", "fetchpriority", "high")) == 1
    assert not entrance.matching("figure", "class", "ex-work")
    assert entrance.matching("section", "id", "statement")
    assert entrance.matching("section", "id", "floorplan")
    assert data["guide"]["en" if prefix else "zh"] in entrance.text
    entrance.assets_exist()
    for room in rooms:
        assert len(room["hang"]) > 0
        selected = [str(i) for panel in room["hang"] for i in panel["ids"]]
        assert set(selected) == set(map(str, room["ids"]))
        assert len(selected) == len(set(selected))
        page = Page(root / prefix / "exhibition" / room["id"] / "index.html")
        assert page.matching("html", "lang", language)
        assert len(page.matching("section", "class", "ex-wall")) == len(room["hang"])
        assert len(page.matching("figure", "class", "ex-work")) == len(selected)
        assert not page.matching("details")
        assert not page.matching("figure", "class", "ex-catalogue-work")
        assert page.matching("dialog", "id", "ex-viewer")
        quote_url = room["quote"]["url"]
        if quote_url.startswith("/"):
            quote_url = "/" + prefix + quote_url.lstrip("/")
        assert any(unquote(a.get("href", "")) == quote_url for a in page.matching("a"))
        assert page.matching("link", "hreflang", "en-US")
        assert page.matching("link", "hreflang", "zh-CN")
        assert "/js/exhibition." in page.text
        assert "jquery" not in page.text.lower()
        assert "%!" not in page.text, "Go template formatting error"
        for link in page.matching("a", "data-viewer"):
            assert ".jpg" not in link["data-caption"].lower()
            assert link["data-caption"].strip()
        assert "images/xilinhot" not in page.text and "images/yunnan" not in page.text
        for image in page.matching("img", "loading", "lazy"):
            assert int(image["width"]) > 0 and int(image["height"]) > 0
            assert image["alt"]
        page.assets_exist()
    # Every room is reachable from the plan in the matching language.
    for room in rooms:
        assert entrance.matching("a", "href", "/" + prefix + "exhibition/" + room["id"] + "/")
assert not list((root / "gallery/images").rglob("*.jpg"))
assert not (root / "gallery/images/xilinhot").exists()
assert not (root / "gallery/images/yunnan").exists()
assert not (root / "gallery/cover.png").exists()
print("Exhibition verified: 2 languages, 3 chapters, all 175 works on the walls, no collapsed catalogue.")
