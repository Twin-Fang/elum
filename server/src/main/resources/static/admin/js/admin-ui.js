/*
 * 관리자 화면의 표시 설정 — 밝게/어둡게, 사이드바 접기 (이슈 #248).
 *
 * 화면이 그려지기 전에 실행돼야 한다. 나중에 바꾸면 밝은 화면이 한 번 번쩍인다.
 *
 * localStorage 접근은 전부 try/catch로 감싼다. 사생활 보호 모드나 저장소가
 * 막힌 환경에서 예외가 나는데, 그것 때문에 관리자 화면이 통째로 죽으면 안 된다.
 * 저장을 못 하면 이번 방문에만 적용되고 끝난다 — 화면은 계속 쓸 수 있다.
 */
(function () {
  'use strict';

  var KEY = 'elum-admin-theme';
  var SIDEBAR_KEY = 'elum-admin-sidebar';

  function read() {
    try {
      return localStorage.getItem(KEY);
    } catch (e) {
      return null; // 저장소를 못 읽어도 시스템 설정으로 계속 간다
    }
  }

  function write(value) {
    try {
      localStorage.setItem(KEY, value);
    } catch (e) {
      /* 기억하지 못할 뿐이다. 이번 방문에는 적용된다. */
    }
  }

  function systemTheme() {
    try {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    } catch (e) {
      return 'light';
    }
  }

  function apply(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    // 토글은 상단바·사이드바 두 곳에 있다. 둘 다 바꿔야 한쪽이 어긋나지 않는다.
    var icons = document.querySelectorAll('[data-theme-icon]');
    for (var i = 0; i < icons.length; i++) {
      icons[i].textContent = theme === 'dark' ? '☀️' : '🌙';
    }
  }

  // --- 사이드바 접기 ---
  //
  // 넓은 화면에서 사이드바는 daisyUI의 `lg:drawer-open` 으로 늘 열려 있다.
  // 그 클래스를 떼면 접힌다. 표가 넓은 화면에서 256px를 되찾기 위한 것이라
  // **접은 상태를 기억한다** — 매번 접어야 하면 더 번거롭다.
  var OPEN_CLASS = 'lg:drawer-open';

  function sidebarCollapsed() {
    try {
      return localStorage.getItem(SIDEBAR_KEY) === 'collapsed';
    } catch (e) {
      return false; // 못 읽으면 펼친 채로 둔다 — 메뉴가 사라지는 쪽이 더 곤란하다
    }
  }

  function applySidebar(collapsed) {
    var drawer = document.querySelector('[data-drawer]');
    if (!drawer) return;
    if (collapsed) {
      drawer.classList.remove(OPEN_CLASS);
    } else {
      drawer.classList.add(OPEN_CLASS);
    }
  }

  // 저장값이 없으면 시스템 설정을 따른다.
  apply(read() || systemTheme());

  document.addEventListener('DOMContentLoaded', function () {
    apply(read() || systemTheme()); // 아이콘은 DOM이 생긴 뒤에야 맞출 수 있다
    applySidebar(sidebarCollapsed());

    document.addEventListener('click', function (event) {
      if (!event.target.closest) return;

      if (event.target.closest('[data-theme-toggle]')) {
        var next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        apply(next);
        write(next);
        return;
      }

      if (event.target.closest('[data-sidebar-toggle]')) {
        var collapsed = !sidebarCollapsed();
        applySidebar(collapsed);
        try {
          localStorage.setItem(SIDEBAR_KEY, collapsed ? 'collapsed' : 'open');
        } catch (e) {
          /* 기억하지 못할 뿐이다. 이번 방문에는 적용된다. */
        }
      }
    });
  });
})();
