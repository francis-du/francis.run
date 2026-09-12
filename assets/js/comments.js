(function () {
  var root = document.getElementById("utteranc");
  if (!root) return;

  var loaded = false;
  var observer;

  function loadUtterances() {
    if (loaded) return;
    loaded = true;
    if (observer) observer.disconnect();

    var script = document.createElement("script");
    script.src = "https://utteranc.es/client.js";
    script.async = true;
    script.crossOrigin = "anonymous";
    script.setAttribute("repo", "francis-du/francis.run");
    script.setAttribute("issue-term", "title");
    script.setAttribute("label", "blog");
    script.setAttribute("theme", document.documentElement.classList.contains("dark") ? "github-dark" : "github-light");
    root.appendChild(script);
  }

  if ("IntersectionObserver" in window) {
    observer = new IntersectionObserver(function (entries) {
      if (entries.some(function (entry) { return entry.isIntersecting; })) loadUtterances();
    }, { rootMargin: "600px 0px" });
    observer.observe(root);
  } else {
    loadUtterances();
  }
})();