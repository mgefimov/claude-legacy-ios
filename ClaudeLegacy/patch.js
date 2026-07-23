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

  status({ stage: "boot" });

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
    if (++readyAttempts > 100) return;
    readyTimer = setTimeout(checkReady, 300);
  };

  const scheduleReadyCheck = () => {
    if (readySent) return;
    readyAttempts = 0;
    clearTimeout(readyTimer);
    readyTimer = setTimeout(checkReady, 800);
  };

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

  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.tagName === "SCRIPT" && node.src && node.src.includes('index')) {
          node.type = "javascript/blocked";
          const src = node.src;
          window.LegacyTranspiler.loadCode(src)
        }
      }
    }
  });

  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
})();
