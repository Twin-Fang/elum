# 이룸 소개 사이트 (elum.suhsaechan.kr)

앱 소개, 행동 카드 안내 글, 개인정보처리방침, 계정 삭제 안내, 초대·연결 링크 페이지를 싣는 정적 사이트다.
2026-11-12 에 GitHub Pages(`twin-fang.github.io/elum`)에서 자체 도메인으로 옮겼다 (#1316, #1317).
레포를 private 로 바꿔도 사이트가 내려가지 않는다.

## 구조

```
site/
├── site_config.py      # 주소 · 스토어 링크 · 언어 · 안내 글 목록 (단일 원본)
├── build_site.py       # 생성 진입점
├── site_frame.py       # 공통 틀 (head · 머리 · 바닥 · 스토어 버튼)
├── site_home.py        # 첫 화면
├── site_guides.py      # 안내 글 목록 · 글
├── site_schema.py      # 구조화 데이터 (JSON-LD)
├── prepare_images.py   # 원본 그림 > assets/img (원본이 바뀌었을 때만)
├── art/                # 사이트 전용 그림 원본 (이미지 하네스 PNG)
├── content/
│   ├── <언어>.json             # 공통 문구 + 첫 화면
│   └── guides/<글>.<언어>.json  # 안내 글
├── assets/             # site.css · site.js · img/
├── static/             # 손으로 관리하는 페이지 (방침 · 삭제 안내 · 초대 · 연결 · 404)
├── verification/       # 검색엔진 소유 확인 파일 (지우면 확인이 풀린다)
└── synology/           # NAS 컨테이너 설정 · 배포 스크립트
```

- 언어: 한국어(루트 `/`), `en/`, `ja/`, `zh/`, `es/`. 모든 페이지가 서로를 `hreflang` 으로 잇는다.
- 안내 글 주소: `/guide/<글>/`, `/<언어>/guide/<글>/`. 글 조각은 모든 언어가 같은 영문이다.

## 고치는 법

| 하고 싶은 것 | 고칠 곳 |
|---|---|
| 문구 고치기 | `content/<언어>.json`, `content/guides/<글>.<언어>.json` (한국어가 원본, 나머지는 번역) |
| 안내 글 더하기 | `site_config.py` 의 `GUIDE_SLUGS` · `GUIDE_IMAGES` 에 한 줄 + 언어 5개 글 파일 |
| 언어 더하기 | `site_config.py` 의 `LANGUAGES` 에 한 줄 + `content/<언어>.json` + 글 파일 전부 |
| 방침 · 삭제 안내 고치기 | `static/privacy.html`, `static/delete.html` (서버 동의 문서와 맞는지 `tool/check_public_pages.py`) |
| 모양 고치기 | `assets/site.css` (색 · 간격은 앱 디자인 토큰과 같은 값) |

문구 규칙은 스토어 등록정보와 같다 ([docs/store/store-listing.md](../docs/store/store-listing.md)): 효과를 약속하지 않고,
의료를 암시하는 말을 쓰지 않는다. 용어는 루트 `CLAUDE.md` 의 용어 규칙을 따른다.

## 만들기 · 미리 보기

```bash
python3 -I site/build_site.py --out /tmp/elum-site              # 전체
python3 -I site/build_site.py --out /tmp/elum-site --languages ko  # 한 언어만 미리 보기
(cd /tmp/elum-site && python3 -m http.server 8765)               # http://localhost:8765
```

파이썬 표준 라이브러리만 쓴다. 문구 파일이 없거나 깨졌으면 어느 파일인지 알리고 멈춘다.

## 배포 (시놀로지 NAS)

```
브라우저 > Cloudflare DNS (CNAME, DNS 전용) > NAS
  > DSM 리버스 프록시 (80·443) > Traefik localhost:8079 > 컨테이너 elum-site (nginx:1.27-alpine :80)
```

`api.elum.suhsaechan.kr` 백엔드와 같은 경로다. 호스트 포트를 새로 열지 않았다.

| 구성 | 값 |
|---|---|
| DNS (Cloudflare suhsaechan.kr) | `elum` · `www.elum` CNAME, 프록시 꺼짐(DNS 전용), TTL 자동 |
| DSM 리버스 프록시 4개 | `elum` · `www.elum` 각각 443(HSTS, `X-Forwarded-Proto: https`) · 80(`X-Forwarded-Proto: http`) > `http://localhost:8079` (설명 `elum-SITE ...`) |
| 인증서 (Let's Encrypt, DSM 자동 갱신) | `elum.suhsaechan.kr` · `www.elum.suhsaechan.kr` 1장씩, 443 규칙에 각각 연결 |
| Traefik 라우터 | `elum-site` (compose 라벨) |
| NAS 폴더 | `/volume1/projects/elum/site/` — `html/`, `nginx.conf`, `security-headers.inc`, `docker-compose.yml` |

```bash
bash site/synology/deploy_synology.sh   # 레포 루트에서
```

1. `site/build_site.py` 로 사이트 생성
2. `site/verification/*.html` 복사
3. tar 묶음을 ssh 로 보내 NAS 에서 풀고 `html/` 을 NAS 로컬 `rsync --delete` 로 맞춤
4. 공개 주소 5개 상태 코드 출력

- 접속 정보는 레포에 두지 않는다. pro-launch 저장 자격 `synology-chan4760`(`NAS_CRED` 로 변경)에서 읽는다.
- html 은 읽기 전용 바인드 마운트라 컨테이너 재시작이 필요 없다.
- NAS 가 맞는 비밀번호도 가끔 거부한다 > 스크립트가 최대 5회 재시도한다.

설정을 바꿨을 때는 스크립트로 올린 뒤 NAS 에서:

```bash
# nginx 설정만 바뀜
sudo /usr/local/bin/docker exec elum-site nginx -t && sudo /usr/local/bin/docker exec elum-site nginx -s reload
# compose(이미지 · 라벨 · 볼륨) 바뀜
cd /volume1/projects/elum/site && sudo /usr/local/bin/docker compose -p elum-site up -d
```

## 확인

```bash
curl -sI https://elum.suhsaechan.kr/                 # 200
curl -sI https://elum.suhsaechan.kr/privacy.html     # 200 (스토어 등록 주소)
curl -sI https://elum.suhsaechan.kr/delete.html      # 200 (Google Play 필수)
curl -sI https://elum.suhsaechan.kr/없는주소           # 404
curl -sI https://www.elum.suhsaechan.kr/             # 301 > https://elum.suhsaechan.kr/
curl -sI http://elum.suhsaechan.kr/                  # 301 > https
```

## 옛 주소 (twin-fang.github.io/elum)

- 옛 버전 앱이 만든 초대·연결 링크와 스토어에 등록된 주소가 옛 주소를 가리킨다. 끊지 않는다.
- 사본은 `Twin-Fang/twin-fang.github.io` 의 `elum/` 폴더에 있다 (이 레포를 private 로 바꿔도 남는다).
- 앱은 초대·연결 링크로 새 주소와 옛 주소를 둘 다 받는다 (`client/lib/features/profile/domain/invite_link.dart`).

## 되돌리기 (사이트 내리기)

```bash
cd /volume1/projects/elum/site && sudo /usr/local/bin/docker compose -p elum-site down
```

DSM 리버스 프록시 4개(설명 `elum-SITE`) · 인증서 2개 · Cloudflare CNAME 2개는 각 관리 화면에서 지운다.
