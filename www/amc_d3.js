// =====================================================================
// amc_d3.js — r2d3 prototype for the JAMRAI AMC dashboard
// Faceted small-multiples, one panel per Host (species). Two chart types,
// picked in R via options.chartType ("curve" | "radar") from the
// "Chart type" toggle:
//   - "curve": grouped bars (mg/kg)
//   - "radar": one closed polygon per region (years around the circle,
//     radius = mg/kg).
//
// Shared primitives (num, colorFor, tooltip, colour picker, region legend)
// live in www/chart_common.js -> window.JAMRAI. This file keeps only the
// AMC-specific rendering.
//
// r2d3 injects into scope: svg, data, width, height, options, theme.
// `data` is an array of row objects with columns:
//   ...1,Year, icon, signif_level, label_icon, label, Host, mg_kg, Region
// =====================================================================

var J = window.JAMRAI;

var colors = (options && options.colors) || {};            // { region: colour } supplied by R
var ymax   = (options && options.ymax) ? +options.ymax : 175;
var chartType = (options && options.chartType) || "curve"; // "curve" | "radar"

// fully-qualified Shiny input ids (namespaced in R via session$ns)
var colorPickInputId = (options && options.colorPickInputId) || "amc_color_pick";
var toggleInputId    = (options && options.toggleInputId)    || "amc_region_toggle";

var FONT = J.FONT;

// regions hidden by clicking their legend swatch/label (R supplies the list)
var hiddenRegions = {};
((options && options.hiddenRegions) || []).forEach(function (r) { hiddenRegions[r] = true; });
function isHidden(region) { return !!hiddenRegions[region]; }

svg.selectAll("*").remove();
svg.style("font-family", FONT);

// ---- coerce + clean -------------------------------------------------
data.forEach(function (d) {
  d.Year = +d.Year;
  d.mgkg = J.num(d.mg_kg);
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

// generic colour lookup — no hard-coded region names
function colorFor(region) { return J.colorFor(region, colors, regions); }

// shared tooltip singleton
J.ensureTooltip();

function tooltipHtml(host, d) {
  var val = d.mgkg !== null ? d.mgkg.toFixed(1) : "NA";
  return "<b>" + host + "</b><br>" +
    "<span style='color:" + colorFor(d.Region) + ";font-weight:700'>" + d.Region + "</span> · " + d.Year +
    "<br>Consumption: <b>" + val + " mg/kg</b>";
}

// ---- legend (shared region legend: hide/recolour) -------------------
var legendH = 30;
var lg = svg.append("g").attr("transform", "translate(14,18)");
J.drawRegionLegend(lg, {
  regions: regions,
  colorForR: colorFor,
  isHidden: isHidden,
  toggleInputId: toggleInputId,
  colorPickInputId: colorPickInputId,
  startX: 0
});

// ---- facet grid -----------------------------------------------------
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
// "curve" chart: grouped bars
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

    // observed bars (grouped by region, hidden regions excluded)
    g.selectAll("rect.bar").data(
      fdata.filter(function (d) { return d.mgkg !== null && !isHidden(d.Region); })
    )
      .enter().append("rect").attr("class", "bar")
      .attr("x", function (d) { return x(d.Year) + xR(d.Region); })
      .attr("width", xR.bandwidth())
      .attr("y", function (d) { return y(d.mgkg); })
      .attr("height", function (d) { return (pad.t + ih) - y(d.mgkg); })
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
  });

  // shared y-axis caption
  svg.append("text").attr("transform", "rotate(-90)")
    .attr("x", -(legendH + (height - legendH) / 2)).attr("y", 14)
    .attr("text-anchor", "middle").attr("fill", "#0C5468").style("font-size", "11px")
    .text("mg/kg Consumption");
}

// =====================================================================
// "radar" chart: one closed polygon per region, years around the circle,
// radius = consumption (mg/kg).
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

    function angle(year) { return -Math.PI / 2 + years.indexOf(year) * (2 * Math.PI / years.length); }
    var rScale = d3.scaleLinear().domain([0, ymax]).range([0, radius]);
    var px = function (year, val) { return centerX + rScale(val) * Math.cos(angle(year)); };
    var py = function (year, val) { return centerY + rScale(val) * Math.sin(angle(year)); };

    // radial grid
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

    var radarLine = d3.line()
      .x(function (d) { return px(d.Year, d.mgkg); })
      .y(function (d) { return py(d.Year, d.mgkg); })
      .curve(d3.curveLinearClosed);

    regions.forEach(function (r) {
      if (isHidden(r)) return;
      var rd = fdata.filter(function (d) { return d.Region === r && d.mgkg !== null; })
                    .sort(function (a, b) { return years.indexOf(a.Year) - years.indexOf(b.Year); });
      if (rd.length < 3) return;

      g.append("path").datum(rd).attr("d", radarLine)
        .attr("fill", colorFor(r)).attr("fill-opacity", 0.18)
        .attr("stroke", colorFor(r)).attr("stroke-width", 2.2);

      g.selectAll(null).data(rd).enter().append("circle")
        .attr("cx", function (d) { return px(d.Year, d.mgkg); })
        .attr("cy", function (d) { return py(d.Year, d.mgkg); })
        .attr("r", 3.5)
        .attr("fill", colorFor(r)).attr("stroke", "#fff").attr("stroke-width", 1)
        .style("cursor", "pointer")
        .on("mousemove", function (d) { J.showTip(d3.event, tooltipHtml(host, d)); })
        .on("mouseleave", J.hideTip);
    });
  });

  svg.append("text").attr("x", width / 2).attr("y", height - 6)
    .attr("text-anchor", "middle").attr("fill", "#0C5468").style("font-size", "11px")
    .text("Radius = Consumption (mg/kg)");
}
