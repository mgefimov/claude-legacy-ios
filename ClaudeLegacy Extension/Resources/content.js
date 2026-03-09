(function () {
  function patchCode(code) {
    // 1.  Lookbehind assertion: (?<=...), (?<!...)
    code = code.replace(/\(\?<[=!]([^()]*(?:\([^()]*\))*[^()]*)\)/g, "");

    // 2. Class static blocks: static{__name(this,"...")}
    code = code.replace(/static\s*\{\s*__name\(this\s*,\s*"[^"]*"\)\s*\}/g, "");

    return code;
  }

  function getNonce() {
    var nonce = '';
    var s = document.querySelector('script[nonce]');
    if (s) nonce = s.nonce || s.getAttribute('nonce');
    return nonce;
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

              newScript.setAttribute('data-orig', src)

              const nonce = getNonce()
              newScript.setAttribute('nonce', nonce);

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
