/**
 * Chart.js rendereri za Kadrovska — Pregled (mini izveštaji).
 */

import Chart from 'chart.js/auto';
import { KADR_ABS_TYPE_LABELS } from '../../lib/constants.js';

const SERVOTEH_PALETTE = [
  '#2563eb',
  '#16a34a',
  '#dc2626',
  '#ca8a04',
  '#7c3aed',
  '#0891b2',
  '#db2777',
  '#65a30d',
];

const chartInstances = new WeakMap();

export function destroyChart(canvasEl) {
  if (!canvasEl) return;
  const c = chartInstances.get(canvasEl);
  if (c) {
    c.destroy();
    chartInstances.delete(canvasEl);
  }
}

export function trackChart(canvasEl, chart) {
  if (canvasEl && chart) chartInstances.set(canvasEl, chart);
}

/** Pre innerHTML remount-a ili na osvežavanju — sve canvas instance unutar root-a. */
export function destroyMiniReportCharts(rootEl) {
  if (!rootEl) return;
  rootEl.querySelectorAll('#chartEmployeesByDept, #chartHoursPerDay, #chartAbsencesByType').forEach(c => {
    destroyChart(c);
  });
}

function dayKeyLocal(isoDate) {
  return `${isoDate}T12:00:00`;
}

/**
 * @param {HTMLCanvasElement} canvasEl
 * @param {Array<{ department: string, count: number }>} data
 */
export function renderEmployeesByDepartmentChart(canvasEl, data) {
  destroyChart(canvasEl);
  const top = data.slice(0, 7);
  const restCount = data.slice(7).reduce((sum, d) => sum + (Number(d.count) || 0), 0);
  const labels = top.map(d => d.department);
  const values = top.map(d => Number(d.count) || 0);
  if (restCount > 0) {
    labels.push('Ostalo');
    values.push(restCount);
  }

  const chart = new Chart(canvasEl, {
    type: 'doughnut',
    data: {
      labels,
      datasets: [{ data: values, backgroundColor: SERVOTEH_PALETTE }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'right', labels: { boxWidth: 12 } },
        title: { display: true, text: 'Zaposleni po odeljenjima' },
      },
    },
  });
  trackChart(canvasEl, chart);
  return chart;
}

/**
 * @param {HTMLCanvasElement} canvasEl
 * @param {Array<{ date: string, hours: string|number }>} data
 */
export function renderHoursPerDayChart(canvasEl, data) {
  destroyChart(canvasEl);
  const labels = data.map(d => String(new Date(dayKeyLocal(d.date)).getDate()));
  const values = data.map(d => Number(d.hours));
  const pointColors = data.map(d => {
    const dow = new Date(dayKeyLocal(d.date)).getDay();
    return dow === 0 || dow === 6 ? '#cbd5e1' : '#2563eb';
  });

  const chart = new Chart(canvasEl, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: 'Sati',
          data: values,
          borderColor: '#2563eb',
          backgroundColor: 'rgba(37, 99, 235, 0.1)',
          pointBackgroundColor: pointColors,
          tension: 0.2,
          fill: true,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        title: { display: true, text: 'Sati po danu (tekući mesec)' },
      },
      scales: {
        y: { beginAtZero: true, title: { display: true, text: 'Sati' } },
        x: { title: { display: true, text: 'Dan u mesecu' } },
      },
    },
  });
  trackChart(canvasEl, chart);
  return chart;
}

/**
 * @param {HTMLCanvasElement} canvasEl
 * @param {Array<{ type: string, days: number }>} data
 */
export function renderAbsencesByTypeChart(canvasEl, data) {
  destroyChart(canvasEl);
  const labels = data.map(d => KADR_ABS_TYPE_LABELS[d.type] ?? d.type);
  const values = data.map(d => Number(d.days) || 0);

  const chart = new Chart(canvasEl, {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          data: values,
          backgroundColor: SERVOTEH_PALETTE,
        },
      ],
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        title: { display: true, text: 'Odsustva po tipu (tekući mesec)' },
      },
      scales: {
        x: { beginAtZero: true, title: { display: true, text: 'Dani' } },
      },
    },
  });
  trackChart(canvasEl, chart);
  return chart;
}
