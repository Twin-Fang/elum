# 스토어 등록정보 기준

Google Play 와 App Store 에 올라가는 문구의 기준이다. **스토어 문구를 고치기 전에 읽는다.**

## 문구는 어디에 있나 (#1351)

| 무엇 | 위치 |
|---|---|
| **원본** (5개 언어 ko·en·ja·zh·es) | [`listing/<언어>/`](./listing/) |
| 검색어 묶음 (원본을 쓸 때 기준) | [`search-keywords.md`](./search-keywords.md) |
| 생성 + 검사 스크립트 | [`build_store_metadata.py`](./build_store_metadata.py) |
| 배포가 읽는 생성본 (손으로 고치지 않는다) | `client/ios/fastlane/metadata/<로케일>/`, `client/android/fastlane/metadata/android/<로케일>/` |

```bash
python3 docs/store/build_store_metadata.py          # 원본 고친 뒤 생성 (검사 실패 시 생성 안 함)
python3 docs/store/build_store_metadata.py --check  # 생성본이 원본과 같은지 확인
```

원본 파일 한 언어분.

| 파일 | 들어가는 곳 | 한도 |
|---|---|---|
| `ios_name.txt` | App Store 이름 | 30 |
| `ios_subtitle.txt` | App Store 부제 | 30 |
| `ios_keywords.txt` | App Store 키워드 (쉼표, 공백 없이) | 100 |
| `ios_promotional_text.txt` | App Store 프로모션 문구 | 170 |
| `play_title.txt` | Play 앱 이름 | 30 |
| `play_short_description.txt` | Play 간단한 설명 | 80 |
| `description.txt` | Play 자세한 설명 = App Store 설명 앞부분 | 4000 |
| `ios_subscription_notice.txt` | App Store 설명 끝 구독 안내 (EULA 링크 필수, #1081) | 설명과 합쳐 4000 |
| `ios_release_notes.txt` | 한국어 외 언어의 App Store 새로운 기능 고정 문구 (한국어는 CHANGELOG) | 4000 |

## 스크린샷 (#1369)

- 문구 원본 `promo/copy.{ko,en}.json` → `python3 -I promo/render_store_images.py --to-play-metadata --to-ios-metadata` (playwright·Pillow 필요)
- **Play**: 휴대폰 스크린샷·대표 그래픽(ko-KR·en-US)이 배포 때 자동으로 바뀐다. ja·zh·es 는 기본 언어(ko) 이미지가 보인다
- **App Store**: `--to-ios-metadata` 로 6.9형(ko·en-US)을 `client/ios/fastlane/screenshots/` 에 두면 배포 때 **iPhone 세트만** 비우고 새로 올린다 (Fastfile `clear_iphone_screenshot_sets`). iPad 스크린샷은 건드리지 않는다 — deliver 의 `overwrite_screenshots` 는 iPad 까지 지워 쓰지 않는다
- 첫 두 장의 큰 글씨에 검색어(`행동카드 만들기`, `발달장애·ADHD`)를 둔다. 검색 결과에서 이름 다음으로 보이는 글이다

## 반영 시점

- **배포(deploy) 때 자동으로 올라간다.** iOS `deliver` 가 이름·부제·키워드·설명·프로모션 문구·방침 주소를, Play `supply` 가 제목·간단한 설명·자세한 설명을 올린다.
- **콘솔에서 직접 고치면 다음 배포가 레포 문구로 덮는다.** 고칠 때는 원본을 고친다.
- App Store 이름·부제·키워드·설명은 **새 버전 제출 때만** 바뀐다. 프로모션 문구는 출시본에서도 바뀐다.
- Play 는 저장 즉시 구글 검토로 넘어간다(관리형 게시 꺼짐).
- ja·zh·es 는 **앱 화면은 닫혀 있고 스토어 문구만** 있다. 그 나라 검색에 걸리게 하려는 것이다. 번역은 원어민 검수 전이다.

## 지켜야 할 것

1. **검색어는 사람들이 실제로 치는 말로 쓴다.** `행동카드`(붙여 씀)와 `행동 카드`를 둘 다 쓰고, 대상(발달장애·자폐·ADHD·학습장애·지적장애)·현장(특수학교·특수교육·치료실·ABA)·쓰임(만들기·교육·학습도구)을 넣는다. 다른 언어는 번역이 아니라 그 나라 검색어(`search-keywords.md`)로 쓴다.
2. **효과를 약속하는 문장은 쓰지 않는다.** `치료해요` `증상이 좋아져요` `효과가 있어요` 같은 문장은 심사 반려·광고 규제로 이어진다. `build_store_metadata.py` 가 막는다.
   - 2026-11-13 바뀜(#1351): 예전에는 `치료`·`교육`·`아동` 같은 단어 자체를 금지했다. 앱 화면에는 나오지 않는 말이므로 **스토어 검색용으로는 쓴다** — 키워드 칸, 그리고 설명에서 대상·현장을 말할 때("특수학교·치료실 선생님도 쓰는").
   - Google Play 태그에 `의료`를 고르지 않는다.
3. **Play 설명에 검색어를 나열하지 않는다.** Play 정책은 반복·나열된 키워드를 금지한다. 문장 안에 자연스럽게 넣는다. 나열은 App Store 키워드 칸에만.
4. **App Store 키워드는 이름·부제에 이미 있는 말을 빼고** 100자를 채운다(Apple 이 세 칸을 합쳐 검색한다).
5. 진단명을 묻거나 모은다는 말을 쓰지 않는다. 카드를 만들 때 적은 내용이 AI 로 간다는 것과 개인정보를 적지 말라는 안내를 둔다.
6. App Store 설명에는 **모든 언어에** 구독 안내(EULA 링크)를 둔다. 없으면 가이드라인 3.1.2 로 반려된다(#1081).

## Play 고정 값 (콘솔에서만 고침)

| 항목 | 값 |
|---|---|
| 카테고리 | 교육 |
| 태그 | 교육, 생산성, 육아, 자기 계발, 학습 가이드 (최대 5개, 구글 고정 목록) |

## 검색 노출에 대해

- 문구는 검색어에 **걸릴 자격**을 만든다. 순위는 설치 수·평점·유지율이 가장 크게 좌우한다.
- "이룸" 한 단어는 같은 이름의 앱이 많아 설치가 쌓여야 올라온다. 그래서 이름 뒤에 `행동카드 만들기` 같은 검색어를 붙였다.
- "행동카드" 단독 검색은 카드 게임·결제 앱과 섞인다. 대상(발달장애·ADHD)과 현장(특수교육·ABA)을 함께 쓴다.
