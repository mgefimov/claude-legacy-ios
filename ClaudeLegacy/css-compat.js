// CSS compatibility pipeline for older WebKit.
//
// Stylesheets are fetched, run through a list of text transforms and re-injected
// as an inline <style> in the original <link>'s place, so features WebKit cannot
// parse are rewritten before they reach the CSS parser.
//
// The individual fixes live in their own files (css-layer-flatten.js,
// css-viewport-units.js) and register themselves here. Which of them are needed
// is decided natively in -[ViewController injectCSSCompatibilityFixes], so on a
// system new enough these scripts are never injected in the first place; the
// transform list being empty is only a safety net.
//
// Doing the interception once, for all transforms, means each stylesheet is
// fetched once and handed to WebKit once — the fixes never race for the same
// <link> or rewrite each other's output.
//
// Note: re-hosting a stylesheet inline makes relative url() resolve against the
// document instead of the stylesheet. Claude's CSS only uses absolute and data:
// URLs, so this is safe here.
(function () {
  const transforms = [];

  const shortName = (src) => {
    const path = String(src || "").split("?")[0];
    const parts = path.split("/");
    return parts[parts.length - 1] || path;
  };

  const status = (payload) => {
    try {
      window.webkit.messageHandlers.loadingStatus.postMessage(payload);
    } catch (e) {}
  };

  const reportError = (message) => {
    status({ stage: "error", message: String(message), fatal: false });
  };

  const applyTransforms = (css) => {
    let out = css;
    for (let i = 0; i < transforms.length; i++) {
      try {
        out = transforms[i].fn(out);
      } catch (e) {
        // A broken transform must not cost us the whole stylesheet.
        reportError("CSS transform '" + transforms[i].name + "' failed: " +
          (e && e.message ? e.message : e));
      }
    }
    return out;
  };

  window.CSSCompat = {
    register: function (name, fn) {
      transforms.push({ name: name, fn: fn });
    },
    // Exposed so the transform chain can be exercised from the Web Inspector.
    transform: applyTransforms,
    isEnabled: function () {
      return transforms.length > 0;
    },
  };

  // Swap a <link rel=stylesheet> for an inline <style> holding the transformed
  // CSS, inserted at the link's position so the cascade order is preserved.
  const interceptStylesheet = (link) => {
    if (link.__cssCompat) return;
    const href = link.href;
    const parent = link.parentNode;
    if (!href || !parent) return;
    link.__cssCompat = true;

    const styleEl = document.createElement("style");
    styleEl.setAttribute("data-css-compat", shortName(href));
    parent.insertBefore(styleEl, link);
    link.media = "not all"; // stop the untransformed sheet from applying

    status({ stage: "download", file: shortName(href) });

    window.fetch(href)
      .then((r) => r.text())
      .then((text) => {
        styleEl.textContent = applyTransforms(text);
        if (link.parentNode) link.parentNode.removeChild(link);
      })
      .catch((e) => {
        // Fall back to the original stylesheet rather than losing it entirely.
        if (styleEl.parentNode) styleEl.parentNode.removeChild(styleEl);
        link.__cssCompat = false;
        link.media = "all";
        reportError("CSS fetch failed for " + shortName(href) + ": " +
          (e && e.message ? e.message : e));
      });
  };

  const transformInlineStyle = (styleEl) => {
    if (styleEl.__cssCompat) return;
    const text = styleEl.textContent;
    // Leave it unmarked while empty: frameworks insert the element first and set
    // its text afterwards, so a later scan still gets a chance at it.
    if (!text) return;
    styleEl.__cssCompat = true;
    const out = applyTransforms(text);
    if (out !== text) styleEl.textContent = out;
  };

  const scan = (root) => {
    if (!transforms.length || !root || !root.querySelectorAll) return;
    const links = root.querySelectorAll('link[rel~="stylesheet"]');
    for (let i = 0; i < links.length; i++) interceptStylesheet(links[i]);
    const styles = root.querySelectorAll("style");
    for (let j = 0; j < styles.length; j++) transformInlineStyle(styles[j]);
  };

  const observer = new MutationObserver((mutations) => {
    if (!transforms.length) return;
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== 1) continue;
        // Stylesheets are appended straight to <head>, so the added node is the
        // <link>/<style> itself — no need to walk inserted subtrees, which would
        // mean a querySelectorAll for every element the SPA mounts.
        if (node.tagName === "LINK") {
          const rel = (node.getAttribute("rel") || "").toLowerCase();
          if (rel.split(/\s+/).indexOf("stylesheet") !== -1) interceptStylesheet(node);
        } else if (node.tagName === "STYLE") {
          transformInlineStyle(node);
        }
      }
    }
  });

  observer.observe(document.documentElement, { childList: true, subtree: true });

  // Anything already parsed, plus a second pass for inline <style> elements
  // whose text was filled in after insertion. (There is deliberately no "load"
  // listener: on claude.ai that event never fires.)
  scan(document);
  document.addEventListener("DOMContentLoaded", () => scan(document));
})();
