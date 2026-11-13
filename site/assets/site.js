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

  // 첫 화면 기기: 앱 화면 2장(적기, 확인) > 시연 영상(따라 하기 > 보상) 반복, 단계 칩·옆 그림을 같은 단계로 켬
  var phoneScreen = document.querySelector('.phone-screen');
  var flowVideo = phoneScreen && phoneScreen.querySelector('.flow');
  if (phoneScreen && flowVideo && !isMotionReduced) {
    var STILL_SCREEN_SECONDS = 3.5;
    var stillScreens = phoneScreen.querySelectorAll('.still');
    var stepChips = document.querySelectorAll('.phone-steps li');
    var stepPops = document.querySelectorAll('.phone-stage .pop');
    var rewardStartSeconds = parseFloat(flowVideo.getAttribute('data-reward-start')) || 0;
    var currentStep = -1;
    var sequenceTimer = 0;

    var showScreen = function (screen) {
      stillScreens.forEach(function (still) { still.classList.toggle('on', still === screen); });
      flowVideo.classList.toggle('on', flowVideo === screen);
    };
    // 단계 칩·옆 그림 켜기 (칩 막대는 그 단계 길이만큼, 다시 켤 때 처음부터)
    var showStep = function (stepIndex, durationSeconds) {
      currentStep = stepIndex;
      stepChips.forEach(function (chip, index) {
        chip.classList.remove('on');
        if (index === stepIndex) {
          chip.style.setProperty('--dur', durationSeconds + 's');
          void chip.offsetWidth;
          chip.classList.add('on');
        }
      });
      stepPops.forEach(function (pop, index) { pop.classList.toggle('on', index === stepIndex); });
    };
    var playFlowVideo = function () {
      if (!flowVideo.src) flowVideo.src = flowVideo.getAttribute('data-src');
      showScreen(flowVideo);
      showStep(2, rewardStartSeconds);
      flowVideo.currentTime = 0;
      var playing = flowVideo.play();
      // 자동 재생이 막히면 첫 장면 그림을 둔 채 순서만 이어 감
      if (playing && playing.catch) {
        playing.catch(function () { sequenceTimer = setTimeout(startSequence, rewardStartSeconds * 1000); });
      }
    };
    var startSequence = function () {
      clearTimeout(sequenceTimer);
      phoneScreen.classList.add('playing');
      showScreen(stillScreens[0]);
      showStep(0, STILL_SCREEN_SECONDS);
      sequenceTimer = setTimeout(function () {
        showScreen(stillScreens[1]);
        showStep(1, STILL_SCREEN_SECONDS);
        sequenceTimer = setTimeout(playFlowVideo, STILL_SCREEN_SECONDS * 1000);
      }, STILL_SCREEN_SECONDS * 1000);
    };
    flowVideo.addEventListener('timeupdate', function () {
      if (currentStep === 2 && flowVideo.currentTime >= rewardStartSeconds) {
        showStep(3, Math.max(1, (flowVideo.duration || rewardStartSeconds + 6) - rewardStartSeconds));
      }
    });
    flowVideo.addEventListener('ended', startSequence);
    startSequence();
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
