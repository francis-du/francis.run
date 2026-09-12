(function () {
  "use strict";

  var article = document.querySelector("main.post[data-copy-code]");
  if (!article) return;

  var copyLabel = article.dataset.copyCode || "Copy";
  var copiedLabel = article.dataset.copiedCode || "Copied";
  var failedLabel = article.dataset.copyFailed || "Copy failed";
  var resetTimers = new WeakMap();

  function fallbackCopy(text) {
    var textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    textarea.style.pointerEvents = "none";
    document.body.appendChild(textarea);
    textarea.select();
    textarea.setSelectionRange(0, textarea.value.length);
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (_) {}
    textarea.remove();
    return ok;
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).then(function () { return true; }, function () {
        return fallbackCopy(text);
      });
    }
    return Promise.resolve(fallbackCopy(text));
  }

  function updateButton(button, label, state) {
    button.textContent = label;
    button.dataset.state = state;
    button.setAttribute("aria-label", label);
    window.clearTimeout(resetTimers.get(button));
    if (state !== "idle") {
      resetTimers.set(button, window.setTimeout(function () {
        updateButton(button, copyLabel, "idle");
      }, 1800));
    }
  }

  article.querySelectorAll(".markdown .highlight").forEach(function (block) {
    var pre = block.querySelector("pre");
    if (!pre || block.querySelector(":scope > .code-copy")) return;

    var button = document.createElement("button");
    button.type = "button";
    button.className = "code-copy";
    updateButton(button, copyLabel, "idle");
    button.addEventListener("click", function () {
      copyText(pre.innerText).then(function (ok) {
        updateButton(button, ok ? copiedLabel : failedLabel, ok ? "copied" : "failed");
      });
    });
    block.appendChild(button);
  });
})();
