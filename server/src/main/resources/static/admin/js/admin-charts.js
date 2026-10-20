/*
 * 관리자 추이 그래프 공통: [data-trend-chart] 카드마다 JSON 조회 > chart.js 그리기 > 표로 보기
 *
 * 카드 속성
 *   data-endpoint   /admin/stats/api/... (unit·from·to·days·metric 을 붙여 부른다)
 *   data-type       bar(기본) · stacked · line
 *   data-unit       day(기본) · month       — [data-trend-unit] 버튼이 바꾼다
 *   data-days       일별 기본 일수
 *   data-metric     count · cost · failure  — [data-trend-metric] 선택이 바꾼다
 *   data-click-link 막대 클릭 시 이동 주소. {from} {to} 를 칸 첫날·끝날로 바꾼다
 * 카드 안 요소: canvas[data-trend-canvas], [data-trend-status], [data-trend-table], input[data-trend-from|to]
 *
 * 실패 시 그래프 자리에 문구 + 에러 코드 + 다시 시도 (E-ADMIN-STATS 조회 실패, E-ADMIN-CHART 차트 파일 없음)
 * 색: 줄 key 마다 고정 (엔티티 기준, 순위·개수로 다시 칠하지 않음). 라이트·다크 각각 검증한 값
 */
(function () {
  'use strict';

  // 줄 key > 색 [라이트, 다크] (참조 팔레트 1~6번 순서, 인접 쌍 색각 검증 통과)
  var SERIES_COLORS = {
    joined: ['#2a78d6', '#3987e5'],
    withdrawn: ['#eb6834', '#d95926'],
    visits: ['#2a78d6', '#3987e5'],
    ROUTINE_CREATE: ['#2a78d6', '#3987e5'],
    ROUTINE_QUESTION: ['#eb6834', '#d95926'],
    CARD_IMAGE: ['#1baf7a', '#199e70'],
    SENSITIVE_INFO_CHECK: ['#eda100', '#c98500'],
    IMAGE_PROMPT_TRANSLATE: ['#e87ba4', '#d55181'],
    PICTOGRAM_PICK: ['#008300', '#008300']
  };
  var FALLBACK_COLOR = ['#898781', '#898781'];
  // 축·격자 잉크 [라이트, 다크]
  var INK = {
    muted: ['#898781', '#898781'],
    grid: ['#e1e0d9', '#2c2c2a'],
    text: ['#52514e', '#c3c2b7']
  };
  var METRIC_SUFFIX = { count: '건', cost: '원', failure: '%' };
  var ERROR_FETCH = 'E-ADMIN-STATS';
  var ERROR_CHART_LIBRARY = 'E-ADMIN-CHART';

  function isDarkTheme() {
    return document.documentElement.getAttribute('data-theme') === 'dark';
  }

  function pick(pair) {
    return pair[isDarkTheme() ? 1 : 0];
  }

  function colorOf(key) {
    return pick(SERIES_COLORS[key] || FALLBACK_COLOR);
  }

  function formatNumber(value) {
    return value == null ? '-' : Number(value).toLocaleString('ko-KR');
  }

  // 칸 첫날 > 칸 끝날 (월별이면 그달 마지막 날)
  function bucketEndOf(bucketStart, unit) {
    if (unit !== 'month') {
      return bucketStart;
    }
    var parts = bucketStart.split('-');
    var lastDay = new Date(Number(parts[0]), Number(parts[1]), 0).getDate();
    return parts[0] + '-' + parts[1] + '-' + String(lastDay).padStart(2, '0');
  }

  function requestUrlOf(card) {
    var params = new URLSearchParams();
    params.set('unit', card.dataset.unit || 'day');
    if (card.dataset.days) params.set('days', card.dataset.days);
    if (card.dataset.metric) params.set('metric', card.dataset.metric);
    var fromInput = card.querySelector('[data-trend-from]');
    var toInput = card.querySelector('[data-trend-to]');
    if (fromInput && fromInput.value) params.set('from', fromInput.value);
    if (toInput && toInput.value) params.set('to', toInput.value);
    return card.dataset.endpoint + '?' + params.toString();
  }

  function showStatus(card, message, errorCode) {
    var status = card.querySelector('[data-trend-status]');
    if (!status) return;
    status.textContent = '';
    if (!message) {
      status.classList.add('hidden');
      return;
    }
    status.classList.remove('hidden');
    var text = document.createElement('span');
    text.textContent = message + (errorCode ? ' (' + errorCode + ')' : '');
    status.appendChild(text);
    if (errorCode) {
      var retry = document.createElement('button');
      retry.type = 'button';
      retry.className = 'btn btn-xs btn-outline ml-2';
      retry.textContent = '다시 시도';
      retry.addEventListener('click', function () { load(card); });
      status.appendChild(retry);
    }
  }

  function datasetsOf(card, chartData) {
    var type = card.dataset.type || 'bar';
    return chartData.series.map(function (series) {
      var color = colorOf(series.key);
      var isLine = type === 'line' || card.dataset.metric === 'failure';
      return {
        type: isLine ? 'line' : 'bar',
        label: series.label,
        data: series.values,
        backgroundColor: isLine ? color + '33' : color,
        borderColor: color,
        borderWidth: isLine ? 2 : 0,
        borderRadius: isLine ? 0 : 4,
        borderSkipped: 'start',
        maxBarThickness: 28,
        pointRadius: 0,
        pointHoverRadius: 4,
        fill: isLine && chartData.series.length === 1,
        tension: 0.3,
        spanGaps: false
      };
    });
  }

  function optionsOf(card, chartData) {
    var isStacked = card.dataset.type === 'stacked' && card.dataset.metric !== 'failure';
    var suffix = METRIC_SUFFIX[card.dataset.metric] || '';
    var muted = pick(INK.muted);
    return {
      maintainAspectRatio: false,
      animation: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        // 줄이 하나면 제목이 이름을 대신한다
        legend: { display: chartData.series.length > 1, labels: { color: pick(INK.text), boxWidth: 12 } },
        tooltip: {
          callbacks: {
            label: function (context) {
              return context.dataset.label + ': ' + formatNumber(context.parsed.y) + (context.parsed.y == null ? '' : suffix);
            }
          }
        }
      },
      scales: {
        x: { stacked: isStacked, grid: { display: false }, ticks: { color: muted, maxRotation: 0, autoSkipPadding: 12 } },
        y: { stacked: isStacked, beginAtZero: true, grid: { color: pick(INK.grid) }, ticks: { color: muted, precision: 0 } }
      },
      onClick: function (event, elements) {
        if (!card.dataset.clickLink || !elements.length) return;
        var bucketStart = chartData.bucketStarts[elements[0].index];
        window.location.href = card.dataset.clickLink
          .replace('{from}', bucketStart)
          .replace('{to}', bucketEndOf(bucketStart, chartData.unit));
      }
    };
  }

  // 표로 보기: 색 없이도 값을 읽을 수 있게 (대비가 낮은 색의 보완)
  function renderTable(card, chartData) {
    var holder = card.querySelector('[data-trend-table]');
    if (!holder) return;
    var table = document.createElement('table');
    table.className = 'table table-xs';
    var headRow = document.createElement('tr');
    ['기간'].concat(chartData.series.map(function (series) { return series.label; })).forEach(function (title) {
      var cell = document.createElement('th');
      cell.textContent = title;
      headRow.appendChild(cell);
    });
    var head = document.createElement('thead');
    head.appendChild(headRow);
    var body = document.createElement('tbody');
    chartData.labels.forEach(function (label, index) {
      var row = document.createElement('tr');
      var labelCell = document.createElement('td');
      labelCell.textContent = label;
      row.appendChild(labelCell);
      chartData.series.forEach(function (series) {
        var cell = document.createElement('td');
        cell.textContent = formatNumber(series.values[index]);
        row.appendChild(cell);
      });
      body.appendChild(row);
    });
    table.appendChild(head);
    table.appendChild(body);
    holder.textContent = '';
    holder.appendChild(table);
  }

  function draw(card, chartData) {
    var canvas = card.querySelector('[data-trend-canvas]');
    if (card.trendChart) {
      card.trendChart.destroy();
    }
    card.trendChart = new window.Chart(canvas, {
      data: { labels: chartData.labels, datasets: datasetsOf(card, chartData) },
      options: optionsOf(card, chartData)
    });
    renderTable(card, chartData);
  }

  function load(card) {
    if (!window.Chart) {
      showStatus(card, '그래프를 그리지 못했어요', ERROR_CHART_LIBRARY);
      return;
    }
    showStatus(card, '불러오는 중…');
    fetch(requestUrlOf(card), { headers: { Accept: 'application/json' } })
      .then(function (response) {
        var type = response.headers.get('content-type') || '';
        if (!response.ok || response.redirected || type.indexOf('application/json') < 0) {
          throw new Error('HTTP ' + response.status);
        }
        return response.json();
      })
      .then(function (chartData) {
        if (!chartData || !Array.isArray(chartData.labels) || !Array.isArray(chartData.series)) {
          throw new Error('unexpected response');
        }
        card.trendData = chartData;
        if (!chartData.series.length) {
          showStatus(card, '이 기간에는 기록이 없어요');
        } else {
          showStatus(card, null);
        }
        draw(card, chartData);
      })
      .catch(function (error) {
        console.warn('[관리자] 추이 그래프를 불러오지 못했어요', card.dataset.endpoint, error);
        showStatus(card, '그래프를 불러오지 못했어요', ERROR_FETCH);
      });
  }

  function bindControls(card) {
    card.querySelectorAll('[data-trend-unit]').forEach(function (button) {
      button.addEventListener('click', function () {
        card.dataset.unit = button.dataset.trendUnit;
        card.querySelectorAll('[data-trend-unit]').forEach(function (other) {
          other.classList.toggle('btn-active', other === button);
        });
        // 단위가 바뀌면 기간 입력은 기본값으로 (일별 90일 <-> 월별 12달)
        card.querySelectorAll('[data-trend-from], [data-trend-to]').forEach(function (input) { input.value = ''; });
        load(card);
      });
    });
    card.querySelectorAll('[data-trend-metric]').forEach(function (select) {
      select.addEventListener('change', function () {
        card.dataset.metric = select.value;
        load(card);
      });
    });
    card.querySelectorAll('[data-trend-from], [data-trend-to]').forEach(function (input) {
      input.addEventListener('change', function () { load(card); });
    });
  }

  function init() {
    var cards = document.querySelectorAll('[data-trend-chart]');
    cards.forEach(function (card) {
      bindControls(card);
      load(card);
    });
    // 테마 전환 시 다크 색으로 다시 그림 (조회는 다시 하지 않음)
    new MutationObserver(function () {
      cards.forEach(function (card) {
        if (card.trendData && window.Chart) draw(card, card.trendData);
      });
    }).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
