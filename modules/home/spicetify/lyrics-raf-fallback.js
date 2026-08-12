(function () {
  if (window.__spicyLyricsRafFallbackInstalled) return;
  window.__spicyLyricsRafFallbackInstalled = true;

  var nativeRAF = window.requestAnimationFrame.bind(window);
  var nativeCAF = window.cancelAnimationFrame.bind(window);
  var FALLBACK_MS = 100;

  var seq = 0;
  var slots = new Map();

  function cancel(handle) {
    var s = slots.get(handle);
    if (!s) return;
    s.active = false;
    if (s.rafId) nativeCAF(s.rafId);
    if (s.timerId) clearTimeout(s.timerId);
    slots.delete(handle);
  }

  function register(cb) {
    var handle = ++seq;
    var s = { cb: cb, active: true, rafId: 0, timerId: 0 };
    slots.set(handle, s);

    function onTimer() {
      if (!s.active) return;
      if (s.rafId) nativeCAF(s.rafId);
      s.rafId = 0;
      s.timerId = 0;
      s.cb(performance.now());
    }

    function onFrame() {
      if (!s.active) return;
      if (s.timerId) clearTimeout(s.timerId);
      s.timerId = 0;
      s.rafId = 0;
      s.cb(performance.now());
    }

    s.timerId = setTimeout(onTimer, FALLBACK_MS);
    s.rafId = nativeRAF(onFrame);
    return handle;
  }

  window.requestAnimationFrame = register;
  window.cancelAnimationFrame = cancel;
})();
