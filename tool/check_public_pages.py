#!/usr/bin/env python3
"""게시된 공개 페이지와 서버 동의 문서가 어긋나지 않는지 본다.

**왜 필요한가.** 방침이 두 곳에 산다 — 게시 페이지(`gh-pages`)와 서버가 들고 있는
동의 문서(`server/src/main/resources/consent/`). 한쪽만 고치면 조용히 어긋난다.
실제로 그렇게 어긋났다: 지원 페이지는 "원문은 따로 보관하지 않아요"라고 적어 두었는데
서버는 원문을 저장하고 방침에도 보관한다고 적혀 있었다. **같은 사이트의 두 페이지가
개인정보 처리에 대해 서로 다른 말을 했고 그중 하나가 사실과 달랐다** (#288).

사람이 두 곳을 눈으로 맞추는 일은 반드시 빠진다. 그래서 값으로 묻는다.

    python3 tool/check_public_pages.py              # 게시된 주소를 받아 본다
    python3 tool/check_public_pages.py --dir <경로>  # 로컬 gh-pages 작업본을 본다

어긋나면 종료 코드 1이다.
"""

from __future__ import annotations

import argparse
import html
import pathlib
import re
import sys
import urllib.request

BASE = "https://twin-fang.github.io/elum"
CONSENT = pathlib.Path(__file__).resolve().parent.parent / "server/src/main/resources/consent"

PAGES = ("index.html", "privacy.html", "delete.html")


def strip_tags(raw: str) -> str:
    raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw)))


def load(name: str, local: pathlib.Path | None) -> str | None:
    """페이지 한 장을 읽는다. 없으면 None — 그 자체가 결함일 수 있다."""
    if local:
        f = local / name
        return f.read_text(encoding="utf-8") if f.exists() else None
    try:
        with urllib.request.urlopen(f"{BASE}/{name}", timeout=15) as r:
            return r.read().decode("utf-8")
    except Exception:
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", type=pathlib.Path, help="로컬 gh-pages 작업본 경로")
    args = ap.parse_args()

    pages: dict[str, str] = {}
    problems: list[str] = []

    for name in PAGES:
        raw = load(name, args.dir)
        if raw is None:
            problems.append(f"{name} 가 없다 — 스토어 선언이 이 주소를 가리킨다")
            continue
        pages[name] = strip_tags(raw)

    # 1) 사실과 다른 고지가 남아 있지 않은가.
    #    서버 `Routine.rawInputText` 는 nullable=false 라 원문은 저장된다.
    if "index.html" in pages and "원문은 따로 보관하지 않" in pages["index.html"]:
        problems.append(
            "index.html 이 '원문은 따로 보관하지 않아요'라고 적고 있다 — "
            "서버는 원문을 저장한다. 사실과 다른 고지다"
        )

    # 2) 앱에 없는 것을 수집한다고 적지 않았는가. 소셜 로그인만 지원한다.
    if "privacy.html" in pages and re.search(r"아이디[,·]\s*비밀번호", pages["privacy.html"]):
        problems.append("privacy.html 에 '아이디, 비밀번호' 가 있다 — 자체 로그인이 없다")

    # 3) 서버 동의 문서가 말하는 것을 게시본도 말하는가.
    checks = [
        ("overseas.txt", "privacy.html", "국외", "국외 이전 고지"),
        ("privacy.txt", "privacy.html", "보호책임자", "개인정보 보호책임자"),
    ]
    for src, page, needle, label in checks:
        doc = CONSENT / src
        if not doc.exists() or page not in pages:
            continue
        if needle in doc.read_text(encoding="utf-8") and needle not in pages[page]:
            problems.append(f"서버 문서에는 {label}가 있는데 {page} 에는 없다")

    # 4) 위탁 제공자가 양쪽에 같이 적혀 있는가.
    #    실제로 보내는 곳과 알린 곳이 다르면 그 자체가 지적 사유다.
    doc = CONSENT / "privacy.txt"
    if doc.exists() and "privacy.html" in pages:
        text = doc.read_text(encoding="utf-8")
        for provider in ("Google", "OpenAI"):
            if provider in text and provider not in pages["privacy.html"]:
                problems.append(f"서버 문서에는 {provider} 가 있는데 privacy.html 에는 없다")

    # 5) 삭제 안내가 Play 가 요구하는 것을 담고 있는가.
    if "delete.html" in pages:
        page = pages["delete.html"]
        for needle, label in (
            ("회원탈퇴", "앱 안에서 지우는 경로"),
            ("@", "메일로 요청하는 방법"),
            ("남는", "남는 데이터 설명"),
        ):
            if needle not in page:
                problems.append(f"delete.html 에 {label} 가 없다")

    if problems:
        print("공개 페이지가 어긋난다\n")
        for p in problems:
            print(f"  ⚠️  {p}")
        return 1

    print(f"공개 페이지 {len(pages)}장 — 어긋난 곳 없음")
    return 0


if __name__ == "__main__":
    sys.exit(main())
