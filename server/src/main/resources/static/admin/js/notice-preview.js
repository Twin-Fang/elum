/*
 * 공지 관리 — 앱 팝업 미리보기와 편집 도움 (이슈 #370).
 *
 * 앱 팝업(보호자 홈, #371)을 휴대폰 틀(393×852) 안에 **같은 치수로** 그린다. 올리기 전에
 * 앱에서 어떻게 보일지 알아야 하기 때문이다. 치수와 색은 맨 위 APP 한 곳에 모았다 —
 * 앱에서 바꾸면 여기도 함께 바꾼다. 어긋나면 미리보기가 거짓말을 한다(명세 N21).
 *
 * 관리자가 적은 글자는 전부 textContent 로 넣는다. innerHTML 로 넣으면 제목에 태그를 적는
 * 것만으로 관리자 화면에 스크립트가 돈다.
 *
 * 하는 일
 *   1. 미리보기 그리기 — 편집 화면(입력하는 대로)과 목록 화면(전체 미리보기)
 *   2. 문구 도움 — 금지어·해요체·글자 수·강조 짝·이미지 형식/크기/비율을 입력 즉시 짚는다
 *      (경고만 한다. 저장을 막는 것은 서버 검증이다)
 *   3. 지우기 확인 — 게시 중이면 한 번 더 묻는다
 */
(function () {
  'use strict';

  // ── 앱 팝업과 같은 값 (명세 2-1 · 3-2) ────────────────────────────
  var APP = {
    phoneW: 393, phoneH: 852,
    cardWidthRatio: 0.9, cardMaxWidth: 360, cardRadius: 20,
    imageRatio: 16 / 10, contentPadding: 20,
    titleSize: 18, bodySize: 14, buttonHeight: 44,
    dotSize: 8, dotGap: 6, hitSize: 44,
    maxSlides: 5,
    color: {
      screen: '#F7F2EF',      // background
      surface: '#FFFFFF',     // surface
      title: '#242634',       // textPrimary
      body: '#74757D',        // routineTileLabel — 14px 에서도 흰 바탕 대비 4.5:1 을 넘는다
      emphasis: '#55CFBA',    // checkDone — 앱의 주 동작(팝업 주 버튼) 색
      button: '#55CFBA',
      buttonText: '#FFFFFF',
      dotOn: '#242634',
      dotOff: '#D7D3D1',      // dialogNeutral
      imageEmpty: '#F7F2EF',  // 이미지 없는 슬라이드의 연한 바탕 (N28)
      dim: 'rgba(0,0,0,0.5)'
    }
  };

  var IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
  var IMAGE_MAX_BYTES = 2 * 1024 * 1024;

  // 저장소 용어 규칙(docs/08-design-principles.md §3-3). 경고만 한다 — 법적 문구가 필요할 때가 있다.
  // "아이"는 아이디·아이콘·아이폰처럼 다른 낱말 안에서도 나와 그 경우는 뺀다.
  var FORBIDDEN = [
    // 조사까지 적어 둔다. 을(를)로 뭉뚱그리면 관공서 문투가 된다(AdminConsentController 와 같은 판단).
    { word: '아이', re: /아이(?!디|콘|템|폰|패드|스)/, instead: "'이룸이'를" },
    { word: '아동', re: /아동/, instead: "'이룸이'를" },
    { word: '기기', re: /기기/, instead: "'휴대폰'을" },
    { word: '모드', re: /모드/, instead: "'화면'을" },
    { word: '강화', re: /강화/, instead: "'보상'을" }
  ];
  var FORMAL_ENDING = /(습니다|합니다|됩니다|입니다|십시오)/;

  // ── 공통 도움 ────────────────────────────────────────────────

  function ready(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  function readData() {
    try {
      var raw = window.NOTICE_PREVIEW_DATA;
      var data = typeof raw === 'string' ? JSON.parse(raw) : raw;
      return {
        hideDays: data && data.hideDays > 0 ? data.hideDays : 7,
        notices: data && Array.isArray(data.notices) ? data.notices : []
      };
    } catch (e) {
      // 자료가 깨져도 편집은 된다. 이 공지 하나만 미리 본다.
      return { hideDays: 7, notices: [] };
    }
  }

  function hideLabel(days) {
    return days === 7 ? '일주일간 보지 않기' : days + '일간 보지 않기';
  }

  /** 서버·앱과 같은 규칙: ** 로 나눈 홀수 번째 조각이 강조. 짝이 안 맞으면 표기만 지운다(N25). */
  function titleParts(title) {
    var pieces = String(title || '').split('**');
    if (pieces.length % 2 === 0) {
      return { paired: false, parts: [{ text: pieces.join(''), em: false }] };
    }
    return {
      paired: true,
      parts: pieces.map(function (text, i) { return { text: text, em: i % 2 === 1 }; })
    };
  }

  /** 앱과 같은 순서 — 우선순위 큰 것 먼저, 같으면 시작이 늦은 것 먼저. */
  function slideOrder(a, b) {
    if ((b.priority || 0) !== (a.priority || 0)) return (b.priority || 0) - (a.priority || 0);
    return String(b.startsAt || '').localeCompare(String(a.startsAt || ''));
  }

  function reaches(noticePlatform, platform) {
    return noticePlatform === 'ALL' || noticePlatform === platform;
  }

  // ── 미리보기 그리기 ─────────────────────────────────────────

  var SCALE = 0.75; // 관리자 화면 옆 칸에 들어가게 줄인다. 치수는 그대로다.

  function injectStyles() {
    if (document.getElementById('np-styles')) return;
    var c = APP.color;
    var cardW = Math.min(APP.phoneW * APP.cardWidthRatio, APP.cardMaxWidth);
    var css = [
      '.np-page{display:grid;gap:1.5rem;align-items:start}.np-page>*{min-width:0}',
      '@media (min-width:1280px){.np-page{grid-template-columns:minmax(0,1fr) 360px}.np-aside{position:sticky;top:4.5rem}}',
      '.np-frame{position:relative;margin:0 auto;overflow:hidden;border-radius:' + (36 * SCALE) + 'px;',
      '  box-shadow:0 0 0 5px #1f2330,0 8px 24px rgba(0,0,0,.25);width:' + (APP.phoneW * SCALE) + 'px;height:' + (APP.phoneH * SCALE) + 'px}',
      '.np-phone{position:absolute;top:0;left:0;width:' + APP.phoneW + 'px;height:' + APP.phoneH + 'px;transform:scale(' + SCALE + ');',
      '  transform-origin:0 0;background:' + c.screen + ';overflow:hidden;color:' + c.title + ';',
      '  font-family:Pretendard,-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Noto Sans KR",sans-serif}',
      '.np-home{padding:76px 24px 0}',
      '.np-home-line{height:26px;width:55%;border-radius:8px;background:#EEE9E6;margin-bottom:18px}',
      '.np-home-card{height:150px;border-radius:20px;background:#fff;margin-bottom:16px}',
      '.np-dim{position:absolute;inset:0;background:' + c.dim + ';display:flex;align-items:center;justify-content:center}',
      '.np-card{position:relative;width:' + cardW + 'px;max-height:calc(100% - 96px);background:' + c.surface + ';',
      '  border-radius:' + APP.cardRadius + 'px;overflow:hidden;display:flex;flex-direction:column;box-shadow:4px 4px 6px rgba(0,0,0,.05)}',
      '.np-media{position:relative;flex:none;width:100%;aspect-ratio:' + APP.imageRatio + ';background:' + c.imageEmpty + '}',
      '.np-media img{display:block;width:100%;height:100%;object-fit:cover}',
      '.np-top{display:flex;justify-content:flex-end;align-items:center;gap:2px;padding:6px 4px 0 8px}',
      '.np-media .np-top{position:absolute;top:0;right:0}',
      '.np-hide{display:inline-flex;align-items:center;gap:6px;height:32px;padding:0 12px;border-radius:999px;',
      '  background:rgba(255,255,255,.85);font-size:13px;color:' + c.title + ';white-space:nowrap}',
      '.np-check{width:16px;height:16px;border:1.5px solid #898B98;border-radius:4px;background:#fff}',
      '.np-close{width:' + APP.hitSize + 'px;height:' + APP.hitSize + 'px;display:inline-flex;align-items:center;justify-content:center}',
      '.np-close span{width:28px;height:28px;border-radius:50%;background:rgba(36,38,52,.6);color:#fff;',
      '  display:flex;align-items:center;justify-content:center;font-size:14px;line-height:1}',
      '.np-content{flex:1 1 auto;min-height:0;display:flex;flex-direction:column;align-items:center;gap:10px;',
      '  padding:' + APP.contentPadding + 'px ' + APP.contentPadding + 'px 4px;text-align:center}',
      '.np-content.is-last{padding-bottom:' + APP.contentPadding + 'px}',
      '.np-title{flex:none;font-size:' + APP.titleSize + 'px;font-weight:700;line-height:1.35;word-break:keep-all;overflow-wrap:anywhere}',
      '.np-em{color:' + c.emphasis + '}',
      '.np-body{flex:0 1 auto;min-height:0;overflow-y:auto;font-size:' + APP.bodySize + 'px;line-height:1.5;color:' + c.body + ';',
      '  white-space:pre-line;word-break:keep-all;overflow-wrap:anywhere}',
      '.np-btn{flex:none;height:' + APP.buttonHeight + 'px;max-width:100%;padding:0 20px;margin-top:4px;border-radius:8px;',
      '  background:' + c.button + ';color:' + c.buttonText + ';font-size:16px;font-weight:600;display:inline-flex;align-items:center;',
      '  white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
      '.np-nav{flex:none;display:flex;align-items:center;justify-content:space-between;padding:0 6px 6px}',
      '.np-arrow{width:' + APP.hitSize + 'px;height:' + APP.hitSize + 'px;border:0;background:none;padding:0;cursor:pointer;',
      '  font-size:20px;color:#898B98}',
      '.np-arrow.is-off{visibility:hidden}',
      '.np-dots{display:flex;gap:' + APP.dotGap + 'px}',
      '.np-dot{width:' + APP.dotSize + 'px;height:' + APP.dotSize + 'px;border-radius:50%;border:0;padding:0;cursor:pointer;background:' + c.dotOff + '}',
      '.np-dot.is-on{background:' + c.dotOn + '}',
      '.np-empty{position:absolute;left:24px;right:24px;top:45%;text-align:center;font-size:16px;color:#898B98;white-space:pre-line}'
    ].join('\n');
    var style = el('style');
    style.id = 'np-styles';
    style.textContent = css;
    document.head.appendChild(style);
  }

  /**
   * 팝업을 그린다.
   *
   * @param slides   [{title, body, imageUrl, buttonLabel, buttonUrl}] — 앱이 받는 순서 그대로
   * @param hideDays 보지 않기 일수
   * @param index    처음 보여줄 슬라이드
   */
  function renderPopup(container, slides, hideDays, index) {
    injectStyles();
    container.textContent = '';
    var frame = el('div', 'np-frame');
    var phone = el('div', 'np-phone');
    frame.appendChild(phone);
    container.appendChild(frame);

    // 보호자 홈을 흐릿하게 흉내 낸다. 팝업이 무엇 위에 뜨는지 보이게.
    var home = el('div', 'np-home');
    home.appendChild(el('div', 'np-home-line'));
    home.appendChild(el('div', 'np-home-card'));
    home.appendChild(el('div', 'np-home-card'));
    phone.appendChild(home);

    if (!slides.length) {
      phone.appendChild(el('div', 'np-empty', '지금 이 플랫폼에 게시 중인 공지가 없어요.\n팝업이 뜨지 않아요.'));
      return;
    }

    var dim = el('div', 'np-dim');
    var card = el('div', 'np-card');
    card.setAttribute('role', 'dialog');
    card.setAttribute('aria-label', '공지 팝업 미리보기');
    dim.appendChild(card);
    phone.appendChild(dim);

    // 이미지가 하나라도 있으면 모든 슬라이드에 그림 자리를 둔다 — 넘길 때 카드 높이가 튀지 않게 (N28)
    var anyImage = slides.some(function (s) { return !!s.imageUrl; });
    var current = Math.max(0, Math.min(index || 0, slides.length - 1));

    function top() {
      var bar = el('div', 'np-top');
      var hide = el('span', 'np-hide');
      hide.appendChild(el('span', 'np-check'));
      hide.appendChild(document.createTextNode(hideLabel(hideDays)));
      var close = el('span', 'np-close');
      close.setAttribute('aria-label', '공지 닫기');
      close.appendChild(el('span', null, '✕'));
      bar.appendChild(hide);
      bar.appendChild(close);
      return bar;
    }

    function draw() {
      card.textContent = '';
      var slide = slides[current];

      if (anyImage) {
        var media = el('div', 'np-media');
        if (slide.imageUrl) {
          var img = el('img');
          img.alt = '';
          img.src = slide.imageUrl;
          // 앱도 이미지를 못 받으면 그림 자리 없이 글만 보인다(N3). 미리보기는 연한 바탕으로 둔다.
          img.onerror = function () { img.remove(); };
          media.appendChild(img);
        }
        media.appendChild(top());
        card.appendChild(media);
      } else {
        card.appendChild(top());
      }

      var content = el('div', 'np-content' + (slides.length > 1 ? '' : ' is-last'));
      var title = el('div', 'np-title');
      titleParts(slide.title).parts.forEach(function (part) {
        if (!part.text) return;
        title.appendChild(part.em ? el('span', 'np-em', part.text) : document.createTextNode(part.text));
      });
      content.appendChild(title);
      content.appendChild(el('div', 'np-body', slide.body || ''));
      // 앱은 https 가 아닌 링크의 버튼을 숨긴다 (N12). 미리보기도 같게.
      if (slide.buttonLabel && /^https:\/\//.test(slide.buttonUrl || '')) {
        var button = el('span', 'np-btn', slide.buttonLabel);
        button.title = slide.buttonUrl;
        content.appendChild(button);
      }
      card.appendChild(content);

      // 한 장이면 점·화살표를 숨긴다 (N23)
      if (slides.length > 1) {
        var nav = el('div', 'np-nav');
        var prev = el('button', 'np-arrow' + (current === 0 ? ' is-off' : ''), '←');
        prev.type = 'button';
        prev.setAttribute('aria-label', '이전 공지');
        prev.addEventListener('click', function () { go(current - 1); });
        var dots = el('div', 'np-dots');
        slides.forEach(function (_, i) {
          var dot = el('button', 'np-dot' + (i === current ? ' is-on' : ''));
          dot.type = 'button';
          dot.setAttribute('aria-label', (i + 1) + '/' + slides.length);
          dot.addEventListener('click', function () { go(i); });
          dots.appendChild(dot);
        });
        var next = el('button', 'np-arrow' + (current === slides.length - 1 ? ' is-off' : ''), '→');
        next.type = 'button';
        next.setAttribute('aria-label', '다음 공지');
        next.addEventListener('click', function () { go(current + 1); });
        nav.appendChild(prev);
        nav.appendChild(dots);
        nav.appendChild(next);
        card.appendChild(nav);
      }
    }

    function go(i) {
      if (i < 0 || i >= slides.length) return;
      current = i;
      draw();
    }

    // 옆으로 밀어 넘기기. 앱과 같은 몸짓을 미리보기에서도 해 본다.
    var startX = null;
    card.addEventListener('pointerdown', function (e) { startX = e.clientX; });
    card.addEventListener('pointerup', function (e) {
      if (startX == null) return;
      var dx = e.clientX - startX;
      startX = null;
      if (Math.abs(dx) > 30) go(current + (dx < 0 ? 1 : -1));
    });

    draw();
  }

  function setActive(buttons, attr, value) {
    buttons.forEach(function (b) {
      var on = b.getAttribute(attr) === value;
      b.classList.toggle('btn-primary', on);
      b.classList.toggle('btn-ghost', !on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }

  // ── 목록 화면: 전체 미리보기 ─────────────────────────────────

  function initListPreview(container) {
    var data = readData();
    var note = document.querySelector('[data-preview-note]');
    var buttons = Array.prototype.slice.call(document.querySelectorAll('[data-preview-platform]'));
    var platform = 'IOS';

    function render() {
      var slides = data.notices
        .filter(function (n) { return reaches(n.platform, platform); })
        .slice(0, APP.maxSlides);
      renderPopup(container, slides, data.hideDays, 0);
      if (note) {
        var total = data.notices.filter(function (n) { return reaches(n.platform, platform); }).length;
        note.textContent = total > APP.maxSlides
          ? '게시 중 ' + total + '개 중 우선순위가 큰 ' + APP.maxSlides + '개만 팝업에 들어가요.'
          : '';
      }
    }

    buttons.forEach(function (b) {
      b.addEventListener('click', function () {
        platform = b.getAttribute('data-preview-platform');
        setActive(buttons, 'data-preview-platform', platform);
        render();
      });
    });
    render();
  }

  // ── 편집 화면: 입력하는 대로 ────────────────────────────────

  function initEditor(form, container) {
    var data = readData();
    var $ = function (id) { return document.getElementById(id); };
    var title = $('notice-title');
    var body = $('notice-body');
    var buttonLabel = $('notice-button-label');
    var buttonUrl = $('notice-button-url');
    var image = $('notice-image');
    var removeImage = $('notice-remove-image');
    var platformSelect = $('notice-platform');
    var priority = $('notice-priority');
    var startsAt = $('notice-starts-at');
    var enabled = $('notice-enabled');
    var wording = $('notice-wording');
    var imageNote = $('notice-image-note');
    var note = document.querySelector('[data-preview-note]');
    var modeButtons = Array.prototype.slice.call(document.querySelectorAll('[data-preview-mode]'));
    var platformButtons = Array.prototype.slice.call(document.querySelectorAll('[data-preview-platform]'));

    var existingImage = container.getAttribute('data-existing-image') || '';
    var pickedImage = null; // 고른 파일을 읽은 data URL. 올리기 전에 미리 본다.
    var mode = 'single';
    var previewPlatform = platformSelect && platformSelect.value === 'ANDROID' ? 'ANDROID' : 'IOS';

    function draft() {
      var imageUrl = pickedImage || (removeImage && removeImage.checked ? null : existingImage || null);
      return {
        draft: true,
        title: title.value, body: body.value,
        imageUrl: imageUrl,
        buttonLabel: buttonLabel.value.trim(), buttonUrl: buttonUrl.value.trim(),
        platform: platformSelect.value, priority: parseInt(priority.value, 10) || 0,
        startsAt: startsAt.value
      };
    }

    function render() {
      var d = draft();
      var messages = [];
      var slides;
      var index = 0;
      if (mode === 'single') {
        slides = [d];
      } else {
        var others = data.notices.filter(function (n) { return reaches(n.platform, previewPlatform); });
        if (reaches(d.platform, previewPlatform)) {
          others = others.concat([d]);
        } else {
          messages.push('이 공지는 ' + (previewPlatform === 'IOS' ? 'iOS' : 'Android') + ' 앱에는 나가지 않아요.');
        }
        var ordered = others.slice().sort(slideOrder);
        var at = ordered.indexOf(d);
        if (at >= APP.maxSlides) {
          messages.push('우선순위가 낮아 ' + APP.maxSlides + '장 밖이라 앱에는 안 나가요. 우선순위를 올리면 들어가요.');
        } else if (at >= 0) {
          messages.push('이 공지는 ' + (at + 1) + '번째 장이에요.');
          index = at;
        }
        slides = ordered.slice(0, APP.maxSlides);
      }
      if (enabled && !enabled.checked) messages.push('꺼 둔 채라 저장해도 앱에는 아직 나가지 않아요.');
      renderPopup(container, slides, data.hideDays, index);
      if (note) note.textContent = messages.join(' ');
      checkWording();
    }

    function counter(input) {
      var target = document.querySelector('[data-count-for="' + input.id + '"]');
      if (!target) return;
      var max = input.getAttribute('maxlength');
      target.textContent = input.value.length + '/' + max;
    }

    // 문구 도움 (N20·N25). 경고만 한다.
    function checkWording() {
      if (!wording) return;
      wording.textContent = '';
      var text = [title.value, body.value, buttonLabel.value].join('\n');
      FORBIDDEN.forEach(function (f) {
        if (f.re.test(text)) {
          wording.appendChild(el('li', null, "'" + f.word + "' 대신 " + f.instead + ' 써요. 용어 규칙이에요'));
        }
      });
      if (FORMAL_ENDING.test(text)) {
        wording.appendChild(el('li', null, '해요체로 바꿔 볼까요? 예: 됩니다 → 돼요, 저장되었습니다 → 저장했어요'));
      }
      if (!titleParts(title.value).paired) {
        var li = el('li', 'text-error', '제목의 ** 짝이 맞지 않아요. 이대로는 저장되지 않아요. 강조할 글자를 **이렇게** 감싸요');
        wording.appendChild(li);
      }
    }

    function onImagePicked() {
      pickedImage = null;
      if (imageNote) imageNote.textContent = '';
      var file = image.files && image.files[0];
      if (!file) { render(); return; }
      // 서버가 서명으로 다시 가린다. 여기서는 올리기 전에 빨리 알려 주기만 한다 (N16).
      if (IMAGE_TYPES.indexOf(file.type) < 0) {
        imageNote.textContent = 'png, jpg, webp 만 올릴 수 있어요. 이 파일은 저장할 때 거절돼요.';
        render();
        return;
      }
      if (file.size > IMAGE_MAX_BYTES) {
        imageNote.textContent = '2MB 를 넘어요(' + (file.size / 1024 / 1024).toFixed(1) + 'MB). 줄여서 다시 골라 주세요.';
        render();
        return;
      }
      var reader = new FileReader();
      reader.onload = function () {
        pickedImage = String(reader.result);
        var probe = new Image();
        probe.onload = function () {
          var ratio = probe.naturalWidth / probe.naturalHeight;
          if (Math.abs(ratio - APP.imageRatio) / APP.imageRatio > 0.03) {
            imageNote.textContent = '16:10 이 아니라서(' + probe.naturalWidth + '×' + probe.naturalHeight
              + ') 가장자리가 잘려 보여요. 미리보기로 확인해요.';
          }
        };
        probe.src = pickedImage;
        render();
      };
      reader.onerror = function () {
        imageNote.textContent = '이 파일을 읽지 못했어요. 다른 파일을 골라 주세요.';
        render();
      };
      reader.readAsDataURL(file);
    }

    [title, body, buttonLabel, buttonUrl, priority, startsAt].forEach(function (input) {
      if (!input) return;
      input.addEventListener('input', function () {
        counter(input);
        render();
      });
      counter(input);
    });
    [platformSelect, enabled, removeImage].forEach(function (input) {
      if (input) input.addEventListener('change', render);
    });
    if (image) image.addEventListener('change', onImagePicked);

    modeButtons.forEach(function (b) {
      b.addEventListener('click', function () {
        mode = b.getAttribute('data-preview-mode');
        setActive(modeButtons, 'data-preview-mode', mode);
        render();
      });
    });
    platformButtons.forEach(function (b) {
      b.addEventListener('click', function () {
        previewPlatform = b.getAttribute('data-preview-platform');
        setActive(platformButtons, 'data-preview-platform', previewPlatform);
        render();
      });
    });
    setActive(platformButtons, 'data-preview-platform', previewPlatform);

    render();
  }

  // ── 지우기 확인 ─────────────────────────────────────────────

  function initDeleteConfirm() {
    document.querySelectorAll('form[data-notice-delete]').forEach(function (form) {
      form.addEventListener('submit', function (event) {
        var title = (form.getAttribute('data-title') || '').split('**').join('');
        if (!window.confirm("'" + title + "' 공지를 지울까요? 이미지도 함께 지워지고 되돌릴 수 없어요.")) {
          event.preventDefault();
          return;
        }
        // 게시 중이면 한 번 더 묻는다 — 지금 보호자에게 나가고 있는 것이다.
        if (form.getAttribute('data-live') === 'true'
          && !window.confirm('지금 게시 중인 공지예요. 지우면 다음에 앱을 켜는 보호자부터 안 보여요. 정말 지울까요?')) {
          event.preventDefault();
        }
      });
    });
  }

  ready(function () {
    try {
      var editor = document.getElementById('notice-form');
      var editPreview = document.getElementById('notice-preview');
      if (editor && editPreview) initEditor(editor, editPreview);
      var listPreview = document.querySelector('[data-notice-preview-list]');
      if (listPreview) initListPreview(listPreview);
    } catch (e) {
      // 미리보기가 깨져도 입력과 저장은 된다. 원인은 콘솔에 남긴다.
      if (window.console) console.error('[공지 미리보기] 그리지 못했어요 (E-NTC-JS)', e);
    }
    initDeleteConfirm();
  });

  // 테스트나 콘솔에서 쓸 수 있게 드러낸다.
  window.ElumNoticePreview = { renderPopup: renderPopup, titleParts: titleParts, APP: APP };
})();
