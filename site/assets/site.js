// 이룸 소개 사이트: 나타나기 연출 · 기기에 맞는 스토어 버튼 · 아래쪽 앱 받기 띠
(function () {
  'use strict';
  var root = document.documentElement;

  // 기기 종류 (ios · android · other): 맞는 스토어 버튼만 앞세움
  var agent = navigator.userAgent || '';
  var isIos = /iPhone|iPad|iPod/.test(agent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var platform = isIos ? 'ios' : (/Android/.test(agent) ? 'android' : 'other');
  root.setAttribute('data-platform', platform);

  // 스크롤해 들어올 때 나타나기 (움직임 줄이기 설정이면 바로 보임)
  var revealTargets = document.querySelectorAll('.reveal');
  var isMotionReduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (isMotionReduced || !('IntersectionObserver' in window)) {
    revealTargets.forEach(function (target) { target.classList.add('in'); });
  } else {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('in');
        observer.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -8% 0px' });
    revealTargets.forEach(function (target) { observer.observe(target); });
  }

  // 첫 화면 기기 틀: 마우스 위치 따라 살짝 기울기 (마우스 있는 PC · 움직임 줄이기 아닐 때만)
  var phone = document.querySelector('.phone');
  var heroVisual = document.querySelector('.hero-visual');
  // 기울기 폭 (마우스가 끝에서 끝으로 갈 때 바뀌는 각도) · 가운데일 때 기본 각도
  var TILT_RANGE_Y_DEGREES = 16;
  var TILT_BASE_Y_DEGREES = -4;
  var TILT_RANGE_X_DEGREES = 10;
  var TILT_BASE_X_DEGREES = 2;
  var hasFinePointer = window.matchMedia && window.matchMedia('(pointer: fine)').matches;
  if (phone && heroVisual && hasFinePointer && !isMotionReduced) {
    heroVisual.addEventListener('pointermove', function (event) {
      var box = heroVisual.getBoundingClientRect();
      var ratioX = (event.clientX - box.left) / box.width - 0.5;
      var ratioY = (event.clientY - box.top) / box.height - 0.5;
      phone.style.setProperty('--tilt-y', (ratioX * TILT_RANGE_Y_DEGREES + TILT_BASE_Y_DEGREES).toFixed(2) + 'deg');
      phone.style.setProperty('--tilt-x', (-ratioY * TILT_RANGE_X_DEGREES + TILT_BASE_X_DEGREES).toFixed(2) + 'deg');
    });
    heroVisual.addEventListener('pointerleave', function () {
      phone.style.removeProperty('--tilt-y');
      phone.style.removeProperty('--tilt-x');
    });
  }

  // 칸 제목 등장 연출: 칸이 화면에 들어오면 seen (움직임 줄이기 · 옛 브라우저는 연출 없음)
  var sections = document.querySelectorAll('main section, body > section');
  if (!isMotionReduced && 'IntersectionObserver' in window && sections.length) {
    root.classList.add('fx');
    var sectionObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('seen');
        sectionObserver.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -12% 0px' });
    sections.forEach(function (section) { sectionObserver.observe(section); });
  }

  // 머리 아래 스크롤 진행 막대 (0~1)
  var updateScrollProgress = function () {
    var scrollable = document.documentElement.scrollHeight - window.innerHeight;
    root.style.setProperty('--scroll', scrollable > 0 ? Math.min(1, window.scrollY / scrollable).toFixed(4) : '0');
  };
  window.addEventListener('scroll', updateScrollProgress, { passive: true });
  updateScrollProgress();

  // 아래쪽 앱 받기 띠: 휴대 기기에서 첫 화면을 지나면 보임, 받기 묶음이 보이면 숨김
  var getBar = document.getElementById('getbar');
  if (getBar && platform !== 'other') {
    var downloadSection = document.querySelector('.download');
    var isDownloadVisible = false;
    if (downloadSection && 'IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        isDownloadVisible = entries[0].isIntersecting;
        updateGetBar();
      }).observe(downloadSection);
    }
    var updateGetBar = function () {
      getBar.hidden = !(window.scrollY > 480 && !isDownloadVisible);
    };
    window.addEventListener('scroll', updateGetBar, { passive: true });
    updateGetBar();
  }
})();
