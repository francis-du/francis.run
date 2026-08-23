document.addEventListener("DOMContentLoaded", function(){
  // Render feather icons (social links, etc.)
  if (window.feather) {
    feather.replace({ "stroke-width": 2, width: 24, height: 24 });
  }

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

function darkscheme(toggle, container) {
  localStorage.setItem("scheme", "dark");
  toggle.innerHTML = feather.icons.sun.toSvg();
  toggle.className = "dark";
  toggle.setAttribute("aria-label", "切换到浅色模式");
  toggle.setAttribute("title", "切换到浅色模式");
  container.classList.add("dark");
}

function lightscheme(toggle, container) {
  localStorage.setItem("scheme", "light");
  toggle.innerHTML = feather.icons.moon.toSvg();
  toggle.className = "light";
  toggle.setAttribute("aria-label", "切换到深色模式");
  toggle.setAttribute("title", "切换到深色模式");
  container.classList.remove("dark");
}
