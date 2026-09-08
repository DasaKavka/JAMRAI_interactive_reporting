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
// Shared primitives (num, colorFor, tooltip, colour picker, region legend)
// live in www/chart_common.js -> window.JAMRAI. This file keeps only the
// AMR-specific rendering (facets, bars/CI/trend, radar, GLM-trend legend).
//
// r2d3 injects into scope: svg, data, width, height, options, theme.
// `data` is an array of row objects with columns:
//   Year, Region, Host, Percent_resistant, Percent_resistant_predict,
//   CI_lower, CI_upper, Sample_size
// Stats (GLM predictions, CIs) are computed in R — D3 only renders.
// Written for D3 v5 (d3.mouse / function(d) handlers).
// =====================================================================

var J = window.JAMRAI;

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
var FONT = J.FONT;

// regions hidden by clicking their legend swatch/label (R supplies the list;
// toggling sends a Shiny input so it survives the next re-render)
var hiddenRegions = {};
((options && options.hiddenRegions) || []).forEach(function (r) { hiddenRegions[r] = true; });
function isHidden(region) { return !!hiddenRegions[region]; }

// GLM trend/forecast — one global on/off, independent of the per-region toggle
var trendHidden = !!(options && options.trendHidden);

// generic colour lookup — no hard-coded region names; falls back to the palette by index
function colorFor(region) { return J.colorFor(region, colors, regions); }

svg.selectAll("*").remove();
svg.style("font-family", FONT);

// ---- coerce + clean -------------------------------------------------
data.forEach(function (d) {
  d.Year = +d.Year;
  d.obs  = J.num(d.Percent_resistant);
  d.pred = J.num(d.Percent_resistant_predict);
  d.lo   = J.num(d.CI_lower);
  d.hi   = J.num(d.CI_upper);
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

// shared tooltip singleton
J.ensureTooltip();

// shared tooltip content used by both the bars and the radar points
function tooltipHtml(host, d) {
  return "<b>" + host + "</b><br>" +
    "<span style='color:" + (colorFor(d.Region)) + ";font-weight:700'>" + d.Region + "</span> · " + d.Year +
    "<br>Resistance: <b>" + d.obs.toFixed(1) + "%</b>" +
    (d.pred !== null ? "<br>Trend (GLM): " + d.pred.toFixed(1) + "%" : "") +
    (d.lo !== null ? "<br>95% CI: " + d.lo.toFixed(1) + "–" + d.hi.toFixed(1) + "%" : "") +
    (d.Sample_size ? "<br>n = " + d.Sample_size : "");
}

// ---- legend (top): shared region legend (hide/recolour) + AMR-specific
//      "GLM trend" entry appended after it. -----------------------------
var legendH = 30;
var lg = svg.append("g").attr("transform", "translate(14,18)");
var lx = J.drawRegionLegend(lg, {
  regions: regions,
  colorForR: colorFor,
  isHidden: isHidden,
  toggleInputId: toggleInputId,
  colorPickInputId: colorPickInputId,
  startX: 0
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
        J.showTip(d3.event, tooltipHtml(host, d));
      })
      .on("mouseleave", function () {
        d3.select(this).attr("opacity", 1);
        J.hideTip();
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
        .on("mousemove", function (d) { J.showTip(d3.event, tooltipHtml(host, d)); })
        .on("mouseleave", J.hideTip);
    });
  });

  svg.append("text").attr("x", width / 2).attr("y", height - 6)
    .attr("text-anchor", "middle").attr("fill", "#0C5468").style("font-size", "11px")
    .text("Radius = % Resistance   (solid = observed, dashed = GLM trend)");
}
