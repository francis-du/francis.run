#!/usr/bin/env python3
"""Verify registered photography collections and their published exhibition pages."""
import json
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

root = Path(sys.argv[1])
registry = json.loads(Path("data/photography/collections.json").read_text())
assert registry, "Register at least one photography collection"
assert len({entry["id"] for entry in registry}) == len(registry), "Duplicate collection ID"
assert len({entry["data_key"] for entry in registry}) == len(registry), "Duplicate data key"
missing_exif = {
    "zh": "原文件未包含 EXIF 信息",
    "en": "No EXIF data in the original file.",
}
languages = [
    ("", "zh-CN", "zh", "弗朗摩斯", "Francis Du"),
    ("en/", "en-US", "en", "Francis Du", "弗朗摩斯"),
]


def normalized(text):
    return " ".join(text.split())


def localized(url, prefix):
    return "/" + prefix + url.lstrip("/")


def published_page(url, prefix):
    path = unquote(urlsplit(localized(url, prefix)).path).lstrip("/")
    return root / path / "index.html"


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.tags = []
        self.fragments = []
        self.hidden = 0
        self.anchors = []
        self.linked_images = []
        self.text = path.read_text()
        self.feed(self.text)
        self.visible_text = normalized(" ".join(self.fragments))

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append((tag, attrs))
        if tag in ("script", "style"):
            self.hidden += 1
        if tag == "a":
            self.anchors.append(attrs)
        if tag == "img" and self.anchors:
            self.linked_images.append((self.anchors[-1], attrs))

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.hidden = max(0, self.hidden - 1)
        if tag == "a" and self.anchors:
            self.anchors.pop()

    def handle_data(self, text):
        if not self.hidden:
            self.fragments.append(text)

    def matching(self, tag, key=None, value=None):
        return [attrs for name, attrs in self.tags if name == tag
                and (key is None or (key in attrs and
                     (value is None or attrs[key] == value)))]

    def classed(self, tag, class_name):
        return [attrs for name, attrs in self.tags
                if name == tag and class_name in attrs.get("class", "").split()]

    def has_class(self, class_name):
        return any(class_name in attrs.get("class", "").split()
                   for _, attrs in self.tags)

    def assets_exist(self):
        for tag, attrs in self.tags:
            urls = [attrs.get("src", "")]
            if tag == "a" and "data-viewer" in attrs:
                urls.append(attrs["href"])
            if tag == "link" and attrs.get("rel") == "stylesheet":
                urls.append(attrs["href"])
            if tag == "img" and attrs.get("srcset"):
                urls.extend(item.strip().split()[0]
                            for item in attrs["srcset"].split(","))
            for url in urls:
                if url.startswith("/"):
                    path = root / unquote(urlsplit(url).path).lstrip("/")
                    assert path.is_file(), f"Missing published asset: {url}"

    def exhibition_shell(self, language, author, other_author):
        assert self.matching("html", "lang", language)
        assert self.classed("body", "exhibition")
        assert author in self.visible_text and other_author not in self.visible_text
        assert self.matching("link", "hreflang", "en-US")
        assert self.matching("link", "hreflang", "zh-CN")
        assert self.matching("meta", "name", "viewport")
        assert "/js/exhibition." in self.text
        assert "jquery" not in self.text.lower()
        assert "%!" not in self.text, "Go template formatting error"
        assert not self.matching("details"), "Works must not be collapsed"
        assert not self.has_class("ex-wall-label"), "Do not add per-work explanations"
        assert not self.matching("a", "href", ""), "An absent quote URL needs a plain credit"
        assert "images/xilinhot" not in self.text and "images/yunnan" not in self.text
        self.assets_exist()


def check_collection_data(entry):
    folder = Path("data/photography") / entry["data_key"]
    data = {name: json.loads((folder / f"{name}.json").read_text())
            for name in ("rooms", "works", "guide", "selection")}
    rooms, works = data["rooms"], data["works"]
    assert rooms and works, entry["id"]
    assert len({room["id"] for room in rooms}) == len(rooms), "Duplicate room ID"
    assert [room["number"] for room in rooms] == [
        f"{i:02d}" for i in range(1, len(rooms) + 1)
    ], "Room numbers must follow the visit order"
    selected = [str(work_id) for room in rooms for work_id in room["ids"]]
    assert len(selected) == len(set(selected)), "A photograph appears in multiple rooms"
    duplicate_of = {str(key): str(value)
                    for key, value in data["selection"]["duplicate_of"].items()}
    assert not set(selected) & set(duplicate_of), "An omitted duplicate is still on display"
    assert set(selected) | set(duplicate_of) == set(works), (
        "Every source must be exhibited or explicitly linked to its retained duplicate"
    )
    assert set(duplicate_of.values()) <= set(selected), "The retained counterpart is not exhibited"
    assert all(key != value for key, value in duplicate_of.items())
    assert len({work["file"] for work in works.values()}) == len(works)
    owner = Path("content") / entry["page"].strip("/")
    assert (owner / entry["cover"]).is_file(), "Missing collection cover"
    for work in works.values():
        assert (owner / work["file"]).is_file(), work["file"]
        exif = work.get("exif") or ""
        assert isinstance(exif, str), "EXIF must be real metadata or an empty value"
        assert not exif or exif.strip(), "Use an empty value for missing EXIF"
        assert work["source"] not in exif
        assert ".jpg" not in exif.lower()
        assert exif not in missing_exif.values(), "Keep missing EXIF empty in the source data"
        for lang in ("zh", "en"):
            assert work["alt"][lang].strip(), "Missing translated image description"
    for room in rooms:
        assert room["ids"] and room["hang"], "An exhibition room is empty"
        assert [str(i) for panel in room["hang"] for i in panel["ids"]] == [
            str(i) for i in room["ids"]
        ], "Hanging order must match the room sequence"
        for lang in ("zh", "en"):
            assert room["title"][lang].strip(), "Missing translated room title"
        guides = ([room["quote"]] if room.get("quote") else []) + [
            panel["guide"] for panel in room["hang"] if panel.get("guide")
        ]
        for guide in guides:
            for lang in ("zh", "en"):
                assert guide["text"][lang].strip()
                assert guide["source"][lang].strip()
        anchors = [panel["anchor"] for panel in room["hang"] if panel.get("guide")]
        assert len(anchors) == len(set(anchors)), "Transition guides need unique anchors"
    data["_statement"] = {}
    for lang in ("zh", "en"):
        filename = "index.en.md" if lang == "en" else "index.md"
        body = (owner / filename).read_text().split("---", 2)[2].strip()
        data["_statement"][lang] = normalized(body)
        assert body, "A bilingual collection needs its own complete introduction"
    return data


def check_i_a_multitude(data):
    """Protect the artist's reviewed selection, subject boundaries, and visit order."""
    rooms, works = data["rooms"], data["works"]
    inventory = {int(work_id) for work_id in works}
    assert set(range(1, 176)) <= inventory, "Preserve the original 175-work inventory"
    assert set(works) == {str(i) for i in range(1, max(inventory) + 1)}, (
        "Keep the complete source inventory when appending photographs"
    )
    assert [room["id"] for room in rooms] == [
        "proximity", "boundless", "half-alive"
    ], "Keep the three-act emotional sequence"
    duplicate_of = data["selection"]["duplicate_of"]
    assert sum(len(room["ids"]) for room in rooms) == len(works) - len(duplicate_of)
    reviewed_duplicates = {
        "31": 30, "33": 35, "34": 35, "39": 38, "51": 52,
        "81": 82, "83": 82, "89": 85, "113": 112,
        "126": 127, "131": 130, "157": 156, "176": 164, "178": 155,
        "4": 5, "19": 18, "20": 18, "142": 143, "109": 108,
        "29": 28, "88": 85, "86": 85, "84": 82, "90": 91,
        "32": 30, "74": 75, "133": 134, "135": 134, "132": 130,
        "158": 156, "159": 161, "160": 161, "45": 44, "50": 49, "129": 128,
    }
    assert reviewed_duplicates.items() <= duplicate_of.items(), (
        "Keep omitted near-duplicates mapped directly to an exhibited counterpart"
    )
    water_sequence = [144, 76, 77, 87, 85, 82, 91, 25, 1]
    mountain_sequence = [162, 30, 72, 93, 35, 75, 134, 130]
    life_sequence = [
        12, 24, 11, 10, 8, 9, 127, 78, 128, 36, 155, 156,
        161, 115, 163,
    ]
    forest_sequence = [
        2, 152, 153, 55, 56, 61, 41, 40, 37, 63, 46, 47, 38,
        42, 43, 48, 49, 52, 53, 54, 44, 57, 58, 59, 60,
        64, 62, 177,
    ]
    body_sequence = [101, 102, 73, 179, 183, 180, 181, 182, 151]
    # These subject boundaries were checked against the actual photographs.
    reviewed_subjects = {
        "proximity": ({
            3, 4, 5, 6, 7, 13, 15, 16, 17, 18, 19, 20, 21, 26, 27,
            65, 66, 69, 79, 80, 92, 94, 95, 96, 97, 98, 99, 100,
            103, 104, 105, 106, 108, 109, 110, 112, 114, 116, 117,
            119, 120, 123, 124, 125, 136, 137, 138, 140, 142, 143,
            145, 146, 147, 148, 149, 164, 165, 166, 167, 168, 169, 170,
            171, 172, 174, 175,
        } | {14, 22, 23, 28, 67, 68, 70, 71, 107, 111, 118, 121, 122,
             139, 141, 150, 154, 173}) - {4, 19, 20, 109, 142},
        "boundless": set(water_sequence + mountain_sequence),
        "half-alive": set(life_sequence + forest_sequence + body_sequence),
    }
    for room in rooms:
        assert set(room["ids"]) == reviewed_subjects[room["id"]], (
            f"Recheck the subjects assigned to room {room['id']}; do not mix unrelated photographs"
        )
    landscape = rooms[1]
    assert landscape["ids"] == water_sequence + mountain_sequence, (
        "The merged landscape room must move continuously from water to mountains"
    )
    transitions = [panel for panel in landscape["hang"] if panel.get("guide")]
    assert len(transitions) == 1 and transitions[0]["ids"][0] == mountain_sequence[0]
    assert transitions[0]["anchor"] == "mountains"
    assert transitions[0]["guide"]["text"] == data["guide"], (
        "Keep the mountain guide at the transition into mountain photographs"
    )
    final = rooms[-1]
    assert final["title"] == {
        "zh": "一半活着，一半已经死去", "en": "Half Alive, Half Already Dead"
    }
    assert final["ids"] == life_sequence + forest_sequence + body_sequence, (
        "Keep life, forest, and the concluding body sequence in continuous, separate blocks"
    )
    assert final["hang"][-1]["ids"] == [151], "The reaching figure must close on its own"
    assert final["quote"]["text"] == {
        "zh": "我到底\n是活着，还是正在死去\n是死去，还是等待着重生",
        "en": "Am I, after all,\nalive, or in the midst of dying?\nDead, or awaiting rebirth?",
    }, "Preserve the artist's Half Alive questions as the final room guide"

    desire = [panel for panel in final["hang"] if panel.get("guide")]
    assert len(desire) == 1 and desire[0]["ids"] == [73], (
        "Place The Worm at the cover portrait, after the blurred faces and before the body sequence"
    )
    assert desire[0]["anchor"] == "desire"
    worm = Path("content/blogs/蠕虫.md").read_text().rsplit("\n---\n", 1)[-1]
    assert normalized(desire[0]["guide"]["text"]["zh"]) == normalized(worm), (
        "Preserve the artist's final stanza of The Worm without rewriting the poem"
    )
    assert desire[0]["guide"]["source"] == {
        "zh": "弗朗摩斯 · 《蠕虫》（节选）", "en": "Francis Du · The Worm (excerpt)"
    }, "Credit the desire guide to The Worm, separately from Half Alive"


datasets = {entry["id"]: check_collection_data(entry) for entry in registry}
for entry in registry:
    if entry["id"] == "i-a-multitude":
        check_i_a_multitude(datasets[entry["id"]])

total_rooms = total_selected = total_sources = 0
for entry in registry:
    data = datasets[entry["id"]]
    total_rooms += len(data["rooms"])
    total_selected += sum(len(room["ids"]) for room in data["rooms"])
    total_sources += len(data["works"])

for prefix, language, lang, author, other_author in languages:
    for hub_url in ("/gallery/",):
        hub = Page(published_page(hub_url, prefix))
        hub.exhibition_shell(language, author, other_author)
        assert not hub.classed("figure", "ex-work"), "The collection shelf is cover-only"
        assert not hub.matching("section", "id", "statement"), "The guide belongs inside its collection"
        assert not hub.matching("section", "id", "floorplan"), "Room navigation belongs inside its collection"
        for entry in registry:
            collection_url = hub_url + entry["id"] + "/"
            assert datasets[entry["id"]]["_statement"][lang] not in hub.visible_text
            assert any(a.get("href") == localized(collection_url, prefix)
                       and image.get("alt") and int(image.get("width", 0)) > 0
                       and int(image.get("height", 0)) > 0
                       for a, image in hub.linked_images), "The collection cover must be a usable entrance"
            assert not any(a.get("href", "").startswith(localized(collection_url, prefix))
                           and a.get("href") != localized(collection_url, prefix)
                           for a in hub.matching("a")), "Do not put individual rooms on the collection shelf"

    for entry in registry:
        data = datasets[entry["id"]]
        rooms = data["rooms"]
        collection_url = "/gallery/" + entry["id"] + "/"
        entrance = Page(published_page(collection_url, prefix))
        entrance.exhibition_shell(language, author, other_author)
        if entry["id"] == "i-a-multitude":
            assert f"{author} × Chat GPT 6.1 Sol" in entrance.visible_text, "Missing curation credit"
        covers = entrance.matching("img", "fetchpriority", "high")
        assert len(covers) == 1 and author in covers[0]["alt"]
        assert not entrance.classed("figure", "ex-work"), "Keep photographs in their own rooms"
        assert len(entrance.matching("section", "id", "statement")) == 1
        assert entrance.matching("section", "id", "floorplan")
        full_guide = data["_statement"][lang]
        assert entrance.visible_text.count(full_guide) == 1, "Show the complete guide once"
        sections = [attrs.get("id") for name, attrs in entrance.tags if name == "section"]
        assert sections.index("statement") < sections.index("floorplan")
        room_urls = [collection_url + room["id"] + "/" for room in rooms]
        assert entrance.classed("a", "ex-enter")[0]["href"] == localized(room_urls[0], prefix)
        assert [door["href"] for door in entrance.classed("a", "ex-door")] == [
            localized(url, prefix) for url in room_urls
        ], "Every room must have an entrance in the collection guide"
        mountain_guide = normalized(data["guide"].get(lang, ""))
        if mountain_guide:
            assert mountain_guide not in entrance.visible_text, "Keep the mountain guide in its room"

        for index, room in enumerate(rooms):
            selected = list(map(str, room["ids"]))
            page = Page(published_page(room_urls[index], prefix))
            page.exhibition_shell(language, author, other_author)
            assert len(page.classed("section", "ex-wall")) == len(room["hang"])
            assert [figure["data-work-id"] for figure in page.classed("figure", "ex-work")] == selected
            assert not page.has_class("ex-catalogue-work"), "All exhibited work should be visible"
            assert not page.matching("figcaption"), "Leave the space below photographs quiet"
            assert page.matching("dialog", "id", "ex-viewer")
            assert normalized(room["title"][lang]) in page.visible_text
            assert full_guide not in page.visible_text, "The complete guide belongs at the entrance"
            if room.get("quote"):
                quote = room["quote"]
                assert normalized(quote["text"][lang]) in page.visible_text
                assert normalized(quote["source"][lang]) in page.visible_text
                quote_url = quote.get("url", "")
                if quote_url.startswith("#"):
                    quote_url = collection_url + quote_url
                if quote_url.startswith("/"):
                    quote_url = localized(quote_url, prefix)
                if quote_url:
                    assert any(unquote(a.get("href", "")) == quote_url for a in page.matching("a"))
            wall_guides = [panel["guide"] for panel in room["hang"] if panel.get("guide")]
            for n, panel in enumerate(room["hang"]):
                if not panel.get("guide"):
                    continue
                assert normalized(panel["guide"]["text"][lang]) in page.visible_text
                assert normalized(panel["guide"]["source"][lang]) in page.visible_text
                guide_position = next(i for i, (tag, attrs) in enumerate(page.tags)
                                      if tag == "section" and attrs.get("id") == panel["anchor"])
                first_image = next(i for i, (tag, attrs) in enumerate(page.tags)
                                   if tag == "figure" and attrs.get("data-work-id") == str(panel["ids"][0]))
                assert guide_position < first_image, "Place the guide before its subject block"
                if n:
                    previous_image = next(i for i, (tag, attrs) in enumerate(page.tags)
                                          if tag == "figure" and attrs.get("data-work-id") ==
                                          str(room["hang"][n - 1]["ids"][-1]))
                    assert previous_image < guide_position, "Keep the transition after the previous block"
            if mountain_guide:
                all_guides = ([room["quote"]] if room.get("quote") else []) + wall_guides
                expected_guides = sum(guide["text"][lang] == data["guide"][lang] for guide in all_guides)
                assert page.visible_text.count(mountain_guide) == expected_guides, (
                    "The mountain guide must appear only at the mountain photographs"
                )
            links = page.matching("a", "data-viewer")
            assert len(links) == len(selected)
            for work_id, link in zip(selected, links):
                work = data["works"][work_id]
                caption = work.get("exif") or missing_exif[lang]
                assert link["data-caption"] == caption, "Show real EXIF or the localized missing-data label"
                assert work["source"] not in link["data-caption"], "Do not show filenames in the viewer"
            for image in page.matching("img", "loading", "lazy"):
                assert int(image["width"]) > 0 and int(image["height"]) > 0
                assert image["alt"]
            expected_previous = room_urls[index - 1] if index else collection_url
            expected_next = room_urls[index + 1] if index + 1 < len(rooms) else collection_url + "#statement"
            hrefs = {a.get("href") for a in page.matching("a")}
            assert localized(expected_previous, prefix) in hrefs, "Missing route back"
            assert localized(expected_next, prefix) in hrefs, "Missing route onward"
            assert localized(collection_url + "#floorplan", prefix) in hrefs
        if entry["id"] == "i-a-multitude":
            legacy_mountain = Page(published_page(collection_url + "veiling/", prefix))
            canonical = legacy_mountain.matching("link", "rel", "canonical")[0]["href"]
            assert urlsplit(canonical).path == localized(collection_url + "boundless/", prefix)
            assert any(canonical in attrs.get("content", "")
                       for attrs in legacy_mountain.matching("meta", "http-equiv", "refresh")), (
                "Preserve the old mountain-room URL as a redirect into the merged landscape room"
            )
        for resource_url in (entry["page"], collection_url):
            resource_root = root / resource_url.strip("/")
            for work in data["works"].values():
                assert not (resource_root / work["file"]).exists(), "Do not publish the source JPEG"
            assert not (resource_root / entry["cover"]).exists(), "Publish a processed cover"
            assert not (resource_root / "images/xilinhot").exists()
            assert not (resource_root / "images/yunnan").exists()

print(f"Exhibitions verified: {len(registry)} collections, 2 languages, {total_rooms} rooms, "
      f"{total_selected} exhibited works, {total_sources} preserved sources, EXIF captions.")
