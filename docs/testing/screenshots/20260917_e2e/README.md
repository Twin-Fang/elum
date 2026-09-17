# 2026-09-17 소셜 로그인 E2E 실측 스크린샷

Android 에뮬레이터(Medium_Phone_API_36.1, Google Play 이미지)에서 릴리스 APK로
카카오 로그인 → 약관 동의 → 온보딩 → 홈까지 실제로 밟으며 남긴 화면이다.
이슈 본문에서 참조하므로 파일명을 바꾸지 않는다.

| 파일 | 장면 |
|---|---|
| `01_consent.png` | 첫 로그인 직후 약관 동의 화면 |
| `02_terms_full.png` | 항목을 눌러 연 약관 전문 (앱 안에서 표시) |
| `03_required_only.png` | 필수만 체크한 상태 — 선택은 비어 있고 CTA는 활성 |
| `04_onboarding_name.png` | 동의 완료 후 이동한 아이 이름 화면 |
| `05_pin_cta_hidden.png` | PIN 재입력 완료 — CTA가 키패드에 가려 보이지 않음 |
| `06_pin_cta_revealed.png` | 키패드를 내려야 드러나는 "맞춤 설정하기" |
| `07_home_fox.png` | 온보딩 직후 홈 — 고른 여우가 보인다 |
| `08_home_cat_after_restart.png` | 앱 재시작 후 같은 계정 홈 — 고양이로 바뀌어 있다 |
| `09_consent_escape_clipped.png` | 동의 화면을 **한 번만** 스크롤한 상태 — 아래에 내용이 더 있다는 단서가 없다 |
| `10_consent_bottom_scrolled.png` | 끝까지 스크롤한 상태 — "다른 계정으로 로그인"이 온전히 보인다 |
| `11_pin_shake_curve.png` | PIN 불일치 흔들림 — 설계 곡선과 60fps 실측 궤적 |
| `12_session_expired_looks_normal.png` | 세션이 완전히 끊긴 상태인데 홈이 정상처럼 보인다 |
| `13_name_carried_over.png` | 다른 계정으로 로그인했는데 이전 아이 이름이 이어붙었다 |
| `14_name_cleared_after_fix.png` | 수정 후 — 이름 입력칸이 비어 있다 |
| `15_session_expired_to_login.png` | 수정 후 — 세션이 끊기면 로그인 화면으로 되돌아간다 |
