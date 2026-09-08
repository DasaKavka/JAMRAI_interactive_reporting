// =====================================================================
// compare_d3.js — combined AMR × AMC view (AMR/AMC tab). Two modes, chosen
// in R via options.mode:
//   - "bar"     : dual-axis grouped bars. AMR (solid, LEFT axis, %) + AMC
//                 (hatched, RIGHT axis, mg/kg), grouped by year, one pair per
//                 region. options.normalize rescales both series to % of their
//                 own max on a single axis so their shapes are comparable.
//   - "scatter" : Monnet plot — x = AMC (mg/kg), y = AMR (%), one point per
//                 (year, region, sector). Axes auto-fit the data (do NOT start
//                 at 0). Human = circle, Animal = triangle. Four action zones
//                 split by the two medians.
//
// Shared primitives via window.JAMRAI (www/chart_common.js).
// data (bar)     : [{ Year, Region, metric:"AMR"|"AMC", val }]
// data (scatter) : [{ Year, Region, Sector:"Human"|"Animal", x, y }]
// =====================================================================

var J = window.JAMRAI;
var mode = (options && options.mode) || "bar";
var colors = (options && options.colors) || {};
var FONT = J.FONT;

svg.selectAll("*").remove();
svg.style("font-family", FONT);

if (mode === "scatter") { renderScatter(); }
else { renderBars(); }

// =====================================================================
// Dual-axis grouped bars (+ optional normalisation)
// =====================================================================
function renderBars() {
  var normalize = !!(options && options.normalize);
  var amrMax = (options && options.amrMax) ? +options.amrMax : 100;
  var amcMax = (options && options.amcMax) ? +options.amcMax : 175;
  var colorPickInputId = (options && options.colorPickInputId) || "cmp_color_pick";
  var toggleInputId = (options && options.toggleInputId) || "cmp_region_toggle";

  var hiddenRegions = {};
  ((options && options.hiddenRegions) || []).forEach(function (r) { hiddenRegions[r] = true; });
  function isHidden(region) { return !!hiddenRegions[region]; }

  data.forEach(function (d) { d.Year = +d.Year; d.val = J.num(d.val); });
  data = data.filter(function (d) { return d.val !== null; });

  var regions = Array.from(new Set(data.map(function (d) { return d.Region; }))).sort();
  var years   = Array.from(new Set(data.map(function (d) { return d.Year; }))).sort(function (a, b) { return a - b; });
  function colorFor(r) { return J.colorFor(r, colors, regions); }

  if (!data.length || !years.length) {
    svg.append("text").attr("x", width / 2).attr("y", height / 2)
       .attr("text-anchor", "middle").attr("fill", "#7aa7b5").style("font-size", "14px")
       .text("No data for this selection");
    return;
  }

  // normalised height = value as % of that metric's max
  function normVal(d) { return (d.metric === "AMR" ? d.val / amrMax : d.val / amcMax) * 100; }

  J.ensureTooltip();
  function tipHtml(d) {
    var unit = d.metric === "AMR" ? " %" : " mg/kg";
    var extra = normalize ? " (" + normVal(d).toFixed(0) + "% of max)" : "";
    return "<span style='color:" + colorFor(d.Region) + ";font-weight:700'>" + d.Region + "</span> · " + d.Year +
      "<br>" + d.metric + ": <b>" + d.val.toFixed(1) + unit + "</b>" + extra;
  }

  // diagonal-hatch pattern per region for the AMC series
  var defs = svg.append("defs");
  regions.forEach(function (r, i) {
    var p = defs.append("pattern").attr("id", "cmp-hatch-" + i)
      .attr("patternUnits", "userSpaceOnUse").attr("width", 6).attr("height", 6)
      .attr("patternTransform", "rotate(45)");
    p.append("rect").attr("width", 6).attr("height", 6).attr("fill", colorFor(r)).attr("opacity", 0.20);
    p.append("line").attr("x1", 0).attr("y1", 0).attr("x2", 0).attr("y2", 6)
      .attr("stroke", colorFor(r)).attr("stroke-width", 3);
  });
  function fillFor(d) {
    if (d.metric === "AMC") return "url(#cmp-hatch-" + regions.indexOf(d.Region) + ")";
    return colorFor(d.Region);
  }

  // ---- legend: shared region legend + AMR/AMC encoding note ----------
  var legendH = 34;
  var lg = svg.append("g").attr("transform", "translate(14,18)");
  var lx = J.drawRegionLegend(lg, {
    regions: regions, colorForR: colorFor, isHidden: isHidden,
    toggleInputId: toggleInputId, colorPickInputId: colorPickInputId, startX: 0
  });
  lg.append("text").attr("x", lx + 6).attr("y", 1).attr("fill", "#5a6b70")
    .style("font-size", "11px")
    .text(normalize ? "solid = AMR   hatched = AMC   (both as % of max)"
                    : "■ solid = AMR (%, left)   ▨ hatched = AMC (mg/kg, right)");

  var pad = { t: legendH + 6, r: normalize ? 24 : 62, b: 52, l: 60 };
  var iw = width - pad.l - pad.r;
  var ih = height - pad.t - pad.b;

  // scales: normalised -> single 0-100 axis; otherwise dual axes
  var yL = d3.scaleLinear().domain([0, normalize ? 100 : amrMax]).range([pad.t + ih, pad.t]);
  var yR = d3.scaleLinear().domain([0, amcMax]).range([pad.t + ih, pad.t]);
  function yPos(d) { return normalize ? yL(normVal(d)) : (d.metric === "AMR" ? yL : yR)(d.val); }

  var x = d3.scaleBand().domain(years).range([pad.l, pad.l + iw]).padding(0.2);
  var groups = [];
  regions.forEach(function (r) { groups.push(r + "|AMR"); groups.push(r + "|AMC"); });
  var xG = d3.scaleBand().domain(groups).range([0, x.bandwidth()]).padding(0.08);

  // left axis
  svg.append("g").attr("transform", "translate(" + pad.l + ",0)")
    .call(d3.axisLeft(yL).ticks(5).tickSize(-iw))
    .call(function (s) { s.select(".domain").remove(); })
    .call(function (s) { s.selectAll("line").attr("stroke", "#E7EFF3"); })
    .call(function (s) { s.selectAll("text").attr("fill", "#0C5468").style("font-size", "10px"); });
  // right axis (only when not normalised)
  if (!normalize) {
    svg.append("g").attr("transform", "translate(" + (pad.l + iw) + ",0)")
      .call(d3.axisRight(yR).ticks(5))
      .call(function (s) { s.select(".domain").attr("stroke", "#D6E4EA"); })
      .call(function (s) { s.selectAll("line").attr("stroke", "#D6E4EA"); })
      .call(function (s) { s.selectAll("text").attr("fill", "#0C5468").style("font-size", "10px"); });
  }

  // x axis (years, thinned if many)
  var step = years.length > 14 ? 2 : 1;
  svg.append("g").attr("transform", "translate(0," + (pad.t + ih) + ")")
    .call(d3.axisBottom(x).tickValues(years.filter(function (yy, idx) { return idx % step === 0; })))
    .call(function (s) { s.select(".domain").attr("stroke", "#D6E4EA"); })
    .call(function (s) { s.selectAll("line").attr("stroke", "#D6E4EA"); })
    .call(function (s) {
      s.selectAll("text").attr("fill", "#0C5468").style("font-size", "9px")
        .attr("transform", "rotate(-90)").attr("text-anchor", "end")
        .attr("dx", "-0.5em").attr("dy", "-0.5em");
    });

  // axis captions
  svg.append("text").attr("transform", "rotate(-90)")
    .attr("x", -(pad.t + ih / 2)).attr("y", 14).attr("text-anchor", "middle")
    .attr("fill", "#0C5468").style("font-size", "11px").style("font-weight", "700")
    .text(normalize ? "% of series max" : "AMR — % Resistance");
  if (!normalize) {
    svg.append("text").attr("transform", "rotate(-90)")
      .attr("x", -(pad.t + ih / 2)).attr("y", width - 12).attr("text-anchor", "middle")
      .attr("fill", "#0C5468").style("font-size", "11px").style("font-weight", "700")
      .text("AMC — mg/kg Consumption");
  }

  svg.selectAll("rect.cbar").data(data.filter(function (d) { return !isHidden(d.Region); }))
    .enter().append("rect").attr("class", "cbar")
    .attr("x", function (d) { return x(d.Year) + xG(d.Region + "|" + d.metric); })
    .attr("width", xG.bandwidth())
    .attr("y", function (d) { return yPos(d); })
    .attr("height", function (d) { return (pad.t + ih) - yPos(d); })
    .attr("fill", fillFor)
    .attr("stroke", function (d) { return colorFor(d.Region); })
    .attr("stroke-width", function (d) { return d.metric === "AMC" ? 0.8 : 0; })
    .attr("rx", 1.5).style("cursor", "pointer")
    .on("mousemove", function (d) { d3.select(this).attr("opacity", 0.82); J.showTip(d3.event, tipHtml(d)); })
    .on("mouseleave", function () { d3.select(this).attr("opacity", 1); J.hideTip(); });
}

// =====================================================================
// Monnet plot (scatter) — x = AMC (mg/kg), y = AMR (%), 4 action zones
// =====================================================================
function renderScatter() {
  var xmed = (options && options.xmed != null) ? +options.xmed : 0;
  var ymed = (options && options.ymed != null) ? +options.ymed : 0;
  var xlab = (options && options.xlab) || "Antibiotic consumption (mg/kg)";
  var ylab = (options && options.ylab) || "Resistance level (%)";

  data.forEach(function (d) { d.Year = +d.Year; d.x = J.num(d.x); d.y = J.num(d.y); });
  data = data.filter(function (d) { return d.x !== null && d.y !== null; });

  if (!data.length) {
    svg.append("text").attr("x", width / 2).attr("y", height / 2)
       .attr("text-anchor", "middle").attr("fill", "#7aa7b5").style("font-size", "14px")
       .text("No overlapping years between the AMR and AMC selections");
    return;
  }

  var showArrows = (options && options.arrows) !== false; // default on
  var regions = Array.from(new Set(data.map(function (d) { return d.Region; }))).sort();
  var sectors = Array.from(new Set(data.map(function (d) { return d.Sector; })));
  function colorFor(r) { return J.colorFor(r, colors, regions); }
  // Human = circle, Animal = triangle
  function symbolFor(sec) { return sec === "Animal" ? d3.symbolTriangle : d3.symbolCircle; }

  // one arrowhead marker per region (coloured), used on the time trajectories
  var defs = svg.append("defs");
  regions.forEach(function (r, i) {
    defs.append("marker").attr("id", "cmp-arrow-" + i)
      .attr("viewBox", "0 -5 10 10").attr("refX", 9).attr("refY", 0)
      .attr("markerWidth", 6).attr("markerHeight", 6).attr("orient", "auto")
      .append("path").attr("d", "M0,-5L10,0L0,5").attr("fill", colorFor(r));
  });

  var pad = { t: 54, r: 30, b: 62, l: 66 };
  var iw = width - pad.l - pad.r;
  var ih = height - pad.t - pad.b;

  // ---- axes AUTO-FIT the data (do NOT start at 0), padded ~12% -------
  var xExtent = d3.extent(data, function (d) { return d.x; });
  var yExtent = d3.extent(data, function (d) { return d.y; });
  var xPad = (xExtent[1] - xExtent[0]) * 0.12 || Math.max(xExtent[1] * 0.1, 1);
  var yPad = (yExtent[1] - yExtent[0]) * 0.12 || Math.max(yExtent[1] * 0.1, 1);
  var xDom = [Math.max(0, xExtent[0] - xPad), xExtent[1] + xPad];
  var yDom = [Math.max(0, yExtent[0] - yPad), yExtent[1] + yPad];

  var x = d3.scaleLinear().domain(xDom).range([pad.l, pad.l + iw]);
  var y = d3.scaleLinear().domain(yDom).range([pad.t + ih, pad.t]);
  var xm = x(xmed), ymD = y(ymed);
  // clamp the median lines to the drawing area (a median can sit outside the
  // padded domain if the data are skewed)
  xm = Math.max(pad.l, Math.min(pad.l + iw, xm));
  ymD = Math.max(pad.t, Math.min(pad.t + ih, ymD));

  // quadrant tints
  var zones = [
    { x0: pad.l, x1: xm, y0: pad.t, y1: ymD, fill: "#e4572e" },
    { x0: xm, x1: pad.l + iw, y0: pad.t, y1: ymD, fill: "#c0392b" },
    { x0: pad.l, x1: xm, y0: ymD, y1: pad.t + ih, fill: "#2ca02c" },
    { x0: xm, x1: pad.l + iw, y0: ymD, y1: pad.t + ih, fill: "#f0a202" }
  ];
  zones.forEach(function (z) {
    svg.append("rect")
      .attr("x", Math.min(z.x0, z.x1)).attr("y", Math.min(z.y0, z.y1))
      .attr("width", Math.abs(z.x1 - z.x0)).attr("height", Math.abs(z.y1 - z.y0))
      .attr("fill", z.fill).attr("opacity", 0.06);
  });

  // axes
  svg.append("g").attr("transform", "translate(0," + (pad.t + ih) + ")")
    .call(d3.axisBottom(x).ticks(6))
    .call(function (s) { s.select(".domain").attr("stroke", "#0C5468"); })
    .call(function (s) { s.selectAll("line").attr("stroke", "#0C5468"); })
    .call(function (s) { s.selectAll("text").attr("fill", "#0C5468").style("font-size", "10px"); });
  svg.append("g").attr("transform", "translate(" + pad.l + ",0)")
    .call(d3.axisLeft(y).ticks(6))
    .call(function (s) { s.select(".domain").attr("stroke", "#0C5468"); })
    .call(function (s) { s.selectAll("line").attr("stroke", "#0C5468"); })
    .call(function (s) { s.selectAll("text").attr("fill", "#0C5468").style("font-size", "10px"); });

  svg.append("text").attr("x", pad.l + iw / 2).attr("y", height - 14)
    .attr("text-anchor", "middle").attr("fill", "#0C5468")
    .style("font-size", "12px").style("font-weight", "700").text(xlab);
  svg.append("text").attr("transform", "rotate(-90)")
    .attr("x", -(pad.t + ih / 2)).attr("y", 16)
    .attr("text-anchor", "middle").attr("fill", "#0C5468")
    .style("font-size", "12px").style("font-weight", "700").text(ylab);

  // median lines + labels
  svg.append("line").attr("x1", xm).attr("x2", xm).attr("y1", pad.t).attr("y2", pad.t + ih)
    .attr("stroke", "#0C5468").attr("stroke-width", 1.2).attr("stroke-dasharray", "6,4").attr("opacity", 0.8);
  svg.append("text").attr("x", xm + 4).attr("y", pad.t + 12)
    .attr("fill", "#0C5468").style("font-size", "10px").style("font-style", "italic").text("median");
  svg.append("line").attr("x1", pad.l).attr("x2", pad.l + iw).attr("y1", ymD).attr("y2", ymD)
    .attr("stroke", "#0C5468").attr("stroke-width", 1.2).attr("stroke-dasharray", "6,4").attr("opacity", 0.8);
  svg.append("text").attr("x", pad.l + iw - 4).attr("y", ymD - 4)
    .attr("text-anchor", "end").attr("fill", "#0C5468").style("font-size", "10px")
    .style("font-style", "italic").text("median");

  // quadrant titles
  function zoneTitle(tx, ty, anchor, l1, l2) {
    var g = svg.append("text").attr("x", tx).attr("y", ty)
      .attr("text-anchor", anchor).attr("fill", "#5a6b70")
      .style("font-size", "10.5px").style("font-weight", "700");
    g.append("tspan").attr("x", tx).text(l1);
    g.append("tspan").attr("x", tx).attr("dy", "1.15em").text(l2);
  }
  zoneTitle(pad.l + 6, pad.t + 14, "start", "High resistance", "Low consumption");
  zoneTitle(pad.l + iw - 6, pad.t + 14, "end", "High resistance", "High consumption");
  zoneTitle(pad.l + 6, pad.t + ih - 26, "start", "Low resistance", "Low consumption (satisfactory)");
  zoneTitle(pad.l + iw - 6, pad.t + ih - 26, "end", "Low resistance", "High consumption");

  // tooltip
  J.ensureTooltip();
  function tooltipHtml(d) {
    return "<span style='color:" + colorFor(d.Region) + ";font-weight:700'>" + d.Region + "</span> · " +
      d.Sector + " · " + d.Year +
      "<br>Consumption: <b>" + d.x.toFixed(1) + " mg/kg</b>" +
      "<br>Resistance: <b>" + d.y.toFixed(1) + " %</b>";
  }

  // chronological trajectory per region × sector, drawn as directional arrows
  // (arrowheads point in the direction of time). Toggled by options.arrows.
  var line = d3.line().x(function (d) { return x(d.x); }).y(function (d) { return y(d.y); });
  if (showArrows) {
    regions.forEach(function (r) {
      sectors.forEach(function (sec) {
        var rd = data.filter(function (d) { return d.Region === r && d.Sector === sec; })
                     .sort(function (a, b) { return a.Year - b.Year; });
        if (rd.length > 1) {
          var mk = "url(#cmp-arrow-" + regions.indexOf(r) + ")";
          svg.append("path").datum(rd).attr("d", line).attr("fill", "none")
            .attr("stroke", colorFor(r)).attr("stroke-width", 1.6).attr("opacity", 0.55)
            .attr("stroke-dasharray", sec === "Animal" ? "4,3" : null)
            .attr("marker-mid", mk).attr("marker-end", mk);
        }
      });
    });
  }

  // points (symbol by sector, colour by region) + year labels
  svg.selectAll("path.pt").data(data).enter().append("path").attr("class", "pt")
    .attr("d", function (d) { return d3.symbol().type(symbolFor(d.Sector)).size(80)(); })
    .attr("transform", function (d) { return "translate(" + x(d.x) + "," + y(d.y) + ")"; })
    .attr("fill", function (d) { return colorFor(d.Region); })
    .attr("stroke", "#fff").attr("stroke-width", 1).style("cursor", "pointer")
    .on("mousemove", function (d) {
      d3.select(this).attr("d", d3.symbol().type(symbolFor(d.Sector)).size(160)());
      J.showTip(d3.event, tooltipHtml(d));
    })
    .on("mouseleave", function (d) {
      d3.select(this).attr("d", d3.symbol().type(symbolFor(d.Sector)).size(80)());
      J.hideTip();
    });

  if (data.length <= 40) {
    svg.selectAll("text.yr").data(data).enter().append("text").attr("class", "yr")
      .attr("x", function (d) { return x(d.x) + 7; })
      .attr("y", function (d) { return y(d.y) - 6; })
      .attr("fill", "#5a6b70").style("font-size", "8.5px")
      .text(function (d) { return d.Year; });
  }

  // region legend (colours) + sector legend (symbols)
  var lg = svg.append("g").attr("transform", "translate(" + (pad.l + 2) + ",22)");
  var endX = J.drawRegionLegend(lg, { regions: regions, colorForR: colorFor, startX: 0 });
  var sx = endX + 10;
  sectors.forEach(function (sec) {
    var g = lg.append("g").attr("transform", "translate(" + sx + ",0)");
    g.append("path")
      .attr("d", d3.symbol().type(symbolFor(sec)).size(70)())
      .attr("transform", "translate(6,-4)")
      .attr("fill", "#5a6b70");
    g.append("text").attr("x", 16).attr("y", 1).attr("fill", "#0C5468")
      .style("font-size", "12px").text(sec);
    sx += 30 + sec.length * 8;
  });
}
