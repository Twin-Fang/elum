#!/usr/bin/env bash
#
# 관리자 화면 CSS를 다시 만든다 (이슈 #248).
#
#   bash server/tool/build-admin-css.sh
#
# ## 언제 돌려야 하나
#
# **템플릿에 새 Tailwind 클래스를 쓴 뒤.** 이 CSS는 templates/ 를 훑어
# 실제로 쓰인 클래스만 담는다. 그래서 파일이 71KB로 작다 — 전체를 담으면 3MB가 넘는다.
#
# 뒤집어 말하면 **새 클래스를 써도 이 스크립트를 돌리지 않으면 먹지 않는다.**
# 스타일이 안 먹는 것 같으면 여기부터 의심한다.
#
# ## 왜 CDN을 쓰지 않나
#
# `cdn.tailwindcss.com`은 브라우저에서 컴파일하는 개발용 빌드다. 콘솔에 프로덕션
# 경고가 뜨고, 스타일이 적용되기 전 화면이 한 번 깜빡인다. 외부 CDN이 막히면
# 관리자 화면이 스타일 없이 뜬다.
#
# ## 빌드 도구를 레포에 넣지 않는다
#
# package.json 없이 npx로 그때만 받아 쓴다. 관리자 CSS 하나 때문에 서버 저장소에
# 노드 의존성을 들이지 않는다.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/src/main/resources/static/admin/vendor/admin.css"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/input.css" <<'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* 이룸 브랜드 주황 — daisyUI 기본 primary를 덮어쓴다. */
[data-theme="light"] {
  --p: 76.9% 0.188 70.08;
  --pc: 20% 0.04 70;
}

/* 좁은 칸에서 배지 글자가 세로로 쪼개진다. 한국어 두 글자짜리 상태값
   (활성·정지·성공·실패)이 "활/성"으로 갈라져 읽히지 않았다. */
.badge {
  white-space: nowrap;
}

/* 표는 좁은 화면에서 가로로 스크롤한다 (모든 표가 이미 overflow-x-auto 안에 있다).
   억지로 칸에 욱여넣게 두면 숫자까지 세로로 쪼개진다 — 별 개수 14가 "1/4"로 갈라졌다.
   긴 이메일은 줄바꿈을 허용하되, 숫자·배지처럼 쪼개지면 뜻이 달라지는 값은 붙여 둔다. */
.table td,
.table th {
  white-space: nowrap;
}
.table td.wrap-anywhere {
  white-space: normal;
  overflow-wrap: anywhere;
}
CSS

cat > "$WORK/tailwind.config.js" <<CONFIG
module.exports = {
  content: ['$ROOT/src/main/resources/templates/**/*.html'],
  plugins: [require('daisyui')],
  daisyui: { themes: ['light', 'dark'], logs: false },
};
CONFIG

cd "$WORK"
npm install -D tailwindcss@3 daisyui@4 >/dev/null 2>&1
npx tailwindcss -i input.css -o admin.css --minify

cp admin.css "$OUT"
echo "생성: $OUT ($(du -h "$OUT" | cut -f1))"
