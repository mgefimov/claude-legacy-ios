(function () {
  function patchCode(code) {
    // 1.  Lookbehind assertion: (?<=...), (?<!...)
    code = code.replace(/\(\?<[=!]([^()]*(?:\([^()]*\))*[^()]*)\)/g, "");

    // 2. Class static blocks: static{__name(this,"...")}
    code = code.replace(/static\s*\{\s*__name\(this\s*,\s*"[^"]*"\)\s*\}/g, "");

    return code;
  }
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.tagName === "SCRIPT" && node.src) {
          node.type = "javascript/blocked";
          const parent = node.parentNode;
          const src = node.src;

          fetch(src)
            .then((r) => r.text())
            .then((code) => {
              const patched = patchCode(code);
              const newScript = document.createElement("script");
              newScript.textContent = patched;
              (parent || document.head).appendChild(newScript);
            });
        }
      }
    }
  });

  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
})();
