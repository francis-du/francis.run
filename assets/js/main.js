document.addEventListener("DOMContentLoaded", function(){
  var toggle = document.getElementById("scheme-toggle");
  var progress = document.getElementById("reading-progress-bar");
  if (progress) {
    var updateProgress = function () {
      var height = document.documentElement.scrollHeight - window.innerHeight;
      var value = height > 0 ? Math.min(100, (window.scrollY / height) * 100) : 0;
      progress.style.width = value + "%";
    };
    updateProgress();
    window.addEventListener("scroll", updateProgress, { passive: true });
    window.addEventListener("resize", updateProgress);
  }

  if (!toggle) { return; }

  var scheme = "light";
  var savedScheme = localStorage.getItem("scheme");

  var container = document.getElementsByTagName("html")[0];
  var prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;

  if (prefersDark) {
    scheme = "dark";
  }

  if(savedScheme) {
    scheme = savedScheme;
  }

  if(scheme == "dark") {
    darkscheme(toggle, container);
  } else {
    lightscheme(toggle, container);
  }

  toggle.addEventListener("click", (event) => {
    event.preventDefault();
    if (toggle.className === "light") {
      darkscheme(toggle, container);
    } else if (toggle.className === "dark") {
      lightscheme(toggle, container);
    }
  });
});

function setToggleLabel(toggle, key) {
  var label = toggle.dataset[key] || toggle.getAttribute("aria-label") || "";
  toggle.setAttribute("aria-label", label);
  toggle.setAttribute("title", label);
}

function syncUtterancesTheme(scheme) {
  var frame = document.querySelector(".utterances-frame");
  if (!frame || !frame.contentWindow) return;
  frame.contentWindow.postMessage({
    type: "set-theme",
    theme: scheme === "dark" ? "github-dark" : "github-light"
  }, "https://utteranc.es");
}

function darkscheme(toggle, container) {
  localStorage.setItem("scheme", "dark");
  toggle.className = "dark";
  setToggleLabel(toggle, "lightLabel");
  container.classList.add("dark");
  syncUtterancesTheme("dark");
}

function lightscheme(toggle, container) {
  localStorage.setItem("scheme", "light");
  toggle.className = "light";
  setToggleLabel(toggle, "darkLabel");
  container.classList.remove("dark");
  syncUtterancesTheme("light");
}
