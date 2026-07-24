(function () {
  const BASE_URL =
    "https://assets-proxy.anthropic.com/claude-ai/v2/assets/v1";
//  const BASE_URL = window.location.href

  const status = (payload) => {
    try {
      window.webkit.messageHandlers.loadingStatus.postMessage(payload);
    } catch (e) {}
  };

  const shortName = (src) => {
    const path = String(src || "").split("?")[0];
    const parts = path.split("/");
    return parts[parts.length - 1] || path;
  };

  const reportError = (message, fatal) => {
    status({ stage: "error", message: String(message), fatal: !!fatal });
  };

  status({ stage: "boot" });

  // Anything thrown while the page is still loading is worth showing: at that
  // point a failure means a blank screen, not a glitch in an already-running app.
  window.addEventListener("error", (event) => {
    if (event && event.message) {
      const where = event.filename
        ? " (" + shortName(event.filename) + ":" + event.lineno + ")"
        : "";
      reportError(event.message + where, false);
    }
  });

  window.addEventListener("unhandledrejection", (event) => {
    const reason = event && event.reason;
    if (reason) {
      reportError((reason && reason.message) || reason, false);
    }
  });

  if (!window.LegacyTranspiler || typeof window.LegacyTranspiler.init !== "function") {
    reportError(
      "legacy-transpiler.js did not load — check the Web Inspector console for a SyntaxError.",
      true
    );
    return;
  }

  // Report every module download so the loading screen can name the file it waits on.
  const originalFetch = window.fetch;
  if (typeof originalFetch === "function") {
    window.fetch = function (input) {
      const url = typeof input === "string" ? input : (input && input.url) || "";
      if (url.indexOf(BASE_URL) === 0) {
        status({ stage: "download", file: shortName(url) });
      }
      return originalFetch.apply(this, arguments);
    };
  }

  // The page is considered loaded once module activity settles and something is painted.
  let readySent = false;
  let readyTimer = null;
  let readyAttempts = 0;

  const checkReady = () => {
    if (readySent) return;
    const painted =
      document.body && document.body.innerText.trim().length > 0;
    if (document.readyState === "complete" && painted) {
      readySent = true;
      status({ stage: "ready" });
      return;
    }
    // Claude paints well after the last module runs — around 15s in on a fast
    // device, considerably later on an old one. Poll briskly at first, then back
    // off, so the same number of (layout-forcing) innerText reads covers ~85s
    // instead of 30s and the native side is not left guessing.
    if (++readyAttempts > 100) return;
    readyTimer = setTimeout(checkReady, readyAttempts < 20 ? 300 : 1000);
  };

  const scheduleReadyCheck = () => {
    if (readySent) return;
    readyAttempts = 0;
    clearTimeout(readyTimer);
    readyTimer = setTimeout(checkReady, 800);
  };

  try {
    window.LegacyTranspiler.init({
      BASE_URL,
      runScript: (code, src) => {
        window.webkit.messageHandlers.patchScript.postMessage({
          code: code,
          file: shortName(src),
        });
        scheduleReadyCheck();
      },
      target: {
        platform: 'iOS',
        version: iosVersion
      }
    });
  } catch (e) {
    reportError("LegacyTranspiler.init failed: " + (e && e.message ? e.message : e), true);
    return;
  }

  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.tagName === "SCRIPT" && node.src && node.src.includes('index')) {
          node.type = "javascript/blocked";
          const src = node.src;
          try {
            window.LegacyTranspiler.loadCode(src)
          } catch (e) {
            // The entry chunk is blocked at this point, so failing here means
            // nothing will ever render.
            reportError(
              "Failed to transpile " + shortName(src) + ": " + (e && e.message ? e.message : e),
              true
            );
          }
        }
      }
    }
  });

  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
})();
