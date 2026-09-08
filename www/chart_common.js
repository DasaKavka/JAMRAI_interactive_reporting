// =====================================================================
// chart_common.js — D3 primitives shared between amr_d3.js, amc_d3.js and
// compare_d3.js. Loaded once globally in the page (see src/ui.R,
// tags$script), so window.JAMRAI is available to every r2d3 widget (which
// run client-side after the page has loaded).
//
// Previously each D3 script copied: num(), toHex6(), colorFor(), the
// floating tooltip, the hidden <color> input, and the clickable region
// legend. All this identical base now lives here.
// =====================================================================
(function () {
  var FONT = "'ITC Avant Garde Gothic','Century Gothic','Segoe UI',sans-serif";
  var PALETTE = ["#078BAD", "#0FDBD5", "#1f77b4", "#e4572e", "#2ca02c", "#9467bd", "#8c564b", "#333333"];

  // --- numeric coercion: "" / NA / non-number -> null -----------------
  function num(v) {
    return (v === null || v === undefined || v === "" || isNaN(+v)) ? null : +v;
  }

  // --- 6-digit hex for the native <color> input -----------------------
  function toHex6(c) {
    if (typeof c === "string" && /^#[0-9a-fA-F]{6}$/.test(c)) return c.toLowerCase();
    var col = d3.rgb(c);
    function h(n) { n = Math.max(0, Math.min(255, Math.round(n))); return ("0" + n.toString(16)).slice(-2); }
    return "#" + h(col.r) + h(col.g) + h(col.b);
  }

  // --- colour of a region: R override, otherwise palette by index -----
  // `colors` = { region: hex } supplied by R; `regions` = display order.
  function colorFor(region, colors, regions) {
    if (colors && colors[region]) return colors[region];
    var i = regions.indexOf(region);
    return PALETTE[(i >= 0 ? i : 0) % PALETTE.length];
  }

  // --- shared floating tooltip (a single <div>, position:fixed) -------
  // Attached to <body> so it does not depend on the widget's container.
  function ensureTooltip() {
    var tip = d3.select("body").selectAll("div.d3tip").data([0]);
    tip = tip.enter().append("div").attr("class", "d3tip")
      .style("position", "fixed").style("pointer-events", "none")
      .style("background", "rgba(255,255,255,.97)").style("border", "1px solid #D6E4EA")
      .style("border-radius", "8px").style("box-shadow", "0 4px 16px rgba(7,139,173,.20)")
      .style("padding", "8px 11px").style("font", "12px " + FONT).style("color", "#0C5468")
      .style("line-height", "1.45").style("z-index", 9999).style("opacity", 0)
      .merge(tip);
    return tip;
  }
  function showTip(ev, html) {
    if (!ev) return;
    var t = d3.select("body").select("div.d3tip");
    if (t.empty()) t = ensureTooltip();
    var tw = 200, tx = ev.clientX + 16, ty = ev.clientY + 12;
    if (tx + tw > window.innerWidth) tx = ev.clientX - tw - 12;
    t.style("opacity", 1).style("left", tx + "px").style("top", ty + "px").html(html);
  }
  function hideTip() {
    d3.select("body").select("div.d3tip").style("opacity", 0);
  }

  // --- hidden native <color> input, opened by clicking the pencil -----
  function pickerNode() {
    var picker = d3.select("body").selectAll("input.d3-legend-color").data([0]);
    picker = picker.enter().append("input")
      .attr("class", "d3-legend-color").attr("type", "color")
      .style("position", "fixed").style("width", "1px").style("height", "1px")
      .style("opacity", 0).style("border", "0").style("padding", "0").style("z-index", 9999)
      .merge(picker);
    return picker.node();
  }

  // --- clickable region legend ----------------------------------------
  // Renders, inside the <g> `lg`, one entry per region: clicking the swatch/
  // label = hide/show (sends toggleInputId to Shiny), clicking ✎ = recolour
  // (sends colorPickInputId). Returns the total width (end x) so the caller
  // can append further entries after it (e.g. "GLM trend").
  //   opts : { regions, colorForR(region), isHidden(region),
  //            toggleInputId, colorPickInputId, startX }
  function drawRegionLegend(lg, opts) {
    var regions = opts.regions;
    var colorForR = opts.colorForR;
    var isHidden = opts.isHidden || function () { return false; };
    var node = pickerNode();
    var lx = opts.startX || 0;

    regions.forEach(function (r) {
      var hidden = isHidden(r);
      var g = lg.append("g").attr("transform", "translate(" + lx + ",0)")
        .style("opacity", hidden ? 0.35 : 1);

      var toggleGroup = g.append("g").style("cursor", "pointer");
      toggleGroup.append("title").text((hidden ? "Click to show " : "Click to hide ") + r);
      toggleGroup.append("rect").attr("width", 14).attr("height", 14).attr("rx", 3).attr("y", -11)
        .attr("fill", colorForR(r)).attr("stroke", "#9bbecb").attr("stroke-width", 1);
      toggleGroup.append("text").attr("x", 20).attr("y", 1).attr("fill", "#0C5468")
        .style("font-size", "12.5px").text(r);
      toggleGroup.on("click", function () {
        if (window.Shiny && opts.toggleInputId) Shiny.setInputValue(opts.toggleInputId, r, { priority: "event" });
      });

      if (opts.colorPickInputId) {
        var pencilGroup = g.append("g").style("cursor", "pointer");
        pencilGroup.append("title").text("Click to change the colour of " + r);
        pencilGroup.append("text").attr("x", 24 + r.length * 7.4).attr("y", 1)
          .attr("fill", "#9bbecb").style("font-size", "11px").text("✎");
        pencilGroup.on("click", function () {
          var ev = d3.event;
          node.value = toHex6(colorForR(r));
          if (ev) { node.style.left = ev.clientX + "px"; node.style.top = ev.clientY + "px"; }
          node.onchange = function () {
            if (window.Shiny) Shiny.setInputValue(opts.colorPickInputId, { region: r, color: node.value }, { priority: "event" });
          };
          node.click();
        });
      }

      lx += 44 + r.length * 8 + (opts.colorPickInputId ? 22 : 0);
    });

    return lx;
  }

  window.JAMRAI = {
    FONT: FONT,
    PALETTE: PALETTE,
    num: num,
    toHex6: toHex6,
    colorFor: colorFor,
    ensureTooltip: ensureTooltip,
    showTip: showTip,
    hideTip: hideTip,
    drawRegionLegend: drawRegionLegend
  };
})();
