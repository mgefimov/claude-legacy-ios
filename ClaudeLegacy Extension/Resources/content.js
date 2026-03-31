(function () {
  const BASE_URL =
    "https://assets-proxy.anthropic.com/claude-ai/v2/assets/v1";
  // const BASE_URL = "http://192.168.1.136:3000";

  window.LegacyTranspiler.init({
    BASE_URL,
    runScript: (code) => {
      window.webkit.messageHandlers.patchScript.postMessage(code);
    },
  });

  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.tagName === "SCRIPT" && node.src) {
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
