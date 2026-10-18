/*
 * 시스템 설정 표 — 검색, 필터 칩, 열 정렬 (화면 안에서만 처리).
 *
 * 설정은 한 화면에 다 실려 있어 서버를 거칠 이유가 없다.
 * 저장 뒤 행이 바뀌면 settings-panel.js 가 window.elumSettingsTable.refresh() 로 다시 거른다.
 */
(function () {
  'use strict';

  var SORT_MARK = { asc: '▲', desc: '▼' };
  // 정렬 열 키 > 행의 data 속성 (행 조각 settings-parts :: row 와 짝)
  var SORT_ATTRIBUTE = {
    name: 'data-sort-name',
    current: 'data-sort-current',
    default: 'data-sort-default',
    changed: 'data-sort-changed',
  };

  function ready(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  ready(function () {
    var table = document.querySelector('[data-settings-table]');
    var search = document.querySelector('[data-settings-search]');
    if (!table || !search) return; // 설정 화면이 아니다

    var tbody = table.querySelector('tbody');
    var emptyRow = tbody.querySelector('[data-empty-row]');
    var counter = document.querySelector('[data-settings-count]');
    var chip = 'all';
    // 처음엔 서버가 준 순서(최근 변경순)
    var sort = { key: 'changed', direction: 'desc' };

    function rowsOf() {
      return Array.prototype.slice.call(tbody.querySelectorAll('[data-config-row]'));
    }

    function matchesChip(row) {
      if (chip === 'all') return true;
      if (chip === 'different') return row.getAttribute('data-different') === 'true';
      if (chip === 'today') return row.getAttribute('data-today') === 'true';
      return chip.indexOf('group:') === 0 && row.getAttribute('data-group') === chip.substring('group:'.length);
    }

    function applyFilter() {
      var keyword = (search.value || '').trim().toLowerCase();
      var shown = 0;
      rowsOf().forEach(function (row) {
        var isMatch = (!keyword || (row.getAttribute('data-search') || '').indexOf(keyword) >= 0) && matchesChip(row);
        row.classList.toggle('hidden', !isMatch);
        if (isMatch) shown++;
      });
      if (emptyRow) emptyRow.classList.toggle('hidden', shown > 0);
      if (counter) counter.textContent = shown + '개 보이는 중';
    }

    function compareRows(a, b) {
      var attribute = SORT_ATTRIBUTE[sort.key];
      var left = a.getAttribute(attribute) || '';
      var right = b.getAttribute(attribute) || '';
      // 마지막 변경이 없는 행은 어느 방향이든 맨 뒤
      if (sort.key === 'changed' && (!left || !right)) {
        if (!left && !right) return 0;
        return !left ? 1 : -1;
      }
      var order = left < right ? -1 : left > right ? 1 : 0;
      return sort.direction === 'asc' ? order : -order;
    }

    function applySort() {
      rowsOf().sort(compareRows).forEach(function (row) {
        tbody.insertBefore(row, emptyRow); // 안내 줄은 항상 맨 아래
      });
      table.querySelectorAll('[data-sort-by]').forEach(function (button) {
        var mark = button.querySelector('[data-sort-mark]');
        if (mark) mark.textContent = button.getAttribute('data-sort-by') === sort.key ? SORT_MARK[sort.direction] : '';
      });
    }

    function refresh() {
      applySort();
      applyFilter();
    }

    function selectChip(value) {
      chip = value;
      document.querySelectorAll('[data-chip]').forEach(function (button) {
        var isOn = button.getAttribute('data-chip') === value;
        button.classList.toggle('btn-primary', isOn);
        button.classList.toggle('btn-ghost', !isOn);
      });
      applyFilter();
    }

    search.addEventListener('input', applyFilter);
    document.querySelectorAll('[data-chip]').forEach(function (button) {
      button.addEventListener('click', function () { selectChip(button.getAttribute('data-chip')); });
    });
    // 요약의 "기본값과 다른 설정 N개 보기" 는 요약이 다시 그려져도 동작해야 해서 문서에서 받는다
    document.addEventListener('click', function (event) {
      var shortcut = event.target.closest('[data-chip-shortcut]');
      if (!shortcut) return;
      selectChip(shortcut.getAttribute('data-chip-shortcut'));
      // 표가 카드보다 넓어 표를 맞추면 화면이 가로로 밀림 > 카드 기준
      (table.closest('.card') || table).scrollIntoView({ behavior: 'smooth', block: 'start', inline: 'nearest' });
    });
    table.querySelectorAll('[data-sort-by]').forEach(function (button) {
      button.addEventListener('click', function () {
        var key = button.getAttribute('data-sort-by');
        // 같은 열이면 방향 뒤집기, 다른 열이면 이름·값은 오름차순, 변경 시각은 최신부터
        sort = sort.key === key
          ? { key: key, direction: sort.direction === 'asc' ? 'desc' : 'asc' }
          : { key: key, direction: key === 'changed' ? 'desc' : 'asc' };
        refresh();
      });
    });

    window.elumSettingsTable = { refresh: refresh };
    refresh();
  });
})();
