/*
 * 시스템 설정 수정 패널 — 행을 누르면 열려 값을 고치고, 그 키의 변경 이력을 본다.
 *
 * 저장은 페이지를 다시 그리지 않는다(스크롤이 맨 위로 튀지 않게).
 * 성공하면 설정 화면을 한 번 더 받아 요약과 그 행만 갈아 끼운다 — 화면을 그리는 곳은 서버 한 곳이다.
 */
(function () {
  'use strict';

  var TOAST_VISIBLE_MILLISECONDS = 3500;
  var NETWORK_ERROR_MESSAGE = '저장하지 못했어요. 연결을 확인해주세요 (E-CFG-NET)';
  var HISTORY_ERROR_MESSAGE = '이력을 불러오지 못했어요 (E-CFG-HIS)';

  function ready(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  function element(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  // 날짜시간 설정값(2026-10-19, 2026-10-19 00:00, 2026-10-19T00:00) > 날짜 선택기 값(yyyy-MM-ddTHH:mm)
  function toDatetimeLocal(raw) {
    var value = (raw || '').trim().replace(' ', 'T');
    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value + 'T00:00';
    return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value) ? value.substring(0, 16) : '';
  }

  function csrfHeaders() {
    var token = document.querySelector('meta[name=_csrf]');
    var header = document.querySelector('meta[name=_csrf_header]');
    var headers = { 'X-Requested-With': 'fetch' };
    if (token && header) headers[header.content] = token.content;
    return headers;
  }

  ready(function () {
    var panel = document.querySelector('[data-settings-panel]');
    var backdrop = document.querySelector('[data-settings-backdrop]');
    var toast = document.querySelector('[data-settings-toast]');
    var tbody = document.querySelector('[data-settings-table] tbody');
    if (!panel || !tbody) return; // 설정 화면이 아니다

    var form = panel.querySelector('[data-panel-form]');
    var widget = panel.querySelector('[data-panel-widget]');
    var historyBox = panel.querySelector('[data-panel-history]');
    var hintText = panel.querySelector('[data-panel-hint]');
    var errorText = panel.querySelector('[data-panel-error]');
    var warningBox = panel.querySelector('[data-panel-warning]');
    var sourceBox = panel.querySelector('[data-panel-source]');
    var reasonInput = form.querySelector('input[name=reason]');
    var saveButton = form.querySelector('button[type=submit]');
    var openKey = null;
    var toastTimer = null;

    function rowOfKey(key) {
      return tbody.querySelector('[data-config-row][data-key="' + key + '"]');
    }

    // --- 값 종류별 입력 위젯 ---
    function buildWidget(row) {
      var type = row.getAttribute('data-type');
      var current = row.getAttribute('data-current') || '';
      widget.textContent = '';
      var input;
      // 회원 ID 목록: 검색해서 고르는 위젯 (스크립트가 없으면 아래 글 입력으로)
      if (row.getAttribute('data-format') === 'MEMBER_ID_LIST' && window.elumSettingsMemberPicker) {
        window.elumSettingsMemberPicker.build(widget, current);
        return;
      }
      if (type === 'BOOLEAN') {
        // 토글: 체크 상태를 숨은 값(true/false)으로 보냄
        var hidden = element('input');
        hidden.type = 'hidden';
        hidden.name = 'value';
        hidden.value = current === 'true' ? 'true' : 'false';
        var label = element('label', 'flex cursor-pointer items-center gap-3');
        var toggle = element('input', 'toggle toggle-primary');
        toggle.type = 'checkbox';
        toggle.checked = hidden.value === 'true';
        var stateText = element('span', 'text-sm', toggle.checked ? '켜짐' : '꺼짐');
        toggle.addEventListener('change', function () {
          hidden.value = toggle.checked ? 'true' : 'false';
          stateText.textContent = toggle.checked ? '켜짐' : '꺼짐';
        });
        label.appendChild(toggle);
        label.appendChild(stateText);
        widget.appendChild(hidden);
        widget.appendChild(label);
        return;
      }
      if (type === 'SELECT') {
        input = element('select', 'select select-bordered select-sm w-full');
        (row.getAttribute('data-allowed') || '').split('|').forEach(function (allowed) {
          var option = element('option', '', allowed);
          option.value = allowed;
          option.selected = allowed === current;
          input.appendChild(option);
        });
      } else if (type === 'DATETIME') {
        // 날짜 선택기. 비우고 저장하면 비어 있는 값(= 꺼짐)
        input = element('input', 'input input-bordered input-sm w-full');
        input.type = 'datetime-local';
        input.value = toDatetimeLocal(current);
      } else if (type === 'SECRET') {
        // 비밀값은 값을 내려주지 않는다. 비우고 저장하면 그대로 둔다
        input = element('input', 'input input-bordered input-sm w-full');
        input.type = 'password';
        input.autocomplete = 'off';
        input.placeholder = row.getAttribute('data-secret') === 'true' && current === ''
          ? '바꾸려면 새 값 입력 (저장한 값은 다시 볼 수 없어요)' : '값을 입력하세요';
      } else if (type === 'INTEGER') {
        input = element('input', 'input input-bordered input-sm w-full');
        input.type = 'number';
        input.step = '1';
        input.value = current;
        if (row.getAttribute('data-min') !== null) input.min = row.getAttribute('data-min');
        if (row.getAttribute('data-max') !== null) input.max = row.getAttribute('data-max');
      } else {
        input = element('input', 'input input-bordered input-sm w-full');
        input.type = 'text';
        input.value = current;
      }
      input.name = 'value';
      widget.appendChild(input);
    }

    // --- 키별 변경 이력 ---
    function renderHistory(entries) {
      historyBox.textContent = '';
      if (!entries.length) {
        historyBox.appendChild(element('p', 'text-base-content/50', '아직 바꾼 기록이 없어요.'));
        return;
      }
      entries.forEach(function (entry) {
        var item = element('div', 'rounded-box border border-base-300 p-2');
        item.appendChild(element('div', 'text-xs text-base-content/60',
          entry.at + (entry.by ? ' · ' + entry.by : '')));
        item.appendChild(element('div', 'break-all',
          (entry.oldValue || '(없음)') + ' → ' + (entry.newValue || '(없음)')));
        if (entry.reason) item.appendChild(element('div', 'text-xs text-base-content/60', entry.reason));
        historyBox.appendChild(item);
      });
    }

    function loadHistory(key) {
      historyBox.textContent = '불러오는 중…';
      fetch('/admin/settings/' + encodeURIComponent(key) + '/history', { headers: { Accept: 'application/json' } })
        .then(function (response) {
          if (!response.ok) throw new Error('HTTP ' + response.status);
          return response.json();
        })
        .then(function (entries) {
          if (openKey === key) renderHistory(entries);
        })
        .catch(function () {
          historyBox.textContent = '';
          var retry = element('button', 'btn btn-ghost btn-xs', '다시 시도');
          retry.type = 'button';
          retry.addEventListener('click', function () { loadHistory(key); });
          historyBox.appendChild(element('p', 'text-error', HISTORY_ERROR_MESSAGE));
          historyBox.appendChild(retry);
        });
    }

    // --- 안내·경고·저장 실패 이유 ---
    // 입력 안내: 정수는 허용 범위, 문자열은 형식
    function hintOf(row) {
      var min = row.getAttribute('data-min');
      var max = row.getAttribute('data-max');
      if (row.getAttribute('data-type') === 'INTEGER' && (min !== null || max !== null)) {
        return '허용 범위 ' + (min !== null ? min : '') + ' ~ ' + (max !== null ? max : '');
      }
      var formatHint = row.getAttribute('data-format-hint');
      return formatHint ? '형식: ' + formatHint : '';
    }

    function showError(message) {
      errorText.textContent = message || '';
      errorText.classList.toggle('hidden', !message);
    }

    // yml 에 묶인 모델명 키만: 실제 적용 값과 출처 (DB 값이 있으면 yml 값은 쓰지 않음)
    function fillSource(row) {
      var deployValue = row.getAttribute('data-deploy-value');
      sourceBox.textContent = '';
      sourceBox.classList.toggle('hidden', deployValue === null);
      if (deployValue === null) return;
      sourceBox.appendChild(element('div', 'font-medium',
        '실제 적용 값: ' + (row.getAttribute('data-current') || '-') + ' · 출처: ' + row.getAttribute('data-source')));
      sourceBox.appendChild(element('div', 'text-base-content/60',
        '배포 설정(yml) 값: ' + deployValue + ' — DB 에 값이 있으면 yml 값은 쓰지 않아요. '
        + '기본값으로 복원하면 지금 yml 값을 저장해요.'));
    }

    // --- 열기·닫기 ---
    function fillPanel(row) {
      panel.querySelector('[data-panel-label]').textContent = row.getAttribute('data-label');
      panel.querySelector('[data-panel-key]').textContent = row.getAttribute('data-key');
      panel.querySelector('[data-panel-description]').textContent = row.getAttribute('data-description');
      panel.querySelector('[data-panel-default]').textContent = row.getAttribute('data-secret') === 'true'
        ? '' : '기본값: ' + (row.getAttribute('data-default-display') || '-');
      // 비밀값의 기본값 복원은 "지우기"
      panel.querySelector('[data-panel-reset]').textContent =
        row.getAttribute('data-secret') === 'true' ? '저장한 값 지우기' : '기본값으로 복원';
      buildWidget(row);
      hintText.textContent = hintOf(row);
      var warning = row.getAttribute('data-warning') === 'true' ? row.getAttribute('data-warning-text') : '';
      warningBox.textContent = warning ? '지금 저장된 값이 규칙에 어긋나요: ' + warning + '. 고쳐서 다시 저장해 주세요.' : '';
      warningBox.classList.toggle('hidden', !warning);
      fillSource(row);
      showError('');
    }

    function openPanel(key) {
      var row = rowOfKey(key);
      if (!row) return;
      openKey = key;
      reasonInput.value = '';
      fillPanel(row);
      panel.classList.remove('hidden');
      backdrop.classList.remove('hidden');
      panel.setAttribute('aria-hidden', 'false');
      loadHistory(key);
    }

    function closePanel() {
      openKey = null;
      panel.classList.add('hidden');
      backdrop.classList.add('hidden');
      panel.setAttribute('aria-hidden', 'true');
    }

    tbody.addEventListener('click', function (event) {
      if (event.target.closest('a, button')) return;
      var row = event.target.closest('[data-config-row]');
      if (row) openPanel(row.getAttribute('data-key'));
    });
    // 요약·Free/Pro 비교의 값을 누르면 그 설정의 패널
    document.addEventListener('click', function (event) {
      var opener = event.target.closest('[data-open-key]');
      if (opener) openPanel(opener.getAttribute('data-open-key'));
    });
    backdrop.addEventListener('click', closePanel);
    panel.querySelector('[data-panel-close]').addEventListener('click', closePanel);
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && openKey) closePanel();
    });

    // --- 토스트: 방금 고친 행 바로 아래 (행이 안 보이면 화면 아래) ---
    function showToast(isOk, message, anchor) {
      toast.textContent = message;
      toast.classList.remove('hidden', 'alert-success', 'alert-error');
      toast.classList.add(isOk ? 'alert-success' : 'alert-error');
      var rect = anchor ? anchor.getBoundingClientRect() : null;
      var isRowVisible = rect && rect.bottom > 0 && rect.top < window.innerHeight;
      if (isRowVisible && window.innerWidth >= 768) {
        toast.style.top = Math.min(rect.bottom + 4, window.innerHeight - 64) + 'px';
        toast.style.bottom = 'auto';
        toast.style.left = Math.max(rect.left + 16, 16) + 'px';
      } else {
        toast.style.top = 'auto';
        toast.style.bottom = '16px';
        toast.style.left = '16px';
      }
      clearTimeout(toastTimer);
      toastTimer = setTimeout(function () { toast.classList.add('hidden'); }, TOAST_VISIBLE_MILLISECONDS);
    }

    // --- 저장 후 서버가 그린 요약·행으로 교체 ---
    function refreshFromServer(key) {
      return fetch('/admin/settings', { headers: { Accept: 'text/html' } })
        .then(function (response) {
          if (!response.ok) throw new Error('HTTP ' + response.status);
          return response.text();
        })
        .then(function (html) {
          var fresh = new DOMParser().parseFromString(html, 'text/html');
          var freshRow = fresh.querySelector('[data-config-row][data-key="' + key + '"]');
          var currentRow = rowOfKey(key);
          if (freshRow && currentRow) currentRow.replaceWith(freshRow);
          var freshSummary = fresh.querySelector('[data-settings-summary]');
          var currentSummary = document.querySelector('[data-settings-summary]');
          if (freshSummary && currentSummary) currentSummary.replaceWith(freshSummary);
          if (window.elumSettingsTable) window.elumSettingsTable.refresh();
        });
    }

    // 값을 고치기 시작하면 지난 저장 실패 이유는 지움
    form.addEventListener('input', function () { showError(''); });

    form.addEventListener('submit', function (event) {
      event.preventDefault();
      if (!openKey) return;
      var key = openKey;
      saveButton.disabled = true; // 두 번 눌러 두 번 보내는 것을 막는다
      fetch('/admin/settings/' + encodeURIComponent(key), {
        method: 'POST', headers: csrfHeaders(), body: new FormData(form),
      })
        .then(function (response) { return response.json(); })
        .then(function (result) {
          if (!result.ok) {
            // 입력칸 옆에 이유 (입력값은 그대로 두고 고쳐서 다시 저장)
            showError(result.reason || result.message);
            showToast(false, result.message, panel);
            return null;
          }
          // 행을 먼저 갈아 끼우고, 토스트는 갈아 낀 행 근처에
          return refreshFromServer(key).then(function () {
            showToast(true, result.message, rowOfKey(key));
            if (openKey === key) {
              reasonInput.value = '';
              fillPanel(rowOfKey(key));
              loadHistory(key);
            }
          });
        })
        .catch(function () { showToast(false, NETWORK_ERROR_MESSAGE, panel); })
        .then(function () { saveButton.disabled = false; });
    });

    // 기본값 복원: 서버가 처리한 뒤 화면을 다시 받는다(메시지는 상단에)
    panel.querySelector('[data-panel-reset]').addEventListener('click', function () {
      if (!openKey) return;
      var resetKey = openKey;
      var isSecret = rowOfKey(resetKey).getAttribute('data-secret') === 'true';
      window.ElumAdminConfirm.ask(isSecret
        ? {title: '저장된 값 지우기', message: '저장된 값을 지울까요? 이 키를 쓰는 기능이 꺼져요.', isDanger: true, acceptLabel: '지우기'}
        : {title: '기본값으로 복원', message: '기본값으로 복원할까요?'})
        .then(function (isConfirmed) {
          if (isConfirmed) submitReset(resetKey);
        });
    });

    // 기본값 복원 제출 (사유는 입력 칸 값, 비면 빈 값)
    function submitReset(resetKey) {
      var resetForm = element('form');
      resetForm.method = 'post';
      resetForm.action = '/admin/settings/' + encodeURIComponent(resetKey) + '/reset';
      var reason = element('input');
      reason.type = 'hidden';
      reason.name = 'reason';
      reason.value = reasonInput.value || '';
      resetForm.appendChild(reason);
      document.body.appendChild(resetForm);
      resetForm.submit();
    }

  });
})();
