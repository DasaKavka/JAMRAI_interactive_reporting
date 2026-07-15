// =====================================================================
// amr_d3.js — r2d3 prototype for the JAMRAI AMR dashboard
// Faceted small-multiples, one panel per Host (species). Two chart types,
// picked in R via options.chartType ("curve" | "radar") from the
// "Chart type" toggle:
//   - "curve": grouped bars (observed % resistant) + 95% CI ribbon + GLM
//     trend line, one series per region.
//   - "radar": one closed polygon per region (years around the circle,
//     radius = observed % resistant).
//
// r2d3 injects into scope: svg, data, width, height, options, theme.
// `data` is an array of row objects with columns:
//   Year, Region, Host, Percent_resistant, Percent_resistant_predict,
//   CI_lower, CI_upper, Sample_size
// Stats (GLM predictions, CIs) are computed in R — D3 only renders.
// Written for D3 v5 (d3.mouse / function(d) handlers).
// =====================================================================

var colors = (options && options.colors) || {};            // { region: colour } supplied by R
var ymax = (options && options.ymax) ? +options.ymax : 100;
var showN = !!(options && options.showSampleSizes);
var chartType = (options && options.chartType) || "curve"; // "curve" | "radar"
// fully-qualified (namespaced) Shiny input ids — R passes session$ns(...) so
// these keep working when several chart instances (Shiny module copies) are
// on the page at once.
var colorPickInputId = (options && options.colorPickInputId) || "amr_color_pick";
var toggleInputId = (options && options.toggleInputId) || "amr_region_toggle";
var trendToggleInputId = (options && options.trendToggleInputId) || "amr_trend_toggle";
var FONT = "'ITC Avant Garde Gothic','Century Gothic','Segoe UI',sans-serif";
var PALETTE = ["#078BAD", "#0FDBD5", "#1f77b4", "#e4572e", "#2ca02c", "#9467bd", "#8c564b", "#333333"];

// regions hidden by clicking their legend swatch/label (R supplies the list;
// toggling sends a Shiny input so it survives the next re-render)
var hiddenRegions = {};
((options && options.hiddenRegions) || []).forEach(function (r) { hiddenRegions[r] = true; });
function isHidden(region) { return !!hiddenRegions[region]; }

// GLM trend/forecast — one global on/off, independent of the per-region toggle
var trendHidden = !!(options && options.trendHidden);

// generic colour lookup — no hard-coded region names; falls back to the palette by index
function colorFor(region) {
  if (colors && colors[region]) return colors[region];
  var i = regions.indexOf(region);
  return PALETTE[(i >= 0 ? i : 0) % PALETTE.length];
}

// hex helper for the native colour input
function toHex6(c) {
  if (typeof c === "string" && /^#[0-9a-fA-F]{6}$/.test(c)) return c.toLowerCase();
  var col = d3.rgb(c);
  function h(n) { n = Math.max(0, Math.min(255, Math.round(n))); return ("0" + n.toString(16)).slice(-2); }
  return "#" + h(col.r) + h(col.g) + h(col.b);
}

svg.selectAll("*").remove();
svg.style("font-family", FONT);

// ---- coerce + clean -------------------------------------------------
function num(v) { return (v === null || v === undefined || v === "" || isNaN(+v)) ? null : +v; }
data.forEach(function (d) {
  d.Year = +d.Year;
  d.obs  = num(d.Percent_resistant);
  d.pred = num(d.Percent_resistant_predict);
  d.lo   = num(d.CI_lower);
  d.hi   = num(d.CI_upper);
});

var hosts   = Array.from(new Set(data.map(function (d) { return d.Host; })));
var regions = Array.from(new Set(data.map(function (d) { return d.Region; }))).sort();
var years   = Array.from(new Set(data.map(function (d) { return d.Year; }))).sort(function (a, b) { return a - b; });

if (!data.length || !hosts.length || !years.length) {
  svg.append("text").attr("x", width / 2).attr("y", height / 2)
     .attr("text-anchor", "middle").attr("fill", "#7aa7b5")
     .style("font-size", "14px").text("No data for this selection");
  return;
}

// ---- tooltip (appended to <body>, position:fixed — robust, no reliance
//      on the widget container being attached when the script first runs) ----
var tip = d3.select("body").selectAll("div.d3tip-amr").data([0]);
tip = tip.enter().append("div").attr("class", "d3tip-amr")
  .style("position", "fixed").style("pointer-events", "none")
  .style("background", "rgba(255,255,255,.97)").style("border", "1px solid #D6E4EA")
  .style("border-radius", "8px").style("box-shadow", "0 4px 16px rgba(7,139,173,.20)")
  .style("padding", "8px 11px").style("font", "12px " + FONT).style("color", "#0C5468")
  .style("line-height", "1.45").style("z-index", 9999).style("opacity", 0)
  .merge(tip);

// shared tooltip content + show/hide, used by both the bars and the radar points
function tooltipHtml(host, d) {
  return "<b>" + host + "</b><br>" +
    "<span style='color:" + (colorFor(d.Region)) + ";font-weight:700'>" + d.Region + "</span> · " + d.Year +
    "<br>Resistance: <b>" + d.obs.toFixed(1) + "%</b>" +
    (d.pred !== null ? "<br>Trend (GLM): " + d.pred.toFixed(1) + "%" : "") +
    (d.lo !== null ? "<br>95% CI: " + d.lo.toFixed(1) + "–" + d.hi.toFixed(1) + "%" : "") +
    (d.Sample_size ? "<br>n = " + d.Sample_size : "");
}
function showTip(ev, html) {
  if (!ev) return;
  var t = d3.select("body").select("div.d3tip-amr");
  if (t.empty()) return;
  var tw = 200, tx = ev.clientX + 16, ty = ev.clientY + 12;
  if (tx + tw > window.innerWidth) tx = ev.clientX - tw - 12;
  t.style("opacity", 1).style("left", tx + "px").style("top", ty + "px").html(html);
}
function hideTip() {
  d3.select("body").select("div.d3tip-amr").style("opacity", 0);
}

// ---- hidden native colour input, opened by clicking a legend item ----------
var picker = d3.select("body").selectAll("input.d3-legend-color").data([0]);
picker = picker.enter().append("input")
  .attr("class", "d3-legend-color").attr("type", "color")
  .style("position", "fixed").style("width", "1px").style("height", "1px")
  .style("opacity", 0).style("border", "0").style("padding", "0").style("z-index", 9999)
  .merge(picker);
var pickerNode = picker.node();

// ---- legend (top): click the swatch/label to hide or show that region's
//      curve(s); click the ✎ pencil to recolour. Hidden regions stay in the
//      legend (dimmed) so they can be clicked again to bring them back. -----
var legendH = 30;
var lg = svg.append("g").attr("transform", "translate(14,18)");
var lx = 0;
regions.forEach(function (r) {
  var hidden = isHidden(r);
  var g = lg.append("g").attr("transform", "translate(" + lx + ",0)")
    .style("opacity", hidden ? 0.35 : 1);

  var toggleGroup = g.append("g").style("cursor", "pointer");
  toggleGroup.append("title").text((hidden ? "Click to show " : "Click to hide ") + r);
  toggleGroup.append("rect").attr("width", 14).attr("height", 14).attr("rx", 3).attr("y", -11)
    .attr("fill", colorFor(r)).attr("stroke", "#9bbecb").attr("stroke-width", 1);
  toggleGroup.append("text").attr("x", 20).attr("y", 1).attr("fill", "#0C5468")
    .style("font-size", "12.5px").text(r);
  toggleGroup.on("click", function () {
    if (window.Shiny) Shiny.setInputValue(toggleInputId, r, { priority: "event" });
  });

  var pencilGroup = g.append("g").style("cursor", "pointer");
  pencilGroup.append("title").text("Click to change the colour of " + r);
  pencilGroup.append("text").attr("x", 24 + r.length * 7.4).attr("y", 1)
    .attr("fill", "#9bbecb").style("font-size", "11px").text("✎");
  pencilGroup.on("click", function () {
    var ev = d3.event;
    pickerNode.value = toHex6(colorFor(r));
    if (ev) { pickerNode.style.left = ev.clientX + "px"; pickerNode.style.top = ev.clientY + "px"; }
    pickerNode.onchange = function () {
      if (window.Shiny) Shiny.setInputValue(colorPickInputId, { region: r, color: pickerNode.value }, { priority: "event" });
    };
    pickerNode.click();
  });

  lx += 44 + r.length * 8 + 22;
});

// GLM trend/forecast: one legend entry, independent of the per-region toggle —
// clicking it hides/shows the dashed trend line (+ CI ribbon in curve mode)
// for every region at once.
(function () {
  var label = "GLM trend";
  var g = lg.append("g").attr("transform", "translate(" + lx + ",0)")
    .style("cursor", "pointer").style("opacity", trendHidden ? 0.35 : 1);
  g.append("title").text((trendHidden ? "Click to show " : "Click to hide ") + label);
  g.append("line").attr("x1", 0).attr("x2", 18).attr("y1", -4).attr("y2", -4)
    .attr("stroke", "#7A8A90").attr("stroke-width", 2.2).attr("stroke-dasharray", "5,3");
  g.append("text").attr("x", 24).attr("y", 1).attr("fill", "#0C5468")
    .style("font-size", "12.5px").text(label);
  g.on("click", function () {
    if (window.Shiny) Shiny.setInputValue(trendToggleInputId, true, { priority: "event" });
  });
  lx += 44 + label.length * 8;
})();

// ---- facet grid (layout math shared by both chart types) ------------
var nCols = Math.min(hosts.length, 2);   // grid of 2 columns max
var nRows = Math.ceil(hosts.length / nCols);
var cellW = width / nCols;
var cellH = (height - legendH) / nRows;

if (chartType === "radar") {
  renderRadarFacets();
} else {
  renderCurveFacets();
}

// =====================================================================
// "curve" chart: grouped bars + CI ribbon + GLM trend line
// =====================================================================
function renderCurveFacets() {
  var pad = { t: 26, r: 18, b: 42, l: 46 };

  hosts.forEach(function (host, i) {
    var cx = (i % nCols) * cellW;
    var cy = legendH + Math.floor(i / nCols) * cellH;
    var g  = svg.append("g").attr("transform", "translate(" + cx + "," + cy + ")");

    var iw = cellW - pad.l - pad.r;
    var ih = cellH - pad.t - pad.b;
    var fdata = data.filter(function (d) { return d.Host === host; });

    var x  = d3.scaleBand().domain(years).range([pad.l, pad.l + iw]).padding(0.22);
    var xR = d3.scaleBand().domain(regions).range([0, x.bandwidth()]).padding(0.06);
    var y  = d3.scaleLinear().domain([0, ymax]).range([pad.t + ih, pad.t]);
    var cxBand = function (d) { return x(d.Year) + x.bandwidth() / 2; };

    // y grid + axis
    g.append("g").attr("transform", "translate(" + pad.l + ",0)")
      .call(d3.axisLeft(y).ticks(4).tickSize(-iw))
      .call(function (s) { s.select(".domain").remove(); })
      .call(function (s) { s.selectAll("line").attr("stroke", "#E7EFF3"); })
      .call(function (s) { s.selectAll("text").attr("fill", "#0C5468").style("font-size", "10px"); });

    // x axis (rotated years, thinned if many)
    var step = years.length > 14 ? 2 : 1;
    g.append("g").attr("transform", "translate(0," + (pad.t + ih) + ")")
      .call(d3.axisBottom(x).tickValues(years.filter(function (yy, idx) { return idx % step === 0; })))
      .call(function (s) { s.select(".domain").attr("stroke", "#D6E4EA"); })
      .call(function (s) { s.selectAll("line").attr("stroke", "#D6E4EA"); })
      .call(function (s) {
        s.selectAll("text").attr("fill", "#0C5468").style("font-size", "9px")
          .attr("transform", "rotate(-90)").attr("text-anchor", "end")
          .attr("dx", "-0.5em").attr("dy", "-0.5em");
      });

    // facet title
    g.append("text").attr("x", pad.l + iw / 2).attr("y", pad.t - 9)
      .attr("text-anchor", "middle").attr("fill", "#056B86")
      .style("font-size", "12px").style("font-weight", "700").text(host);

    // CI ribbon + trend line per region (skip regions hidden via the legend,
    // and skip all of it if the "GLM trend" legend entry is toggled off)
    regions.forEach(function (r) {
      if (isHidden(r) || trendHidden) return;
      var rd = fdata.filter(function (d) { return d.Region === r && d.pred !== null; })
                    .sort(function (a, b) { return a.Year - b.Year; });
      if (!rd.length) return;
      var area = d3.area().defined(function (d) { return d.lo !== null && d.hi !== null; })
        .x(cxBand).y0(function (d) { return y(d.lo); }).y1(function (d) { return y(d.hi); });
      g.append("path").datum(rd).attr("d", area).attr("fill", colorFor(r)).attr("opacity", 0.16);
      var line = d3.line().defined(function (d) { return d.pred !== null; })
        .x(cxBand).y(function (d) { return y(d.pred); });
      g.append("path").datum(rd).attr("d", line).attr("fill", "none")
        .attr("stroke", colorFor(r)).attr("stroke-width", 2.2);
    });

    // observed bars (grouped by region, hidden regions excluded)
    g.selectAll("rect.bar").data(fdata.filter(function (d) { return d.obs !== null && !isHidden(d.Region); }))
      .enter().append("rect").attr("class", "bar")
      .attr("x", function (d) { return x(d.Year) + xR(d.Region); })
      .attr("width", xR.bandwidth())
      .attr("y", function (d) { return y(d.obs); })
      .attr("height", function (d) { return (pad.t + ih) - y(d.obs); })
      .attr("fill", function (d) { return colorFor(d.Region); })
      .attr("rx", 1.5)
      .style("cursor", "pointer")
      .on("mousemove", function (d) {
        d3.select(this).attr("opacity", 0.82);
        showTip(d3.event, tooltipHtml(host, d));
      })
      .on("mouseleave", function () {
        d3.select(this).attr("opacity", 1);
        hideTip();
      });

    // sample-size labels on the Belgian bars (toggle "Show Belgian sample sizes")
    if (showN) {
      g.selectAll("text.ssize")
        .data(fdata.filter(function (d) {
          return d.obs !== null && !isHidden(d.Region) &&
                 d.Sample_size !== null && d.Sample_size !== undefined && d.Sample_size !== "";
        }))
        .enter().append("text").attr("class", "ssize")
        .attr("text-anchor", "start").attr("dy", "0.32em")
        .attr("fill", "#0C5468").style("font-size", "8.5px")
        .attr("transform", function (d) {
          var px = x(d.Year) + xR(d.Region) + xR.bandwidth() / 2;
          var py = y(d.obs) - 5;
          return "translate(" + px + "," + py + ") rotate(-90)";
        })
        .text(function (d) { return d.Sample_size; });
    }
  });

  // shared y-axis caption
  svg.append("text").attr("transform", "rotate(-90)")
    .attr("x", -(legendH + (height - legendH) / 2)).attr("y", 14)
    .attr("text-anchor", "middle").attr("fill", "#0C5468").style("font-size", "11px")
    .text("% Resistance");
}

// =====================================================================
// "radar" chart: one closed polygon per region, years spread around the
// circle, radius = observed % resistant. Same legend/tooltip as "curve".
// =====================================================================
function renderRadarFacets() {
  var padTop = 34, padBottom = 14, padSide = 44;

  hosts.forEach(function (host, i) {
    var cx = (i % nCols) * cellW;
    var cy = legendH + Math.floor(i / nCols) * cellH;
    var g  = svg.append("g").attr("transform", "translate(" + cx + "," + cy + ")");

    // facet title
    g.append("text").attr("x", cellW / 2).attr("y", 16)
      .attr("text-anchor", "middle").attr("fill", "#056B86")
      .style("font-size", "12px").style("font-weight", "700").text(host);

    var fdata = data.filter(function (d) { return d.Host === host; });

    if (years.length < 3) {
      g.append("text").attr("x", cellW / 2).attr("y", padTop + (cellH - padTop - padBottom) / 2)
        .attr("text-anchor", "middle").attr("fill", "#7aa7b5").style("font-size", "12px")
        .text("Select at least 3 years for a radar chart");
      return;
    }

    var innerW = cellW - 2 * padSide;
    var innerH = cellH - padTop - padBottom;
    var radius = Math.max(10, Math.min(innerW, innerH) / 2 - 26);
    var centerX = cellW / 2;
    var centerY = padTop + innerH / 2;

    // years run clockwise from the top (12 o'clock), evenly spaced
    function angle(year) { return -Math.PI / 2 + years.indexOf(year) * (2 * Math.PI / years.length); }
    var rScale = d3.scaleLinear().domain([0, ymax]).range([0, radius]);
    var px = function (year, val) { return centerX + rScale(val) * Math.cos(angle(year)); };
    var py = function (year, val) { return centerY + rScale(val) * Math.sin(angle(year)); };

    // ---- radial grid: concentric polygons + spokes + year labels -------
    var ringVals = rScale.ticks(4).filter(function (v) { return v > 0; });
    ringVals.forEach(function (v) {
      var pts = years.map(function (yy) { return px(yy, v) + "," + py(yy, v); }).join(" ");
      g.append("polygon").attr("points", pts)
        .attr("fill", "none").attr("stroke", "#E7EFF3").attr("stroke-width", 1);
      g.append("text").attr("x", centerX + 3).attr("y", py(years[0], v) - 2)
        .attr("fill", "#9bbecb").style("font-size", "9px").text(v);
    });
    years.forEach(function (yy) {
      g.append("line")
        .attr("x1", centerX).attr("y1", centerY)
        .attr("x2", px(yy, ymax)).attr("y2", py(yy, ymax))
        .attr("stroke", "#E7EFF3").attr("stroke-width", 1);
      var lx2 = px(yy, ymax) + Math.cos(angle(yy)) * 14;
      var ly2 = py(yy, ymax) + Math.sin(angle(yy)) * 14;
      var c = Math.cos(angle(yy));
      var anchor = c > 0.3 ? "start" : (c < -0.3 ? "end" : "middle");
      g.append("text").attr("x", lx2).attr("y", ly2)
        .attr("text-anchor", anchor).attr("dy", "0.32em")
        .attr("fill", "#0C5468").style("font-size", "10px").text(yy);
    });

    // ---- one polygon per region (observed) + one dashed polygon (GLM trend) --
    var radarLine = d3.line()
      .x(function (d) { return px(d.Year, d.obs); })
      .y(function (d) { return py(d.Year, d.obs); })
      .curve(d3.curveLinearClosed);
    var trendLine = d3.line()
      .x(function (d) { return px(d.Year, d.pred); })
      .y(function (d) { return py(d.Year, d.pred); })
      .curve(d3.curveLinearClosed);

    regions.forEach(function (r) {
      if (isHidden(r)) return;
      var rd = fdata.filter(function (d) { return d.Region === r && d.obs !== null; })
                    .sort(function (a, b) { return years.indexOf(a.Year) - years.indexOf(b.Year); });
      if (rd.length < 3) return;

      g.append("path").datum(rd).attr("d", radarLine)
        .attr("fill", colorFor(r)).attr("fill-opacity", 0.18)
        .attr("stroke", colorFor(r)).attr("stroke-width", 2.2);

      // GLM forecast/trend line — same region colour, dashed, no fill, drawn
      // on top of the observed area so the trend stays legible where they
      // overlap. Gated by the "GLM trend" legend entry, independent of the
      // per-region toggle above (which only hides the observed polygon+dots).
      var trendPts = trendHidden ? [] : fdata.filter(function (d) { return d.Region === r && d.pred !== null; })
                          .sort(function (a, b) { return years.indexOf(a.Year) - years.indexOf(b.Year); });
      if (trendPts.length >= 3) {
        g.append("path").datum(trendPts).attr("d", trendLine)
          .attr("fill", "none")
          .attr("stroke", colorFor(r)).attr("stroke-width", 1.8)
          .attr("stroke-dasharray", "5,3");
      }

      g.selectAll(null).data(rd).enter().append("circle")
        .attr("cx", function (d) { return px(d.Year, d.obs); })
        .attr("cy", function (d) { return py(d.Year, d.obs); })
        .attr("r", 3.5)
        .attr("fill", colorFor(r)).attr("stroke", "#fff").attr("stroke-width", 1)
        .style("cursor", "pointer")
        .on("mousemove", function (d) { showTip(d3.event, tooltipHtml(host, d)); })
        .on("mouseleave", hideTip);
    });
  });

  svg.append("text").attr("x", width / 2).attr("y", height - 6)
    .attr("text-anchor", "middle").attr("fill", "#0C5468").style("font-size", "11px")
    .text("Radius = % Resistance   (solid = observed, dashed = GLM trend)");
}
