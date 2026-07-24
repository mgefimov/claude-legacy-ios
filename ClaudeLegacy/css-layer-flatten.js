// Flatten CSS cascade layers for WebKit older than Safari 15.4.
// Injected only on affected systems — see -[ViewController injectCSSCompatibilityFixes].
//
// `@layer` shipped in Safari 15.4. Older WebKit sees an unknown at-rule and drops
// the entire block — and Claude's Tailwind v4 CSS keeps ~92% of its rules inside
// `@layer` (the `utilities` layer alone is ~1.4 MB of 1.6 MB), so almost all
// styling disappears and the layout falls apart.
//
// There is no way to polyfill layer semantics, so we unwrap the blocks and keep
// the rules in source order. That loses the guarantee that a later layer beats an
// earlier one regardless of specificity, but the layers are emitted in cascade
// order (theme → base → components → utilities), which makes source order a
// faithful approximation — and it is what Tailwind's own pre-@layer output did.
(function () {
  if (!window.CSSCompat) return;

  // Unwraps `@layer name { ... }` blocks and drops bare `@layer a, b;` statements.
  // The scan tracks braces, strings, comments and escapes so it is not fooled by
  // braces inside `content:"..."`, by `@media`/`@supports` nested in a layer, or
  // by Tailwind's escaped selectors such as `.\[font-feature-settings\:\'liga\'\]`
  // (where `\'` is a literal apostrophe, not the start of a string).
  window.CSSCompat.register("layer-flatten", function (css) {
    if (css.indexOf("@layer") === -1) return css;

    const out = [];
    const n = css.length;
    let i = 0;
    let seg = 0; // start of the pending verbatim segment
    const stack = []; // per open brace: true if it is a suppressed @layer wrapper
    const flush = (upTo) => { if (upTo > seg) out.push(css.slice(seg, upTo)); };

    while (i < n) {
      const c = css.charCodeAt(i);

      // backslash escape: the next char is a literal, never a delimiter
      if (c === 92) { i += 2; continue; }
      // comment /* ... */
      if (c === 47 && css.charCodeAt(i + 1) === 42) {
        const e = css.indexOf("*/", i + 2);
        i = e < 0 ? n : e + 2;
        continue;
      }
      // string "..." or '...'
      if (c === 34 || c === 39) {
        let j = i + 1;
        while (j < n) {
          const cj = css.charCodeAt(j);
          if (cj === 92) { j += 2; continue; }
          if (cj === c) { j++; break; }
          j++;
        }
        i = j;
        continue;
      }
      // @layer
      if (c === 64 && css.substr(i, 6).toLowerCase() === "@layer") {
        const after = css.charCodeAt(i + 6);
        const boundary = isNaN(after) || after === 32 || after === 9 ||
          after === 10 || after === 13 || after === 123 || after === 59;
        if (boundary) {
          flush(i);
          let k = i + 6;
          while (k < n && css[k] !== "{" && css[k] !== ";") k++;
          if (k >= n) { seg = n; break; }
          if (css[k] === ";") { i = k + 1; seg = i; continue; } // bare statement
          stack.push(true); // block wrapper: drop its "{" and matching "}"
          i = k + 1;
          seg = i;
          continue;
        }
      }
      if (c === 123) { stack.push(false); i++; continue; } // {
      if (c === 125) { // }
        const suppressed = stack.length ? stack.pop() : false;
        if (suppressed) { flush(i); i++; seg = i; continue; }
        i++;
        continue;
      }
      i++;
    }
    flush(n);
    return out.join("");
  });
})();
