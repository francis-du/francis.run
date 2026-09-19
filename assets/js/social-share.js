document.addEventListener("DOMContentLoaded", function () {
  var button = document.querySelector("[data-native-share]");
  if (!button) return;

  var url = button.dataset.shareUrl || window.location.href;
  var title = button.dataset.shareTitle || document.title;
  var text = button.dataset.shareText || "";
  var defaultLabel = button.getAttribute("aria-label") || "";
  var copiedLabel = button.dataset.copiedLabel || defaultLabel;

  button.addEventListener("click", async function () {
    try {
      if (navigator.share) {
        await navigator.share({ title: title, text: text, url: url });
        return;
      }

      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(url);
        button.setAttribute("aria-label", copiedLabel);
        button.setAttribute("title", copiedLabel);
        window.setTimeout(function () {
          button.setAttribute("aria-label", defaultLabel);
          button.setAttribute("title", defaultLabel);
        }, 1800);
      }
    } catch (error) {
      if (error && error.name === "AbortError") return;
      console.warn("Share failed", error);
    }
  });
});
