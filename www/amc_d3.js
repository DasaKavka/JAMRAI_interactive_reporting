// =====================================================================
// amc_d3.js — r2d3 prototype for the JAMRAI AMR AMC dashboard
// Faceted small-multiples, one panel per Host (species). Two chart types,
// picked in R via options.chartType ("curve" | "radar") from the
// "Chart type" toggle:
//   - "curve": grouped bars (mg/kg)
//   - "radar": one closed polygon per region (years around the circle,
//     radius = mg/kg).
//
// r2d3 injects into scope: svg, data, width, height, options, theme.
// `data` is an array of row objects with columns:
//   ...1,Year, icon, signif_level, label_icon, label, Host, mg_kg, Region
// =====================================================================

var colors = (options && options.colors) || {};            // { region: colour } supplied by R
var ymax   = (options && options.ymax) ? +options.ymax : 175;
var chartType = (options && options.chartType) || "curve"; // "curve" | "radar"

// fully-qualified Shiny input ids (namespaced in R via session$ns)
var colorPickInputId = (options && options.colorPickInputId) || "amc_color_pick";
var toggleInputId    = (options && options.toggleInputId)    || "amc_region_toggle";

var FONT    = "'ITC Avant Garde Gothic','Century Gothic','Segoe UI',sans-serif";
var PALETTE = ["#078BAD", "#0FDBD5", "#1f77b4", "#e4572e", "#2ca02c", "#9467bd", "#8c564b", "#333333"];

// regions hidden by clicking their legend swatch/label (R supplies the list)
var hiddenRegions = {};
((options && options.hiddenRegions) || []).forEach(function (r) { hiddenRegions[r] = true; });
function isHidden(region) { return !!hiddenRegions[region]; }

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
  d.mgkg = num(d.mg_kg);
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
function colorFor(region) {
  if (colors && colors[region]) return colors[region];
  var i = regions.indexOf(region);
  return PALETTE[(i >= 0 ? i : 0) % PALETTE.length];
}

// ---- tooltip --------------------------------------------------------
var tip = d3.select("body").selectAll("div.d3tip-amc").data([0]);
tip = tip.enter().append("div").attr("class", "d3tip-amc")
  .style("position", "fixed").style("pointer-events", "none")
  .style("background", "rgba(255,255,255,.97)").style("border", "1px solid #D6E4EA")
  .style("border-radius", "8px").style("box-shadow", "0 4px 16px rgba(7,139,173,.20)")
  .style("padding", "8px 11px").style("font", "12px " + FONT).style("color", "#0C5468")
  .style("line-height", "1.45").style("z-index", 9999).style("opacity", 0)
  .merge(tip);

function tooltipHtml(host, d) {
  var val = d.mgkg !== null ? d.mgkg.toFixed(1) : "NA";
  return "<b>" + host + "</b><br>" +
    "<span style='color:" + colorFor(d.Region) + ";font-weight:700'>" + d.Region + "</span> · " + d.Year +
    "<br>Consumption: <b>" + val + " mg/kg</b>";
}

function showTip(ev, html) {
  if (!ev) return;
  var t = d3.select("body").select("div.d3tip-amc");
  if (t.empty()) return;
  var tw = 200, tx = ev.clientX + 16, ty = ev.clientY + 12;
  if (tx + tw > window.innerWidth) tx = ev.clientX - tw - 12;
  t.style("opacity", 1).style("left", tx + "px").style("top", ty + "px").html(html);
}
function hideTip() {
  d3.select("body").select("div.d3tip-amc").style("opacity", 0);
}

// ---- hidden native colour input ------------------------------------
var picker = d3.select("body").selectAll("input.d3-legend-color").data([0]);
picker = picker.enter().append("input")
  .attr("class", "d3-legend-color").attr("type", "color")
  .style("position", "fixed").style("width", "1px").style("height", "1px")
  .style("opacity", 0).style("border", "0").style("padding", "0").style("z-index", 9999)
  .merge(picker);
var pickerNode = picker.node();

// ---- legend ---------------------------------------------------------
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
        showTip(d3.event, tooltipHtml(host, d));
      })
      .on("mouseleave", function () {
        d3.select(this).attr("opacity", 1);
        hideTip();
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
        .on("mousemove", function (d) { showTip(d3.event, tooltipHtml(host, d)); })
        .on("mouseleave", hideTip);
    });
  });

  svg.append("text").attr("x", width / 2).attr("y", height - 6)
    .attr("text-anchor", "middle").attr("fill", "#0C5468").style("font-size", "11px")
    .text("Radius = Consumption (mg/kg)");
}