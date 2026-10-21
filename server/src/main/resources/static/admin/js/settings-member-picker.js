/*
 * 설정 회원 고르기 위젯 — 회원 ID 쉼표 목록 설정(광고 항상 노출 회원)을 검색 > 선택 > 칩으로 다룬다.
 * 보내는 값은 숨은 입력 하나(쉼표 목록). 칩 이름은 서버에서 받아 붙이고, 없는 ID 는 빨간 칩으로 남겨 빼게 한다.
 * settings-panel.js 가 data-format="MEMBER_ID_LIST" 행을 열 때 window.elumSettingsMemberPicker.build 로 부른다.
 */
(function () {
  'use strict';

  var SEARCH_DELAY_MILLISECONDS = 250;
  // 서버 MemberPickerService.MINIMUM_KEYWORD_LENGTH 와 같은 값
  var MINIMUM_KEYWORD_LENGTH = 2;
  var ID_PREVIEW_LENGTH = 8;
  var ID_DELIMITER = ',';
  var SEARCH_ERROR_MESSAGE = '회원을 찾지 못했어요. 다시 입력해 주세요 (E-CFG-MEM)';
  var LOOKUP_ERROR_MESSAGE = '회원 정보를 불러오지 못해 ID 만 보여요 (E-CFG-MEM)';

  function element(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  // 쉼표 목록 > ID 배열 (공백·빈 항목·중복 제거, 순서 유지)
  function splitIds(text) {
    var ids = [];
    (text || '').split(ID_DELIMITER).forEach(function (raw) {
      var id = raw.trim();
      if (id && ids.indexOf(id) < 0) ids.push(id);
    });
    return ids;
  }

  function shortId(id) {
    return id.length > ID_PREVIEW_LENGTH ? id.substring(0, ID_PREVIEW_LENGTH) + '…' : id;
  }

  function memberName(member) {
    return member.nickname || member.username || shortId(member.id);
  }

  function fetchJson(url) {
    return fetch(url, { headers: { Accept: 'application/json' } }).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return response.json();
    });
  }

  /** 위젯 그리기: 숨은 값 + 칩 + 검색칸 + 결과 목록 */
  function build(widget, current) {
    var ids = splitIds(current);
    var memberById = {};
    // 칩 이름 조회 상태: loading, done, failed (done 일 때만 "없는 회원" 표시)
    var lookupState = 'loading';
    var searchTimer = null;
    var searchSequence = 0;

    var hidden = element('input');
    hidden.type = 'hidden';
    hidden.name = 'value';
    var chipBox = element('div', 'flex flex-wrap gap-1');
    var searchInput = element('input', 'input input-bordered input-sm w-full');
    searchInput.type = 'search';
    searchInput.autocomplete = 'off';
    searchInput.placeholder = '아이디·닉네임·회원 ID 로 찾아 추가 (2글자 이상)';
    var resultBox = element('ul',
      'menu menu-sm hidden max-h-60 flex-nowrap overflow-y-auto rounded-box border border-base-300 bg-base-100');
    var statusText = element('p', 'text-xs text-base-content/60');

    // --- 칩 (고른 회원) ---
    function sync() {
      hidden.value = ids.join(ID_DELIMITER);
      renderChips();
    }

    function renderChips() {
      chipBox.textContent = '';
      if (!ids.length) {
        chipBox.appendChild(element('span', 'text-sm text-base-content/50', '고른 회원이 없어요 (이대로 저장하면 없음)'));
        return;
      }
      ids.forEach(function (id) {
        var member = memberById[id];
        var isUnknown = lookupState === 'done' && !member;
        var chip = element('span', 'badge h-auto gap-1 py-1 ' + (isUnknown ? 'badge-error' : 'badge-outline'));
        chip.title = id;
        var label = member
          ? memberName(member) + ' · ' + shortId(id)
          : (isUnknown ? '없는 회원 · ' : '') + shortId(id);
        chip.appendChild(element('span', 'max-w-48 truncate', label));
        if (member && member.status !== 'ACTIVE') {
          chip.appendChild(element('span', 'text-xs opacity-70', '(' + member.statusLabel + ')'));
        }
        var removeButton = element('button', 'btn btn-ghost btn-xs h-5 min-h-0 px-1', '✕');
        removeButton.type = 'button';
        removeButton.setAttribute('aria-label', label + ' 빼기');
        removeButton.addEventListener('click', function () {
          ids = ids.filter(function (chosenId) { return chosenId !== id; });
          sync();
        });
        chip.appendChild(removeButton);
        chipBox.appendChild(chip);
      });
    }

    // 저장된 ID > 회원 정보 (칩 이름, 없는 회원 구분)
    function lookupChosenMembers() {
      if (!ids.length) {
        lookupState = 'done';
        renderChips();
        return;
      }
      fetchJson('/admin/settings/api/members/by-ids?ids=' + encodeURIComponent(ids.join(ID_DELIMITER)))
        .then(function (members) {
          members.forEach(function (member) { memberById[member.id] = member; });
          lookupState = 'done';
          renderChips();
        })
        .catch(function () {
          lookupState = 'failed';
          statusText.className = 'text-xs text-error';
          statusText.textContent = LOOKUP_ERROR_MESSAGE;
          renderChips();
        });
    }

    // --- 검색 결과 ---
    function hideResults() {
      resultBox.classList.add('hidden');
      resultBox.textContent = '';
    }

    function addMember(member) {
      memberById[member.id] = member;
      if (ids.indexOf(member.id) < 0) ids.push(member.id);
      searchInput.value = '';
      hideResults();
      sync();
      searchInput.focus();
    }

    function renderResults(members) {
      resultBox.textContent = '';
      resultBox.classList.remove('hidden');
      if (!members.length) {
        resultBox.appendChild(element('li', 'px-3 py-2 text-sm text-base-content/50', '맞는 회원이 없어요'));
        return;
      }
      members.forEach(function (member) {
        var isChosen = ids.indexOf(member.id) >= 0;
        var item = element('li');
        var button = element('button', 'flex flex-col items-start gap-0');
        button.type = 'button';
        button.disabled = isChosen;
        var title = element('span', 'font-medium', memberName(member) + (isChosen ? ' (추가됨)' : ''));
        var detail = element('span', 'text-xs text-base-content/60',
          (member.username || '-') + ' · ' + shortId(member.id) + ' · ' + member.statusLabel);
        button.appendChild(title);
        button.appendChild(detail);
        button.addEventListener('click', function () { addMember(member); });
        item.appendChild(button);
        resultBox.appendChild(item);
      });
    }

    function searchMembers(keyword) {
      var sequence = ++searchSequence; // 늦게 온 옛 응답이 새 결과를 덮지 않게
      fetchJson('/admin/settings/api/members?keyword=' + encodeURIComponent(keyword))
        .then(function (members) {
          if (sequence === searchSequence) renderResults(members);
        })
        .catch(function () {
          if (sequence !== searchSequence) return;
          resultBox.textContent = '';
          resultBox.classList.remove('hidden');
          resultBox.appendChild(element('li', 'px-3 py-2 text-sm text-error', SEARCH_ERROR_MESSAGE));
        });
    }

    searchInput.addEventListener('input', function () {
      clearTimeout(searchTimer);
      var keyword = searchInput.value.trim();
      if (keyword.length < MINIMUM_KEYWORD_LENGTH) {
        searchSequence++;
        hideResults();
        return;
      }
      searchTimer = setTimeout(function () { searchMembers(keyword); }, SEARCH_DELAY_MILLISECONDS);
    });
    searchInput.addEventListener('keydown', function (event) {
      // 검색칸 Enter 로 설정이 저장되지 않게
      if (event.key === 'Enter') event.preventDefault();
      // 결과가 열려 있으면 Esc 는 결과만 닫음 (패널은 그대로)
      if (event.key === 'Escape' && !resultBox.classList.contains('hidden')) {
        event.stopPropagation();
        hideResults();
      }
    });

    widget.appendChild(hidden);
    widget.appendChild(chipBox);
    widget.appendChild(searchInput);
    widget.appendChild(resultBox);
    widget.appendChild(statusText);
    sync();
    lookupChosenMembers();
  }

  window.elumSettingsMemberPicker = { build: build };
})();
