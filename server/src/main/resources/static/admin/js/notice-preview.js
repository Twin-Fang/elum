/*
 * 공지 관리 — 앱 팝업 미리보기와 편집 도움 (이슈 #370 · #390).
 *
 * 앱 팝업(보호자 홈)을 휴대폰 틀(393×852) 안에 **같은 치수·같은 글꼴·같은 줄바꿈으로** 그린다.
 * 올리기 전에 앱에서 어떻게 보일지 알아야 하기 때문이다. 치수와 색은 맨 위 APP 한 곳에
 * 모았다 — 앱(`NoticePopupCard`·`ElumDialogSurface`·`AppTypography.notice*`)에서 바꾸면
 * 여기도 함께 바꾼다. 어긋나면 미리보기가 거짓말을 한다(명세 N21 · #385 A).
 *
 * #390 에서 앱 팝업이 공통 팝업(`팝업` 931:4878 의 `방침` 변형 1090:4922)으로 바뀌었다.
 * 슬라이드·점·화살표가 없어지고 공지가 여럿이면 **하나씩 차례로** 뜬다. 미리보기도 같다.
 *
 * 줄바꿈은 **어절 단위**다. 앱은 붙은 글자 사이에 끊지 말라는 표시(U+2060)를 넣어 띄어쓰기
 * 에서만 끊는다(`keep_words.dart`). 여기서도 **같은 함수(keepWords)로 같은 표시를** 넣는다.
 * CSS `keep-all` 에 맡기지 않는 이유 — 숫자·문장부호 옆에서 끊는 규칙이 엔진마다 달라
 * 앱과 한두 곳씩 어긋난다. 같은 표시를 넣으면 두 엔진 모두 띄어쓰기에서만 끊는다.
 * 글꼴도 앱과 같은 Pretendard 를 동봉해 쓴다(vendor/fonts) — 글꼴이 다르면 폭이 달라
 * 같은 규칙이어도 다른 자리에서 꺾인다.
 *
 * 관리자가 적은 글자는 전부 textContent 로 넣는다. innerHTML 로 넣으면 제목에 태그를 적는
 * 것만으로 관리자 화면에 스크립트가 돈다.
 *
 * 하는 일
 *   1. 미리보기 그리기 — 편집 화면(입력하는 대로)과 목록 화면(전체 미리보기)
 *   2. 문구 도움 — 금지어·해요체·글자 수·강조 짝·이미지 형식/크기/비율을 입력 즉시 짚는다
 *      (경고만 한다. 저장을 막는 것은 서버 검증이다)
 *   3. 지우기 확인 — 게시 중이면 한 번 더 묻는다
 *   4. 저장하면 어떻게 되는지 (#385 E) — 켜기 아래 한 줄로 "바로 보호자 모두에게 보여요" ·
 *      "시작 시각부터 보여요" · "아직 나가지 않아요"를 말하고, 나가고 있지 않던 공지가 저장·켜기
 *      한 번에 곧바로 나가게 될 때만 한 번 묻는다
 */
(function () {
  'use strict';

  // ── 앱 팝업과 같은 값 (시안 1090:4922 · 앱 NoticePopupCard) ─────────────
  var APP = {
    phoneW: 393, phoneH: 852,
    // 공통 팝업 카드 (ElumDialogSurface)
    cardWidth: 322, cardRadius: 20, padTop: 24, padSide: 14, padBottom: 14,
    // 긴 공지 — 카드는 화면의 75% 까지, 넘치면 글 자리만 스크롤 (N4)
    cardMaxHeightRatio: 0.75,
    // 그림 — 시안 밖(임시). 제목 위, 카드 안쪽 폭, 모서리 8, 그림이 맨 위면 위 여백 14
    imageRatio: 16 / 10, imageRadius: 8, imageToTitle: 20,
    // 글 (AppTypography.noticeTitle · noticeBody · noticeHideLabel)
    titleSize: 18, titleWeight: 500, titleLine: 1.1,
    bodySize: 16, bodyWeight: 400, bodyLine: 1.2,
    titleToBody: 20,
    // 보지 않기 — 동그란 체크 16 · 사이 6 · 글자 14
    bodyToHide: 24, checkSize: 16, checkGap: 6, hideSize: 14, hideToButtons: 14,
    // 버튼 (ElumDialogButton) — 높이 54 · 모서리 8 · 사이 4 · 18/600
    buttonHeight: 54, buttonRadius: 8, buttonGap: 4, buttonSize: 18, buttonWeight: 600,
    maxSlides: 5,
    color: {
      screen: '#F7F2EF',      // background
      surface: '#FFFFFF',     // surface
      title: '#000000',       // dialogTitleText — 공통 팝업 제목과 같은 순검정 (#318)
      body: '#000000',        // 시안 본문도 순검정 (1090:4903)
      emphasis: '#55CFBA',    // checkDone
      primary: '#55CFBA',     // checkDone — 주 동작 버튼
      primaryText: '#FFFFFF',
      neutral: '#D7D3D1',     // dialogNeutral — 닫기
      neutralText: '#FFFFFF', // dialogNeutralText
      hide: '#74757D',        // noticeHideLabel
      checkRing: '#C9D6D4',   // checkIdleBorder (`채크_라운드` Default)
      imageEmpty: '#F7F2EF',  // noticeImagePlaceholder — 그림을 받는 동안
      shadow: 'rgba(0,0,0,0.05)', // loginButtonShadow
      dim: 'rgba(0,0,0,0.5)'
    }
  };

  // 끊지 말라는 표시 (U+2060). 앱 keep_words.dart 의 _joiner 와 같다.
  var JOINER = '\u2060';

  // 체크 표시 — 앱 에셋 icon_check_mark.svg 와 같은 경로
  var CHECK_PATH = 'M9.13267 0.32031C9.55992 -0.106784 10.2524 -0.106756 10.6797 0.32031C11.1068 0.747577 11.1068 1.44008 10.6797 1.86733L4.80083 7.74521L4.68857 7.84762C4.41505 8.07201 4.07059 8.19538 3.71368 8.19523C3.30614 8.19526 2.9156 8.03347 2.62752 7.74521L0.320288 5.43896C-0.106734 5.01169 -0.106791 4.31918 0.320288 3.89194C0.734186 3.47838 1.39752 3.46576 1.82693 3.85354L1.86731 3.89194L3.71368 5.73832L9.13267 0.32031Z';

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
        notices: data && Array.isArray(data.notices) ? data.notices : [],
        serverNow: data && typeof data.serverNow === 'number' ? data.serverNow : null
      };
    } catch (e) {
      // 자료가 깨져도 편집은 된다. 이 공지 하나만 미리 본다.
      return { hideDays: 7, notices: [], serverNow: null };
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

  /** 글자 단위(이모지 한 덩어리는 한 글자)로 나눈다. 앱의 characters 와 같게. */
  function graphemes(text) {
    if (window.Intl && Intl.Segmenter) {
      return Array.from(new Intl.Segmenter('ko', { granularity: 'grapheme' }).segment(text),
        function (s) { return s.segment; });
    }
    return Array.from(text);
  }

  function isSpace(ch) { return ch.trim() === ''; }

  /**
   * 어절 단위 줄바꿈 — 앱 keepWordsParts 와 **같은 규칙**이다(#385 A).
   * 붙은 두 글자 사이에 끊지 말라는 표시를 넣는다. 조각(강조) 경계도 붙어 있으면 넣는다.
   */
  function keepWordsParts(parts) {
    var prev = null;
    return parts.map(function (part) {
      var out = '';
      graphemes(part).forEach(function (ch) {
        if (prev !== null && !isSpace(prev) && !isSpace(ch)) out += JOINER;
        out += ch;
        prev = ch;
      });
      return out;
    });
  }

  function keepWords(text) { return keepWordsParts([text])[0]; }

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

  /** 동봉한 글꼴 폴더. 이 스크립트 주소에서 찾는다 — 관리자 주소가 바뀌어도 따라간다. */
  function fontBase() {
    var script = document.currentScript || document.querySelector('script[src*="notice-preview.js"]');
    var src = script && script.src ? script.src : '/admin/js/notice-preview.js';
    return src.replace(/js\/notice-preview\.js.*$/, 'vendor/fonts/');
  }
  var FONT_BASE = fontBase();

  function injectStyles() {
    if (document.getElementById('np-styles')) return;
    var c = APP.color;
    var face = function (weight, file) {
      return '@font-face{font-family:"ElumPretendard";font-weight:' + weight + ';font-style:normal;font-display:block;'
        + 'src:url("' + FONT_BASE + file + '") format("woff")}';
    };
    var css = [
      // 앱과 같은 글꼴 — 폭이 같아야 같은 자리에서 꺾인다. 한글은 KS X 1001 2350자만 담았다(파일 크기).
      face(400, 'Pretendard-Regular.subset.woff'),
      face(500, 'Pretendard-Medium.subset.woff'),
      face(600, 'Pretendard-SemiBold.subset.woff'),
      '.np-page{display:grid;gap:1.5rem;align-items:start}.np-page>*{min-width:0}',
      '@media (min-width:1280px){.np-page{grid-template-columns:minmax(0,1fr) 360px}.np-aside{position:sticky;top:4.5rem}}',
      '.np-frame{position:relative;margin:0 auto;overflow:hidden;border-radius:' + (36 * SCALE) + 'px;',
      '  box-shadow:0 0 0 5px #1f2330,0 8px 24px rgba(0,0,0,.25);width:' + (APP.phoneW * SCALE) + 'px;height:' + (APP.phoneH * SCALE) + 'px}',
      '.np-phone{position:absolute;top:0;left:0;width:' + APP.phoneW + 'px;height:' + APP.phoneH + 'px;transform:scale(' + SCALE + ');',
      '  transform-origin:0 0;background:' + c.screen + ';overflow:hidden;color:' + c.title + ';',
      '  font-family:ElumPretendard,Pretendard,-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Noto Sans KR",sans-serif;',
      '  -webkit-font-smoothing:antialiased;letter-spacing:0}',
      '.np-home{padding:76px 24px 0}',
      '.np-home-line{height:26px;width:55%;border-radius:8px;background:#EEE9E6;margin-bottom:18px}',
      '.np-home-card{height:150px;border-radius:20px;background:#fff;margin-bottom:16px}',
      '.np-dim{position:absolute;inset:0;background:' + c.dim + ';display:flex;align-items:center;justify-content:center}',
      // 카드 — ElumDialogSurface
      '.np-card{box-sizing:border-box;width:' + APP.cardWidth + 'px;max-height:' + (APP.phoneH * APP.cardMaxHeightRatio) + 'px;',
      '  padding:' + APP.padTop + 'px ' + APP.padSide + 'px ' + APP.padBottom + 'px;background:' + c.surface + ';',
      '  border-radius:' + APP.cardRadius + 'px;box-shadow:4px 4px 6px ' + c.shadow + ';display:flex;flex-direction:column}',
      '.np-card.has-image{padding-top:' + APP.padSide + 'px}',
      // 글 자리 — 넘치면 여기만 스크롤 (앱 SingleChildScrollView)
      '.np-scroll{flex:0 1 auto;min-height:0;overflow-y:auto;display:flex;flex-direction:column}',
      '.np-media{flex:none;width:100%;aspect-ratio:' + APP.imageRatio + ';border-radius:' + APP.imageRadius + 'px;overflow:hidden;',
      '  background:' + c.imageEmpty + ';margin-bottom:' + APP.imageToTitle + 'px}',
      '.np-media img{display:block;width:100%;height:100%;object-fit:cover}',
      // 줄바꿈은 끊지 말라는 표시가 정한다. 여기서는 표시가 없는 긴 낱말만 글자에서 끊게 둔다(앱 엔진과 같다).
      '.np-title,.np-body,.np-btn-label,.np-hide-label{white-space:pre-wrap;word-break:normal;overflow-wrap:anywhere;text-align:center}',
      '.np-title{font-size:' + APP.titleSize + 'px;font-weight:' + APP.titleWeight + ';line-height:' + APP.titleLine + ';color:' + c.title + '}',
      '.np-em{color:' + c.emphasis + '}',
      '.np-body{margin-top:' + APP.titleToBody + 'px;font-size:' + APP.bodySize + 'px;font-weight:' + APP.bodyWeight + ';',
      '  line-height:' + APP.bodyLine + ';color:' + c.body + '}',
      // 보지 않기 — 동그란 체크 (`채크_라운드`)
      '.np-hide{flex:none;align-self:center;display:inline-flex;align-items:center;gap:' + APP.checkGap + 'px;margin-top:' + APP.bodyToHide + 'px;',
      '  border:0;background:none;padding:0;cursor:pointer;font:inherit}',
      '.np-hide-label{font-size:' + APP.hideSize + 'px;font-weight:400;line-height:1;color:' + c.hide + '}',
      '.np-check{flex:none;box-sizing:border-box;width:' + APP.checkSize + 'px;height:' + APP.checkSize + 'px;border-radius:50%;',
      '  border:' + (APP.checkSize / 11).toFixed(2) + 'px solid ' + c.checkRing + ';background:' + c.surface + ';display:flex;align-items:center;justify-content:center}',
      '.np-check svg{width:' + (APP.checkSize * 10.91 / 20).toFixed(2) + 'px;height:' + (APP.checkSize * 8.13 / 20).toFixed(2) + 'px;fill:' + c.checkRing + '}',
      '.np-hide.is-on .np-check{background:' + c.primary + ';border-color:' + c.primary + '}',
      '.np-hide.is-on .np-check svg{fill:#fff}',
      // 버튼 — ElumDialogButton. 링크 없으면 닫기 하나가 꽉 차고 주 동작 색
      '.np-actions{flex:none;display:flex;gap:' + APP.buttonGap + 'px;margin-top:' + APP.hideToButtons + 'px}',
      '.np-btn{flex:1 1 0;min-width:0;box-sizing:border-box;min-height:' + APP.buttonHeight + 'px;padding:8px;border:0;cursor:pointer;',
      '  border-radius:' + APP.buttonRadius + 'px;display:flex;align-items:center;justify-content:center}',
      '.np-btn-label{font-size:' + APP.buttonSize + 'px;font-weight:' + APP.buttonWeight + ';line-height:1}',
      '.np-btn.is-primary{background:' + c.primary + ';color:' + c.primaryText + '}',
      '.np-btn.is-neutral{background:' + c.neutral + ';color:' + c.neutralText + '}',
      '.np-empty{position:absolute;left:24px;right:24px;top:45%;text-align:center;font-size:16px;color:#898B98;white-space:pre-line}',
      // 차례 — 휴대폰 틀 **밖**의 관리자용 조작이다. 앱에는 없다.
      '.np-seq{display:flex;align-items:center;justify-content:center;gap:.5rem;margin-top:.75rem;font-size:.8rem}'
    ].join('\n');
    var style = el('style');
    style.id = 'np-styles';
    style.textContent = css;
    document.head.appendChild(style);
  }

  function checkIcon() {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', '0 0 11 9');
    svg.setAttribute('aria-hidden', 'true');
    var path = document.createElementNS(ns, 'path');
    path.setAttribute('d', CHECK_PATH);
    svg.appendChild(path);
    return svg;
  }

  /**
   * 공지 팝업 **하나**를 카드로 그린다 — 앱 NoticePopupCard 와 같은 짜임.
   * 돌려주는 것: 카드와 링크 버튼 글자(편집 화면이 두 줄을 넘는지 잰다).
   */
  function drawCard(slide, hideDays, onNext) {
    var card = el('div', 'np-card');
    card.setAttribute('role', 'dialog');
    card.setAttribute('aria-label', '공지 팝업 미리보기');

    var scroll = el('div', 'np-scroll');
    if (slide.imageUrl) {
      // 그림 있는 공지 — 시안 밖(임시). 앱도 그림을 못 받으면 자리째 없앤다(N3).
      card.classList.add('has-image');
      var media = el('div', 'np-media');
      var img = el('img');
      img.alt = '';
      img.src = slide.imageUrl;
      img.onerror = function () {
        media.remove();
        card.classList.remove('has-image');
      };
      media.appendChild(img);
      scroll.appendChild(media);
    }

    var title = el('div', 'np-title');
    var parts = titleParts(slide.title).parts.filter(function (p) { return !!p.text; });
    var kept = keepWordsParts(parts.map(function (p) { return p.text; }));
    parts.forEach(function (part, i) {
      title.appendChild(part.em ? el('span', 'np-em', kept[i]) : document.createTextNode(kept[i]));
    });
    title.setAttribute('aria-label', parts.map(function (p) { return p.text; }).join(''));
    scroll.appendChild(title);
    var body = el('div', 'np-body', keepWords(slide.body || ''));
    body.setAttribute('aria-label', slide.body || '');
    scroll.appendChild(body);
    card.appendChild(scroll);

    var hide = el('button', 'np-hide');
    hide.type = 'button';
    hide.setAttribute('role', 'checkbox');
    hide.setAttribute('aria-checked', 'false');
    var check = el('span', 'np-check');
    check.appendChild(checkIcon());
    hide.appendChild(check);
    hide.appendChild(el('span', 'np-hide-label', keepWords(hideLabel(hideDays))));
    hide.addEventListener('click', function () {
      var on = !hide.classList.contains('is-on');
      hide.classList.toggle('is-on', on);
      hide.setAttribute('aria-checked', on ? 'true' : 'false');
    });
    card.appendChild(hide);

    // 앱은 https 가 아닌 링크의 버튼을 숨긴다 (N12). 미리보기도 같게.
    var hasLink = !!(slide.buttonLabel && /^https:\/\//.test(slide.buttonUrl || ''));
    var actions = el('div', 'np-actions');
    var close = el('button', 'np-btn ' + (hasLink ? 'is-neutral' : 'is-primary'));
    close.type = 'button';
    close.appendChild(el('span', 'np-btn-label', '닫기'));
    close.addEventListener('click', onNext);
    actions.appendChild(close);
    var linkLabel = null;
    if (hasLink) {
      var link = el('button', 'np-btn is-primary');
      link.type = 'button';
      link.title = slide.buttonUrl;
      linkLabel = el('span', 'np-btn-label', keepWords(slide.buttonLabel));
      link.setAttribute('aria-label', slide.buttonLabel);
      link.appendChild(linkLabel);
      // 앱에서는 브라우저를 열고 닫힌다. 미리보기에서는 다음 공지로 넘어가는 것만 흉내 낸다.
      link.addEventListener('click', onNext);
      actions.appendChild(link);
    }
    card.appendChild(actions);
    return { card: card, linkLabel: linkLabel };
  }

  /**
   * 팝업을 그린다. 공지가 여럿이면 **하나씩 차례로** 뜬다 — 앱과 같다(#390).
   *
   * @param slides   [{title, body, imageUrl, buttonLabel, buttonUrl}] — 앱이 받는 순서 그대로
   * @param hideDays 보지 않기 일수
   * @param index    처음 보여줄 공지
   * @return {linkLabel} 지금 그린 공지의 링크 버튼 글자(없으면 null)
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
      return { linkLabel: null };
    }

    var dim = el('div', 'np-dim');
    phone.appendChild(dim);
    var seq = slides.length > 1 ? el('div', 'np-seq') : null;
    if (seq) container.appendChild(seq);

    var current = Math.max(0, Math.min(index || 0, slides.length - 1));
    var result = { linkLabel: null };

    function draw() {
      dim.textContent = '';
      if (current >= slides.length) {
        // 마지막 공지까지 닫았다 — 홈만 남는다
        dim.style.background = 'transparent';
        phone.appendChild(el('div', 'np-empty', '공지를 모두 닫았어요.\n보호자 홈이 보여요.'));
      } else {
        dim.style.background = '';
        var drawn = drawCard(slides[current], hideDays, function () { go(current + 1); });
        dim.appendChild(drawn.card);
        result.linkLabel = drawn.linkLabel;
      }
      if (seq) drawSeq();
    }

    // 휴대폰 틀 밖의 관리자용 조작 — 몇 번째로 뜨는지 보고 앞뒤로 옮겨 본다.
    function drawSeq() {
      seq.textContent = '';
      var prev = el('button', 'btn btn-xs btn-ghost', '앞 공지');
      prev.type = 'button';
      prev.disabled = current === 0;
      prev.addEventListener('click', function () { go(current - 1); });
      var where = current >= slides.length
        ? '모두 닫음'
        : (current + 1) + '/' + slides.length + ' — 닫으면 다음 공지가 이어서 떠요';
      var next = el('button', 'btn btn-xs btn-ghost', current >= slides.length ? '처음부터' : '다음 공지');
      next.type = 'button';
      next.addEventListener('click', function () { go(current >= slides.length ? 0 : current + 1); });
      seq.appendChild(prev);
      seq.appendChild(el('span', null, where));
      seq.appendChild(next);
    }

    function go(i) {
      if (i < 0 || i > slides.length) return;
      var empty = phone.querySelector('.np-empty');
      if (empty) empty.remove();
      current = i;
      draw();
    }

    draw();
    return result;
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
      var drawn = renderPopup(container, slides, data.hideDays, index);
      // 버튼 문구는 두 줄까지가 보기 좋다(#390 R2). 넘어도 잘리지는 않지만 버튼이 커진다.
      if (drawn.linkLabel && drawn.linkLabel.offsetHeight > APP.buttonSize * 2 + 1) {
        messages.push('버튼 문구가 두 줄을 넘어요. 짧게 줄이면 버튼이 다른 팝업과 같은 크기로 떠요.');
      }
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
    [platformSelect, removeImage].forEach(function (input) {
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

  // ── 저장하면 어떻게 되는지 (#385 E) ─────────────────────────
  //
  // 켜 둔 채 저장하면 곧바로 보호자 모두에게 나가는데, 화면은 꺼 둔 채일 때만 말하고 있었다.
  // 미리보기와 따로 둔다 — 미리보기 그리기가 깨져도 이 안내와 확인은 돌아야 한다.

  // 게시 기간 판단에 쓰는 지금 시각. 서버가 실어 준 시각을 기준으로 흐른 만큼 더한다 —
  // 관리자 PC 시계가 틀려도 앱 API(서버 시계)와 같은 판단을 한다. 없으면 PC 시계.
  var clockOffset = (function () {
    var serverNow = readData().serverNow;
    return serverNow === null ? 0 : serverNow - Date.now();
  })();

  function nowMillis() {
    return Date.now() + clockOffset;
  }

  // datetime-local 칸 값(한국 시각, 'YYYY-MM-DDTHH:mm')을 시각으로. 한국은 서머타임이 없어 +09:00 고정.
  function kstMillis(value) {
    var m = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})/.exec(value || '');
    return m ? Date.parse(m[1] + ':00+09:00') : NaN;
  }

  function kstLabel(value) {
    var m = /^\d{4}-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(value || '');
    return m ? Number(m[1]) + '월 ' + Number(m[2]) + '일 ' + m[3] + ':' + m[4] : value;
  }

  // 누구에게 가는지. 플랫폼을 좁혔으면 그 휴대폰 보호자만이다.
  function audience(platform) {
    if (platform === 'IOS') return 'iOS 보호자 모두에게';
    if (platform === 'ANDROID') return 'Android 보호자 모두에게';
    return '보호자 모두에게';
  }

  /**
   * 지금 입력대로 저장하면 어떻게 되는지.
   * kind: off · stop · live · scheduled · ended · invalid · unknown
   * 서버 판단(NoticeStatus.of)과 같은 규칙이다 — 시작은 그 순간부터, 종료는 그 순간부터 빠진다.
   */
  function publishOutcome(input) {
    var who = audience(input.platform);
    if (!input.enabled) {
      return input.wasLive
        ? { kind: 'stop', text: '꺼 둔 채 저장하면 다음에 앱을 켜는 보호자부터 안 보여요.' }
        : { kind: 'off', text: '꺼 둔 채라 저장해도 앱에는 아직 나가지 않아요.' };
    }
    var start = kstMillis(input.startsAt);
    var end = input.endsAt ? kstMillis(input.endsAt) : null;
    if (isNaN(start) || (end !== null && isNaN(end))) {
      return { kind: 'unknown', text: '켜 둔 채라 저장하면 게시 기간에 맞춰 ' + who + ' 보여요.' };
    }
    if (end !== null && end <= start) {
      return { kind: 'invalid', text: '종료가 시작보다 빨라요. 이대로는 저장되지 않아요.' };
    }
    var now = nowMillis();
    if (end !== null && end <= now) {
      return { kind: 'ended', text: '종료 시각이 지나 켜 둬도 앱에는 나가지 않아요.' };
    }
    if (start > now) {
      return {
        kind: 'scheduled',
        text: '켜 둔 채라 게시 시작 시각(' + kstLabel(input.startsAt) + ')부터 ' + who + ' 보여요.'
      };
    }
    if (input.wasLive) {
      // 이미 나가고 있는 공지를 고치는 중. 보지 않기로 숨긴 보호자에게 다시 뜨는지는 "다시 보이게"가 정한다.
      return {
        kind: 'live',
        text: '게시 중이라 저장하면 고친 내용이 바로 보여요. '
          + (input.bumpRevision ? '숨긴 보호자에게도 다시 떠요.' : '보지 않기로 숨긴 보호자에게는 다시 뜨지 않아요.')
      };
    }
    return { kind: 'live', text: '켜 둔 채라 저장하면 바로 ' + who + ' 보여요. 다음에 앱을 켜는 보호자부터 떠요.' };
  }

  function initPublishNote(form) {
    var note = document.getElementById('notice-publish-note');
    var enabled = document.getElementById('notice-enabled');
    var startsAt = document.getElementById('notice-starts-at');
    var endsAt = document.getElementById('notice-ends-at');
    var platform = document.getElementById('notice-platform');
    var bump = form.querySelector('[name="bumpRevision"]');
    var wasLive = form.getAttribute('data-was-live') === 'true';

    function current() {
      return publishOutcome({
        enabled: !!(enabled && enabled.checked),
        startsAt: startsAt ? startsAt.value : '',
        endsAt: endsAt ? endsAt.value : '',
        platform: platform ? platform.value : 'ALL',
        bumpRevision: !!(bump && bump.checked),
        wasLive: wasLive
      });
    }

    function update() {
      if (note) note.textContent = current().text;
    }

    [enabled, startsAt, endsAt, platform, bump].forEach(function (input) {
      if (!input) return;
      input.addEventListener('input', update);
      input.addEventListener('change', update);
    });

    // 나가고 있지 않던 공지가 이 저장으로 곧바로 나가게 될 때만 한 번 묻는다. 게시 중인 공지의
    // 오타 수정·예약 공지 저장까지 매번 물으면 확인 창을 읽지 않고 누르는 버릇이 든다.
    form.addEventListener('submit', function (event) {
      var outcome = current();
      if (outcome.kind === 'live' && !wasLive
        && !window.confirm('저장하면 바로 ' + audience(platform ? platform.value : 'ALL')
          + ' 보여요. 다음에 앱을 켜는 보호자부터 떠요. 저장할까요?')) {
        event.preventDefault();
      }
    });

    update();
  }

  // 목록의 "켜기" — 게시 기간 안이라 누르는 순간 나가는 줄만 묻는다. 판단은 서버가 했다(data-goes-live).
  function initEnableConfirm() {
    document.querySelectorAll('form[data-notice-enable]').forEach(function (form) {
      form.addEventListener('submit', function (event) {
        if (form.getAttribute('data-goes-live') !== 'true') return;
        var title = (form.getAttribute('data-title') || '').split('**').join('');
        if (!window.confirm("'" + title + "' 공지를 켜면 바로 " + audience(form.getAttribute('data-platform'))
          + ' 보여요. 켤까요?')) {
          event.preventDefault();
        }
      });
    });
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
    try {
      var form = document.getElementById('notice-form');
      if (form) initPublishNote(form);
    } catch (e) {
      // 안내 줄은 서버가 그려 둔 글 그대로 남는다. 원인은 콘솔에 남긴다.
      if (window.console) console.error('[공지 편집] 저장 안내를 고치지 못했어요 (E-NTC-JS)', e);
    }
    initEnableConfirm();
    initDeleteConfirm();
  });

  // 테스트나 콘솔에서 쓸 수 있게 드러낸다.
  window.ElumNoticePreview = {
    renderPopup: renderPopup, titleParts: titleParts, publishOutcome: publishOutcome, APP: APP
  };
})();
