// Redraw htmlwidgets (leaflet map, plotly chart) when a user-resizable box
// (.pm-resizable, see pm.css) changes size. htmlwidgets only listens for window
// resizes, so forward element resizes as one window "resize" per frame.
(function () {
  if (!window.ResizeObserver) return;
  var frame = null;
  var observer = new ResizeObserver(function () {
    if (frame) cancelAnimationFrame(frame);
    frame = requestAnimationFrame(function () {
      window.dispatchEvent(new Event("resize"));
    });
  });
  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll(".pm-resizable").forEach(function (el) {
      observer.observe(el);
    });
  });
})();
