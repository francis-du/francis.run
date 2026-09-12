(function () {
  "use strict";

  var overlay = document.getElementById("site-search-dialog");
  var form = document.getElementById("site-search-form");
  var input = document.getElementById("search-input");
  var status = document.getElementById("search-status");
  var resultsRoot = document.getElementById("search-results");
  var closeButton = overlay && overlay.querySelector("[data-search-close]");

  if (!overlay || !form || !input || !status || !resultsRoot) return;

  var language = document.documentElement.lang || "en";
  var indexPromise = null;
  var debounceTimer = null;
  var returnFocus = null;
  var activeIndex = -1;

  function normalize(value) {
    var text = String(value || "");
    try {
      if (typeof text.normalize === "function") text = text.normalize("NFKC");
    } catch (_) {}
    try {
      return text.toLocaleLowerCase(language);
    } catch (_) {
      return text.toLowerCase();
    }
  }

  function isOpen() {
    return !overlay.hidden;
  }

  function resultItems() {
    return resultsRoot.querySelectorAll(".search-result");
  }

  function clearActiveResult() {
    var items = resultItems();
    for (var i = 0; i < items.length; i += 1) {
      items[i].classList.remove("is-active");
    }
    activeIndex = -1;
    input.removeAttribute("aria-activedescendant");
  }

  function setActiveResult(index, shouldScroll) {
    var items = resultItems();
    if (!items.length) {
      clearActiveResult();
      return;
    }

    if (index < 0) index = items.length - 1;
    if (index >= items.length) index = 0;

    for (var i = 0; i < items.length; i += 1) {
      items[i].classList.toggle("is-active", i === index);
    }

    activeIndex = index;
    input.setAttribute("aria-activedescendant", items[index].id);

    if (shouldScroll !== false) {
      try {
        items[index].scrollIntoView({ block: "nearest" });
      } catch (_) {}
    }
  }

  function clearResults() {
    while (resultsRoot.firstChild) resultsRoot.removeChild(resultsRoot.firstChild);
    clearActiveResult();
  }

  function resetSearch() {
    window.clearTimeout(debounceTimer);
    input.value = "";
    clearResults();
    status.textContent = form.dataset.ready;
  }

  function loadIndex() {
    if (indexPromise) return indexPromise;
    if (typeof window.fetch !== "function") {
      return Promise.reject(new Error("search fetch unsupported"));
    }

    var indexURL = overlay.getAttribute("data-index-url") || "";
    try {
      indexURL = new URL(indexURL, document.baseURI || window.location.href).toString();
    } catch (_) {}

    indexPromise = window.fetch(indexURL, {
      credentials: "same-origin",
      headers: { Accept: "application/json" }
    })
      .then(function (response) {
        if (!response.ok) throw new Error("search index unavailable: " + response.status);
        return response.json();
      })
      .then(function (items) {
        if (!Array.isArray(items)) throw new Error("invalid search index");
        return items.map(function (item) {
          var tags = Array.isArray(item.tags) ? item.tags : [];
          return {
            title: String(item.title || ""),
            url: String(item.url || ""),
            description: String(item.description || ""),
            tags: tags,
            date: String(item.date || ""),
            _title: normalize(item.title),
            _description: normalize(item.description),
            _tags: normalize(tags.join(" ")),
            _content: normalize(item.content)
          };
        });
      })
      .catch(function (error) {
        indexPromise = null;
        throw error;
      });

    return indexPromise;
  }

  function scoreItem(item, tokens) {
    var haystack = [item._title, item._tags, item._description, item._content].join(" ");
    var score = 0;

    for (var i = 0; i < tokens.length; i += 1) {
      var token = tokens[i];
      if (haystack.indexOf(token) === -1) return -1;
      if (item._title.indexOf(token) !== -1) score += 8;
      if (item._tags.indexOf(token) !== -1) score += 5;
      if (item._description.indexOf(token) !== -1) score += 3;
      if (item._content.indexOf(token) !== -1) score += 1;
    }

    return score;
  }

  function renderResults(items, query) {
    clearResults();

    var normalized = normalize(query).trim();
    if (!normalized) {
      status.textContent = form.dataset.ready;
      return;
    }

    var tokens = normalized.split(/\s+/).filter(Boolean);
    var matches = items
      .map(function (item) {
        return { item: item, score: scoreItem(item, tokens) };
      })
      .filter(function (entry) {
        return entry.score >= 0;
      })
      .sort(function (a, b) {
        return b.score - a.score || String(b.item.date).localeCompare(String(a.item.date));
      })
      .slice(0, 30);

    if (!matches.length) {
      status.textContent = form.dataset.empty + " “" + query + "”";
      return;
    }

    status.textContent = matches.length + " " + (matches.length === 1 ? form.dataset.resultSingular : form.dataset.resultPlural);

    matches.forEach(function (match, index) {
      var item = match.item;
      var li = document.createElement("li");
      li.className = "search-result";
      li.id = "search-result-" + index;

      var link = document.createElement("a");
      link.className = "search-result-link";
      link.href = item.url;

      var meta = document.createElement("div");
      meta.className = "search-result-meta";

      if (item.date) {
        var time = document.createElement("time");
        time.dateTime = item.date;
        time.textContent = item.date;
        meta.appendChild(time);
      }

      item.tags.slice(0, 4).forEach(function (tag) {
        var span = document.createElement("span");
        span.textContent = "#" + tag;
        meta.appendChild(span);
      });

      var title = document.createElement("h2");
      title.textContent = item.title;

      link.appendChild(meta);
      link.appendChild(title);

      if (item.description) {
        var description = document.createElement("p");
        description.textContent = item.description;
        link.appendChild(description);
      }

      li.appendChild(link);
      li.addEventListener("pointerenter", function () {
        setActiveResult(index, false);
      });
      resultsRoot.appendChild(li);
    });

    setActiveResult(0, false);
  }

  function search(query) {
    var value = String(query || "").trim();
    if (!value) {
      clearResults();
      status.textContent = form.dataset.ready;
      return;
    }

    status.textContent = form.dataset.loading;
    loadIndex()
      .then(function (items) {
        renderResults(items, value);
      })
      .catch(function () {
        clearResults();
        status.textContent = form.dataset.error;
      });
  }

  function openSearch() {
    if (isOpen()) {
      input.focus();
      input.select();
      return;
    }

    returnFocus = document.activeElement;
    overlay.hidden = false;
    document.documentElement.classList.add("search-open");

    window.setTimeout(function () {
      input.focus();
      input.select();
    }, 0);
  }

  function closeSearch() {
    if (!isOpen()) return;

    resetSearch();
    overlay.hidden = true;
    document.documentElement.classList.remove("search-open");

    if (returnFocus && typeof returnFocus.focus === "function") {
      returnFocus.focus();
    }
    returnFocus = null;
  }

  function focusableElements() {
    return overlay.querySelectorAll("button:not([disabled]), input:not([disabled]), a[href]");
  }

  input.addEventListener("input", function () {
    window.clearTimeout(debounceTimer);
    debounceTimer = window.setTimeout(function () {
      search(input.value);
    }, 120);
  });

  input.addEventListener("keydown", function (event) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActiveResult(activeIndex + 1);
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      setActiveResult(activeIndex - 1);
      return;
    }

    if (event.key === "Enter" && activeIndex >= 0) {
      var items = resultItems();
      var link = items[activeIndex] && items[activeIndex].querySelector("a[href]");
      if (link) {
        event.preventDefault();
        window.location.href = link.href;
      }
    }
  });

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    window.clearTimeout(debounceTimer);
    search(input.value);
  });

  if (closeButton) closeButton.addEventListener("click", closeSearch);

  overlay.addEventListener("click", function (event) {
    if (event.target === overlay) closeSearch();
  });

  document.addEventListener("keydown", function (event) {
    var target = event.target;
    var editable = target && (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName));
    var commandK = (event.metaKey || event.ctrlKey) && String(event.key).toLowerCase() === "k";
    var slash = event.key === "/" && !editable && !event.metaKey && !event.ctrlKey && !event.altKey;

    if (commandK || slash) {
      event.preventDefault();
      openSearch();
      return;
    }

    if (event.key === "Escape" && isOpen()) {
      event.preventDefault();
      closeSearch();
      return;
    }

    if (event.key === "Tab" && isOpen()) {
      var focusable = focusableElements();
      if (!focusable.length) return;
      var first = focusable[0];
      var last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
  });
})();