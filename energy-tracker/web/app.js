/* Dashboard client. Charts are drawn as plain SVG rather than pulled from a CDN,
   so the tracker works on an isolated building network with no internet. */

const SYSTEM_COLORS = ['#4f7c1f', '#7ab32e', '#2f6fb0', '#c2870b', '#6b7f99', '#9c5fb5', '#3f9e8c'];
const UTILITY_CLASS = { electricity: '', gas: 'gas', water: 'water' };

const state = { data: null, siteId: null, months: 12 };

const $ = (id) => document.getElementById(id);

const fmt = {
  number: (n, digits = 0) => Number(n || 0).toLocaleString(undefined,
    { minimumFractionDigits: digits, maximumFractionDigits: digits }),
  money: (n) => '$' + Number(n || 0).toLocaleString(undefined,
    { minimumFractionDigits: 0, maximumFractionDigits: 0 }),
  percent: (fraction, digits = 1) => (fraction === null || fraction === undefined)
    ? '--' : (fraction * 100).toFixed(digits) + '%',
  signedPercent: (fraction) => (fraction === null || fraction === undefined)
    ? '--' : (fraction >= 0 ? '+' : '') + (fraction * 100).toFixed(1) + '%',
  compact: (n) => {
    const value = Number(n || 0);
    if (Math.abs(value) >= 1e6) return (value / 1e6).toFixed(1) + 'M';
    if (Math.abs(value) >= 1e3) return Math.round(value / 1e3) + 'K';
    return Math.round(value).toString();
  },
};

/* ---------- data ---------- */

async function load() {
  const params = new URLSearchParams({ months: String(state.months) });
  if (state.siteId) params.set('site', String(state.siteId));
  const response = await fetch('/api/dashboard?' + params.toString());
  if (!response.ok) throw new Error('dashboard request failed (' + response.status + ')');
  state.data = await response.json();
  if (!state.siteId && state.data.site) state.siteId = state.data.site.id;
  render();
}

function render() {
  const data = state.data;
  $('loading').hidden = true;
  $('dashboard').hidden = false;
  renderSiteOptions(data.sites || []);

  if (data.empty) {
    $('period-title').textContent = 'No readings yet';
    $('kpi-row').innerHTML =
      '<article class="card"><p class="empty-state">Add a reading or import a CSV below to start tracking.</p></article>';
    ['series-chart', 'donut-chart'].forEach((id) => { $(id).innerHTML = ''; });
    ['donut-legend', 'alert-list', 'movers-body', 'forecast-body', 'readings-body']
      .forEach((id) => { $(id).innerHTML = ''; });
    renderMeterOptions(data.meters || []);
    return;
  }

  $('period-title').textContent = data.kpis.label + ' · ' + (data.site ? data.site.name : 'All sites') +
    (data.pending_period ? ' · ' + data.pending_period + ' still coming in' : '');
  renderKpis(data.kpis);
  drawSeries(data.series, data.forecast, data.kpis.unit);
  drawDonut(data.by_system, data.kpis.unit);
  renderAlerts(data.alerts);
  renderMovers(data.movers);
  renderForecast(data.forecast, data.kpis.unit);
  renderLatestReadings(data);
  renderMeterOptions(data.meters || []);
  if (data.forecast && data.forecast.length) $('forecast-basis').textContent =
    'Basis: ' + data.forecast[0].basis + '.';
}

/* ---------- KPI tiles ---------- */

function deltaMarkup(change, { lowerIsBetter = true, caption = 'vs last month' } = {}) {
  if (change === null || change === undefined) {
    return '<div class="kpi-delta flat">&mdash; <small>no prior month</small></div>';
  }
  const improving = lowerIsBetter ? change < 0 : change > 0;
  const cls = Math.abs(change) < 0.005 ? 'flat' : (improving ? 'down' : 'up');
  const arrow = change > 0 ? '↑' : (change < 0 ? '↓' : '→');
  return '<div class="kpi-delta ' + cls + '">' + arrow + ' ' +
    fmt.percent(Math.abs(change)) + ' <small>' + caption + '</small></div>';
}

function tile(label, value, unit, deltaHtml) {
  return '<article class="card kpi">' +
    '<div class="kpi-label">' + label + '</div>' +
    '<div class="kpi-value">' + value + (unit ? '<span class="unit">' + unit + '</span>' : '') + '</div>' +
    deltaHtml + '</article>';
}

function renderKpis(k) {
  const tiles = [
    tile('Total energy use', fmt.number(k.consumption), k.unit, deltaMarkup(k.consumption_change)),
    tile('Utility cost', fmt.money(k.cost), '', deltaMarkup(k.cost_change)),
    tile('Carbon footprint', fmt.number(k.co2e_kg / 1000, 1), 't CO₂e',
      deltaMarkup(k.consumption_change_yoy, { caption: 'vs same month last year' })),
  ];
  if (k.eui !== null && k.eui !== undefined) {
    tiles.push(tile('Energy use intensity', k.eui.toFixed(2), 'kWh/ft²',
      '<div class="kpi-delta flat">&mdash; <small>monthly, electricity only</small></div>'));
  }
  $('kpi-row').innerHTML = tiles.join('');
}

/* ---------- line chart ---------- */

function svgEl(name, attrs) {
  const node = document.createElementNS('http://www.w3.org/2000/svg', name);
  Object.entries(attrs || {}).forEach(([key, value]) => node.setAttribute(key, String(value)));
  return node;
}

function drawSeries(series, forecastRows, unit) {
  const svg = $('series-chart');
  svg.innerHTML = '';
  if (!series.length) return;

  const W = 720, H = 280, pad = { top: 16, right: 18, bottom: 34, left: 56 };
  const forecast = forecastRows || [];
  const points = series.map((row) => ({ label: row.label, axis: row.short_label, value: row.consumption, projected: false }))
    .concat(forecast.map((row) => ({ label: row.label, axis: row.short_label, value: row.consumption, projected: true })));

  const max = Math.max(...points.map((p) => p.value), 1);
  const ceiling = niceCeiling(max);
  const plotW = W - pad.left - pad.right;
  const plotH = H - pad.top - pad.bottom;
  const x = (i) => pad.left + (points.length === 1 ? plotW / 2 : (i / (points.length - 1)) * plotW);
  const y = (v) => pad.top + plotH - (v / ceiling) * plotH;

  // Horizontal gridlines with value labels.
  for (let step = 0; step <= 4; step++) {
    const value = (ceiling / 4) * step;
    const yy = y(value);
    svg.appendChild(svgEl('line', { class: 'chart-grid', x1: pad.left, x2: W - pad.right, y1: yy, y2: yy }));
    const label = svgEl('text', { class: 'chart-axis', x: pad.left - 8, y: yy + 3.5, 'text-anchor': 'end' });
    label.textContent = fmt.compact(value);
    svg.appendChild(label);
  }

  const actual = points.filter((p) => !p.projected);
  const areaPath = actual.map((p, i) => (i ? 'L' : 'M') + x(i) + ' ' + y(p.value)).join(' ') +
    ' L' + x(actual.length - 1) + ' ' + y(0) + ' L' + x(0) + ' ' + y(0) + ' Z';
  svg.appendChild(svgEl('path', { d: areaPath, fill: 'rgba(79,124,31,.10)' }));
  svg.appendChild(svgEl('path', {
    class: 'chart-line',
    d: actual.map((p, i) => (i ? 'L' : 'M') + x(i) + ' ' + y(p.value)).join(' '),
  }));

  if (forecast.length) {
    // Start the dashed run at the last actual point so the two lines meet.
    const bridge = points.slice(actual.length - 1);
    svg.appendChild(svgEl('path', {
      class: 'chart-line forecast',
      d: bridge.map((p, i) => (i ? 'L' : 'M') + x(actual.length - 1 + i) + ' ' + y(p.value)).join(' '),
    }));
  }

  const alerted = new Set((state.data.alerts || []).map((a) => a.period));
  points.forEach((p, i) => {
    const dot = svgEl('circle', {
      class: 'chart-dot' + (!p.projected && alerted.has(series[i] && series[i].period) ? ' alerted' : ''),
      cx: x(i), cy: y(p.value), r: 3.6,
    });
    if (p.projected) { dot.setAttribute('stroke', '#2f6fb0'); }
    const title = svgEl('title');
    title.textContent = p.label + ': ' + fmt.number(p.value) + ' ' + unit + (p.projected ? ' (projected)' : '');
    dot.appendChild(title);
    svg.appendChild(dot);
  });

  // Label every other month so the axis stays readable at any range.
  const stride = points.length > 14 ? 3 : (points.length > 8 ? 2 : 1);
  points.forEach((p, i) => {
    if (i % stride !== 0 && i !== points.length - 1) return;
    const label = svgEl('text', { class: 'chart-axis', x: x(i), y: H - 12, 'text-anchor': 'middle' });
    label.textContent = p.axis || p.label;
    svg.appendChild(label);
  });
}

function niceCeiling(max) {
  const magnitude = Math.pow(10, Math.floor(Math.log10(max)));
  return Math.ceil((max * 1.1) / magnitude) * magnitude;
}

/* ---------- donut ---------- */

function drawDonut(rows, unit) {
  const svg = $('donut-chart');
  svg.innerHTML = '';
  const legend = $('donut-legend');
  legend.innerHTML = '';
  if (!rows.length) return;

  const cx = 120, cy = 88, outer = 66, inner = 42;
  const total = rows.reduce((sum, row) => sum + row.consumption, 0);
  let angle = -Math.PI / 2;

  rows.forEach((row, i) => {
    const sweep = total ? (row.consumption / total) * Math.PI * 2 : 0;
    const color = SYSTEM_COLORS[i % SYSTEM_COLORS.length];
    svg.appendChild(svgEl('path', { d: ringSlice(cx, cy, inner, outer, angle, angle + sweep), fill: color }));
    angle += sweep;

    const li = document.createElement('li');
    li.innerHTML = '<span class="swatch" style="background:' + color + '"></span>' +
      '<span class="legend-name">' + escapeHtml(row.system || row.utility) + '</span>' +
      '<span class="legend-value">' + fmt.compact(row.consumption) + '</span>' +
      '<span class="legend-share">' + fmt.percent(row.share, 0) + '</span>';
    legend.appendChild(li);
  });

  const total_text = svgEl('text', { x: cx, y: cy - 2, 'text-anchor': 'middle', class: 'donut-total' });
  total_text.textContent = fmt.compact(total);
  svg.appendChild(total_text);
  // Keep the caption inside the ring's hole - the card heading already says which month.
  const caption = svgEl('text', { x: cx, y: cy + 14, 'text-anchor': 'middle', class: 'donut-caption' });
  caption.textContent = unit;
  svg.appendChild(caption);
}

function ringSlice(cx, cy, inner, outer, start, end) {
  // A full circle cannot be drawn as one arc; nudge it just short of 360 degrees.
  const sweep = Math.min(end - start, Math.PI * 2 - 1e-4);
  const finish = start + sweep;
  const large = sweep > Math.PI ? 1 : 0;
  const p = (radius, theta) => [cx + radius * Math.cos(theta), cy + radius * Math.sin(theta)];
  const [x1, y1] = p(outer, start), [x2, y2] = p(outer, finish);
  const [x3, y3] = p(inner, finish), [x4, y4] = p(inner, start);
  return 'M' + x1 + ' ' + y1 +
    ' A' + outer + ' ' + outer + ' 0 ' + large + ' 1 ' + x2 + ' ' + y2 +
    ' L' + x3 + ' ' + y3 +
    ' A' + inner + ' ' + inner + ' 0 ' + large + ' 0 ' + x4 + ' ' + y4 + ' Z';
}

/* ---------- panels ---------- */

function renderAlerts(alerts) {
  const list = $('alert-list');
  if (!alerts.length) {
    list.innerHTML = '<li class="empty-state good">Every meter is inside its normal range this month.</li>';
    return;
  }
  list.innerHTML = alerts.map((a) =>
    '<li class="alert ' + a.severity + '">' +
      '<span class="alert-badge">' + (a.kind === 'spike' ? a.severity : 'check meter') + '</span>' +
      '<div>' +
        '<div class="alert-meter">' + escapeHtml(a.meter) + '</div>' +
        '<div class="alert-detail">' + escapeHtml(a.message) + '</div>' +
        '<div class="alert-detail">' + fmt.number(a.consumption) + ' ' + a.unit +
          ' against a normal of ' + fmt.number(a.baseline) + ' ' + a.unit + '</div>' +
      '</div>' +
      '<div class="alert-cost">' + fmt.money(Math.abs(a.excess_cost)) +
        '<small>' + (a.excess_cost >= 0 ? 'extra this month' : 'below normal') + '</small></div>' +
    '</li>').join('');
}

function renderMovers(movers) {
  $('movers-body').innerHTML = movers.length ? movers.map((m) => {
    const cls = m.delta_cost > 0 ? 'up' : 'down';
    return '<tr>' +
      '<td>' + escapeHtml(m.meter) + '<div class="alert-detail">' + escapeHtml(m.system) + '</div></td>' +
      '<td class="num ' + cls + '">' + fmt.signedPercent(m.change) + '</td>' +
      '<td class="num ' + cls + '">' + (m.delta_cost >= 0 ? '+' : '−') +
        fmt.money(Math.abs(m.delta_cost)) + '</td>' +
      '</tr>';
  }).join('') : '<tr><td colspan="3" class="empty-state">Two months of readings are needed to compare.</td></tr>';
}

function renderForecast(rows, unit) {
  $('forecast-body').innerHTML = rows.length ? rows.map((row) =>
    '<tr><td>' + row.label + '</td>' +
    '<td class="num">' + fmt.number(row.consumption) + ' ' + unit + '</td>' +
    '<td class="num">' + fmt.money(row.cost) + '</td></tr>').join('')
    : '<tr><td colspan="3" class="empty-state">Not enough history to project.</td></tr>';
}

async function renderLatestReadings(data) {
  const params = new URLSearchParams({ limit: '40' });
  if (state.siteId) params.set('site', String(state.siteId));
  const response = await fetch('/api/readings?' + params.toString());
  const payload = await response.json();
  const latest = (payload.readings || []).filter((r) => r.period === data.period);
  $('readings-body').innerHTML = latest.map((r) =>
    '<tr><td>' + escapeHtml(r.meter) + '<div class="alert-detail">' + escapeHtml(r.system) + '</div></td>' +
    '<td><span class="pill ' + (UTILITY_CLASS[r.utility] || '') + '">' + escapeHtml(r.utility) + '</span></td>' +
    '<td class="num">' + fmt.number(r.consumption) + ' ' + r.unit + '</td>' +
    '<td class="num">' + fmt.money(r.cost) + '</td></tr>').join('') ||
    '<tr><td colspan="4" class="empty-state">No readings for this month.</td></tr>';
}

function renderSiteOptions(sites) {
  const select = $('site-select');
  if (select.dataset.count === String(sites.length)) return;
  select.dataset.count = String(sites.length);
  select.innerHTML = sites.map((s) =>
    '<option value="' + s.id + '">' + escapeHtml(s.name) + '</option>').join('');
  if (state.siteId) select.value = String(state.siteId);
}

function renderMeterOptions(meters) {
  const select = $('reading-meter');
  const previous = select.value;
  select.innerHTML = meters.map((m) =>
    '<option value="' + m.id + '">' + escapeHtml(m.name) + ' (' + m.unit + ')</option>').join('');
  if (previous) select.value = previous;
}

function escapeHtml(value) {
  return String(value === null || value === undefined ? '' : value)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function note(id, message, ok) {
  const el = $(id);
  el.textContent = message;
  el.className = 'form-note ' + (ok ? 'ok' : 'bad');
}

/* ---------- events ---------- */

$('site-select').addEventListener('change', (event) => {
  state.siteId = Number(event.target.value);
  load().catch(showFailure);
});

$('range-select').addEventListener('change', (event) => {
  state.months = Number(event.target.value);
  load().catch(showFailure);
});

$('export-btn').addEventListener('click', () => {
  const params = state.siteId ? '?site=' + state.siteId : '';
  window.location.href = '/api/export.csv' + params;
});

$('reading-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const body = {
    meter_id: Number($('reading-meter').value),
    period: $('reading-period').value,
    consumption: $('reading-consumption').value,
    cost: $('reading-cost').value || null,
  };
  const response = await fetch('/api/readings', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const payload = await response.json();
  if (!response.ok) return note('reading-note', payload.error || 'Could not save.', false);
  note('reading-note', 'Saved.', true);
  $('reading-consumption').value = '';
  $('reading-cost').value = '';
  load().catch(showFailure);
});

$('import-file-btn').addEventListener('click', () => $('import-file').click());

$('import-file').addEventListener('change', async (event) => {
  const file = event.target.files[0];
  if (file) $('import-text').value = await file.text();
});

$('import-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const text = $('import-text').value.trim();
  if (!text) return note('import-note', 'Paste or choose a CSV first.', false);
  const params = state.siteId ? '?site=' + state.siteId : '';
  const response = await fetch('/api/import' + params, {
    method: 'POST',
    headers: { 'Content-Type': 'text/csv' },
    body: text,
  });
  const result = await response.json();
  if (!response.ok && !result.imported) {
    return note('import-note', (result.errors || ['Import failed.']).join(' | '), false);
  }
  const summary = 'Imported ' + result.imported + ' reading(s)' +
    (result.created_meters ? ', created ' + result.created_meters + ' meter(s)' : '') +
    (result.errors.length ? '. Skipped ' + result.errors.length + ' row(s).' : '.');
  note('import-note', summary, !result.errors.length);
  load().catch(showFailure);
});

function showFailure(error) {
  $('loading').hidden = false;
  $('loading').textContent = 'Could not reach the tracker API: ' + error.message;
}

$('reading-period').value = new Date().toISOString().slice(0, 7);
load().catch(showFailure);
