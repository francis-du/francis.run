(() => {
  const dialog = document.querySelector("#ex-viewer");
  if (!dialog || typeof dialog.showModal !== "function") return;
  const links = [...document.querySelectorAll("[data-viewer]")];
  const unique = [...new Map(links.map(link => [link.href, link])).values()];
  const image = dialog.querySelector("#ex-viewer-image");
  const caption = dialog.querySelector("#ex-viewer-caption");
  const count = dialog.querySelector("#ex-viewer-count");
  let position = 0;
  let trigger;
  function show(index) {
    position = (index + unique.length) % unique.length;
    const link = unique[position];
    image.src = link.href;
    image.alt = link.dataset.alt;
    caption.textContent = link.dataset.caption;
    count.textContent = (position + 1) + " / " + unique.length;
  }
  links.forEach(link => link.addEventListener("click", event => {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    trigger = link;
    show(unique.findIndex(item => item.href === link.href));
    dialog.showModal();
    document.body.classList.add("ex-viewer-open");
  }));
  dialog.querySelector("[data-close]").addEventListener("click", () => dialog.close());
  dialog.querySelector("[data-prev]").addEventListener("click", () => show(position - 1));
  dialog.querySelector("[data-next]").addEventListener("click", () => show(position + 1));
  dialog.addEventListener("keydown", event => {
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
      show(position + (event.key === "ArrowRight" ? 1 : -1));
    }
  });
  dialog.addEventListener("close", () => {
    document.body.classList.remove("ex-viewer-open");
    trigger?.focus();
    image.removeAttribute("src");
  });
})();
