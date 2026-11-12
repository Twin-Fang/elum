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
