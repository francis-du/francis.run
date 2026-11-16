// Run the shipped script in a small browser model; never rewrite production assets.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "assets/js/main.js"), "utf8");
const css = fs.readFileSync(path.join(root, "assets/css/article-toc.css"), "utf8");
const breakpoint = 1180;
const widths = [0, 1, 240, 320, 390, 640, 768, 1024, 1179, 1180, 1181, 1440, 1920, 4096];

function page(script, width, { hasToc = true, hasToggle = false } = {}) {
  const ready = [];
  const mediaQueries = [];
  const windowListeners = new Map();
  let currentWidth = width;
  let open = false;
  const toc = {
    get open() { return open; },
    set open(value) { open = Boolean(value); }
  };
  const toggle = {
    className: "",
    dataset: { lightLabel: "Light theme", darkLabel: "Dark theme" },
    getAttribute() { return ""; },
    setAttribute() {},
    addEventListener() {}
  };
  const html = { classList: { add() {}, remove() {} } };
  const document = {
    addEventListener(type, callback) {
      if (type === "DOMContentLoaded") ready.push(callback);
    },
    getElementById(id) {
      return id === "scheme-toggle" && hasToggle ? toggle : null;
    },
    getElementsByTagName() { return [html]; },
    querySelector(selector) {
      return selector === ".article-toc" && hasToc ? toc : null;
    }
  };
  const window = {
    addEventListener(type, callback) {
      if (!windowListeners.has(type)) windowListeners.set(type, []);
      windowListeners.get(type).push(callback);
    },
    matchMedia(query) {
      if (query === "(prefers-color-scheme: dark)") return { matches: false };
      const match = /^\(min-width:\s*(\d+)px\)$/.exec(query);
      if (!match) throw new Error("Unexpected media query: " + query);
      const minimum = Number(match[1]);
      const listeners = new Map();
      const media = {
        matches: currentWidth >= minimum,
        addEventListener(type, callback) {
          if (!listeners.has(type)) listeners.set(type, []);
          listeners.get(type).push(callback);
        }
      };
      mediaQueries.push({ media, minimum, listeners });
      return media;
    }
  };
  const context = vm.createContext({
    document, window,
    localStorage: { getItem() { return null; }, setItem() {} }
  });
  script.runInContext(context, { timeout: 1000 });
  for (const callback of ready) callback();
  return {
    toc,
    viewportQueryCount() { return mediaQueries.length; },
    resize(nextWidth) {
      currentWidth = nextWidth;
      for (const { media, minimum, listeners } of mediaQueries) {
        const matches = nextWidth >= minimum;
        // MediaQueryList emits change only when its match result changes.
        if (matches === media.matches) continue;
        media.matches = matches;
        for (const callback of listeners.get("change") || []) {
          callback({ matches, target: media });
        }
      }
      for (const callback of windowListeners.get("resize") || []) callback();
    }
  };
}

function contract(script) {
  let assertions = 0;
  const check = (actual, expected, message) => {
    assert.equal(actual, expected, message);
    assertions += 1;
  };

  // Initial defaults must work with or without the independent theme control.
  for (const width of widths) {
    for (const hasToggle of [false, true]) {
      const view = page(script, width, { hasToggle });
      check(view.toc.open, width >= breakpoint, "initial disclosure at " + width);
    }
  }

  // Every pair exercises both directions, equal widths, and both manual choices.
  for (const before of widths) {
    for (const after of widths) {
      for (const manualOpen of [false, true]) {
        const view = page(script, before);
        view.toc.open = manualOpen;
        view.resize(after);
        const crossed = (before >= breakpoint) !== (after >= breakpoint);
        const expected = crossed ? after >= breakpoint : manualOpen;
        check(view.toc.open, expected,
          "manual=" + manualOpen + ", resize " + before + " -> " + after);
      }
    }
  }

  // Repeated crossings must keep working after manual changes and prior events.
  for (const history of [
    [390, 1179, 1180, 1181, 1440, 1179, 320, 1180],
    [1920, 1180, 1179, 1180, 4096, 768, 390, 1440]
  ]) {
    const view = page(script, history[0], { hasToggle: true });
    let previous = history[0];
    for (const next of history.slice(1)) {
      view.toc.open = !view.toc.open;
      const manualOpen = view.toc.open;
      view.resize(next);
      const crossed = (previous >= breakpoint) !== (next >= breakpoint);
      check(view.toc.open, crossed ? next >= breakpoint : manualOpen,
        "repeated resize " + previous + " -> " + next);
      previous = next;
    }
  }

  // Short articles and non-article pages have no TOC.
  for (const width of [390, 1180, 1920]) {
    for (const hasToggle of [false, true]) {
      const view = page(script, width, { hasToc: false, hasToggle });
      view.resize(width < breakpoint ? 1440 : 390);
      check(view.viewportQueryCount(), 0, "no TOC must not install layout observers");
    }
  }
  return assertions;
}

function compile(code, name) {
  return new vm.Script(code, { filename: name });
}

assert.match(css, /@media\s*\(min-width:\s*1180px\)/,
  "CSS must use the same documented desktop boundary");
const mode = process.argv[2];
assert.ok(mode === "property" || mode === "mutation", "use property or mutation");
const baselineAssertions = contract(compile(source, "assets/js/main.js"));

if (mode === "property") {
  console.log("TOC property: " + baselineAssertions + " assertions passed across " +
    widths.length + " viewport widths, manual actions, repeated crossings and no-TOC pages.");
} else {
  const assignment = "articleToc.open = desktopToc.matches;";
  const listener = 'desktopToc.addEventListener("change", syncTocLayout);';
  const mutants = [
    ["inverted layout", assignment, "articleToc.open = !desktopToc.matches;"],
    ["always open", assignment, "articleToc.open = true;"],
    ["always closed", assignment, "articleToc.open = false;"],
    ["missing initial state", "\n    syncTocLayout();\n", "\n    // initial sync omitted\n"],
    ["missing breakpoint listener", listener, "// listener omitted"],
    ["reset manual choice on every resize", listener,
      'window.addEventListener("resize", syncTocLayout);'],
    ["off-by-one breakpoint", "(min-width: 1180px)", "(min-width: 1181px)"],
    ["never close after desktop", assignment,
      "if (desktopToc.matches) articleToc.open = true;"]
  ];
  for (const [name, before, after] of mutants) {
    assert.equal(source.split(before).length - 1, 1,
      "mutation anchor must be unique: " + name);
    // Compilation happens outside the kill check. Syntax errors never count.
    const script = compile(source.replace(before, after), "mutant: " + name);
    let killed = false;
    try {
      contract(script);
    } catch (error) {
      // An executed behavioral assertion must reject it; runtime crashes do not count.
      if (!(error instanceof assert.AssertionError)) throw error;
      killed = true;
      console.log("Rejected: " + name);
    }
    assert.ok(killed, "behavioral mutant survived: " + name);
  }
  console.log("TOC mutation: " + mutants.length + "/" + mutants.length +
    " executable mutants rejected; baseline " + baselineAssertions + " assertions passed.");
}
