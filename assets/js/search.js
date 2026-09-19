(function () {
  "use strict";

  var modal = document.getElementById("site-search-dialog");
  var widgets = document.querySelectorAll("search-modal-snippet, chat-bubble-snippet");

  if (!modal) return;

  function currentTheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light";
  }

  function syncTheme() {
    var theme = currentTheme();
    for (var i = 0; i < widgets.length; i += 1) {
      widgets[i].setAttribute("theme", theme);
    }
  }

  function openSearch() {
    if (typeof modal.open === "function") {
      modal.open();
      return;
    }

    if (window.customElements && typeof window.customElements.whenDefined === "function") {
      window.customElements.whenDefined("search-modal-snippet").then(function () {
        if (typeof modal.open === "function") modal.open();
      });
    }
  }

  syncTheme();

  if (typeof window.MutationObserver === "function") {
    new window.MutationObserver(syncTheme).observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"]
    });
  }

  document.addEventListener("keydown", function (event) {
    var target = event.target;
    var editable = target && (
      target.isContentEditable ||
      /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName)
    );
    var slash = event.key === "/" &&
      !editable &&
      !event.metaKey &&
      !event.ctrlKey &&
      !event.altKey;

    if (!slash) return;

    event.preventDefault();
    openSearch();
  });
})();
