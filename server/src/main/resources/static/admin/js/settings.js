/*
 * 시스템 설정 화면 — 찾기와 저장 (이슈 #248).
 *
 * 설정이 서른 개가 넘는다. 점검 모드·강제 업데이트 키가 더 붙을 예정이라
 * 평면 목록으로는 원하는 것을 찾을 수 없다. 거르는 일은 **서버를 거치지 않는다** —
 * 값이 이미 화면에 다 있어서 왕복할 이유가 없다.
 *
 * 저장도 페이지를 다시 그리지 않는다. 화면이 길어 리로드하면 스크롤이 맨 위로 튀고,
 * 고치던 자리를 다시 찾아 내려가야 한다.
 */
(function () {
  'use strict';

  function ready(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  ready(function () {
    var search = document.querySelector('[data-settings-search]');
    if (!search) return; // 설정 화면이 아니다

    var changedOnly = document.querySelector('[data-changed-only]');
    var counter = document.querySelector('[data-settings-count]');
    var toast = document.querySelector('[data-settings-toast]');
    var group = '';

    function applyFilter() {
      var q = (search.value || '').trim().toLowerCase();
      var onlyChanged = changedOnly && changedOnly.checked;
      var shown = 0;

      document.querySelectorAll('[data-group-card]').forEach(function (card) {
        var visibleRows = 0;
        card.querySelectorAll('[data-config-row]').forEach(function (row) {
          var hit = !q || (row.getAttribute('data-search') || '').indexOf(q) >= 0;
          if (onlyChanged && row.getAttribute('data-changed') !== 'true') hit = false;
          if (group && card.getAttribute('data-group-card') !== group) hit = false;
          row.classList.toggle('hidden', !hit);
          if (hit) visibleRows++;
        });
        // 안에 보이는 것이 하나도 없으면 그룹 카드째 숨긴다 — 빈 카드만 남으면 더 헷갈린다
        card.classList.toggle('hidden', visibleRows === 0);
        shown += visibleRows;
      });

      if (counter) counter.textContent = shown + '개 보이는 중';
    }

    search.addEventListener('input', applyFilter);
    if (changedOnly) changedOnly.addEventListener('change', applyFilter);

    document.querySelectorAll('[data-group-tab]').forEach(function (tab) {
      tab.addEventListener('click', function () {
        group = tab.getAttribute('data-group-tab') || '';
        document.querySelectorAll('[data-group-tab]').forEach(function (t) {
          var on = t === tab;
          t.classList.toggle('btn-primary', on);
          t.classList.toggle('btn-ghost', !on);
        });
        applyFilter();
      });
    });

    applyFilter();

    // --- 리로드 없는 저장 ---
    function showToast(ok, message) {
      if (!toast) return;
      toast.textContent = message;
      toast.classList.remove('hidden', 'alert-success', 'alert-error');
      toast.classList.add(ok ? 'alert-success' : 'alert-error');
    }

    document.querySelectorAll('form[data-async-save]').forEach(function (form) {
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        var button = form.querySelector('button[type=submit]');
        if (button) button.disabled = true; // 두 번 눌러 두 번 보내는 것을 막는다

        fetch(form.action, {
          method: 'POST',
          headers: { 'X-Requested-With': 'fetch' },
          body: new FormData(form),
        })
          .then(function (res) { return res.json(); })
          .then(function (data) {
            showToast(data.ok, data.message);
            // 성공하면 "변경됨" 배지가 붙어야 하는데, 배지는 서버가 그린다.
            // 값만 바뀐 것을 표시해 두고 다음 새로고침에 정식으로 반영한다.
            if (data.ok) {
              var row = form.closest('[data-config-row]');
              if (row) row.setAttribute('data-changed', 'true');
            }
          })
          .catch(function () {
            // 네트워크가 끊겼거나 서버가 죽었다. 무엇이 문제인지 말해 준다.
            showToast(false, '저장하지 못했어요. 연결을 확인해주세요 (E-CFG-NET)');
          })
          .then(function () {
            if (button) button.disabled = false;
          });
      });
    });
  });
})();
