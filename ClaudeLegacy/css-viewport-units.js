// Downgrade the dynamic/small/large viewport units for WebKit older than 15.4.
// Injected only on affected systems — see -[ViewController injectCSSCompatibilityFixes].
//
// `dvh`/`svh`/`lvh` (and the dvw/dvi/dvb/dvmin/dvmax family) shipped in Safari
// 15.4. Claude sizes its scrollable drawers with them — `height:100dvh`,
// `max-height:calc(100dvh - 2rem)` and so on. On older WebKit the declaration is
// invalid and gets dropped, so the container ends up with no bounded height: it
// cannot scroll, and a touch scrolls the page behind it instead. Mapping them to
// the classic `vh`/`vw` units restores a bounded height.
//
// Only declaration VALUES are rewritten. Tailwind also emits the value inside
// escaped selectors — `.h-\[calc\(100dvh-2rem\)\]`, `.max-h-dvh` — and those class
// names must stay byte-identical to the ones in the HTML, or the rule stops
// matching. Anything inside an escaped `\[ ... \]` segment is therefore left as
// is, and a unit is only rewritten when it directly follows a number that is not
// part of an identifier.
(function () {
  if (!window.CSSCompat) return;

  const UNIT = /^[0-9]*\.?[0-9]+(dv|sv|lv)(h|w|i|b|min|max)\b/;

  window.CSSCompat.register("viewport-units", function (css) {
    if (css.indexOf("dv") === -1 && css.indexOf("sv") === -1 && css.indexOf("lv") === -1) {
      return css;
    }

    const out = [];
    const n = css.length;
    let i = 0;
    let seg = 0;
    let inBracket = false; // inside an escaped \[ ... \] selector segment
    const flush = (upTo) => { if (upTo > seg) out.push(css.slice(seg, upTo)); };

    while (i < n) {
      const c = css.charCodeAt(i);

      if (c === 92) { // backslash escape — also tracks \[ ... \] selectors
        const nx = css[i + 1];
        if (nx === "[") inBracket = true;
        else if (nx === "]") inBracket = false;
        i += 2;
        continue;
      }
      if (c === 47 && css.charCodeAt(i + 1) === 42) { // comment
        const e = css.indexOf("*/", i + 2);
        i = e < 0 ? n : e + 2;
        continue;
      }
      if (c === 34 || c === 39) { // string
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
      // a digit (or leading dot) may start a viewport-unit token
      if (!inBracket && ((c >= 48 && c <= 57) || c === 46)) {
        const prev = i > 0 ? css[i - 1] : " ";
        if (!/[A-Za-z0-9_]/.test(prev)) { // not inside an identifier
          const m = UNIT.exec(css.substr(i, 40));
          if (m) {
            flush(i);
            // strip the d/s/l prefix: 100dvh -> 100vh, 40svmin -> 40vmin
            out.push(m[0].slice(0, m[0].length - (m[1].length + m[2].length)) + "v" + m[2]);
            i += m[0].length;
            seg = i;
            continue;
          }
        }
      }
      i++;
    }
    flush(n);
    return out.join("");
  });
})();
