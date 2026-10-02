# 이룸 (ELUM) 문서

이 폴더는 **개발 기록과 기획 자료**를 모아 둔 곳이에요. 앱을 쓰는 방법은 [도움말](https://twin-fang.github.io/elum/)을 봐 주세요.

> 01~07번 기획 문서는 해커톤 때 쓴 **초안**이에요. 이후 많이 바뀌어서 **지금 동작과 다를 수 있어요.**
> 현재 기준은 아래 "지금 기준이 되는 문서"를 따라 주세요.

## 지금 기준이 되는 문서

| 무엇이 궁금한가요 | 어디를 보나요 |
| --- | --- |
| 앱 사용법, 문의 | [도움말](https://twin-fang.github.io/elum/) |
| 개인정보를 어떻게 다루는지 | [개인정보처리방침](https://twin-fang.github.io/elum/privacy.html) |
| 화면 문구, 말투, 디자인 규칙 | [08-design-principles.md](./08-design-principles.md) |
| 앱 개발 규칙 | [client/CLAUDE.md](../client/CLAUDE.md) |
| 서버 개발 규칙 | [server/CLAUDE.md](../server/CLAUDE.md) |
| 저장소 공통 규칙, 작업 순서 | [CLAUDE.md](../CLAUDE.md) |

## 초기 기획 기록 (해커톤 초안)

| 문서 | 내용 | 지금과 다른 점 |
| --- | --- | --- |
| [00-one-pager.md](./00-one-pager.md) | 한 장 요약 | 초기 구상 |
| [01-overview.md](./01-overview.md) | 서비스 개요, 대상, 핵심 가치 | 대상을 나이가 아니라 기능 수준으로 정의하게 바뀜 |
| [02-architecture.md](./02-architecture.md) | 시스템 구성, 기술 스택 | AI DLP, 로컬 LLM 구성은 쓰지 않음 |
| [03-screens.md](./03-screens.md) | 화면 흐름과 화면별 명세 | 화면이 여러 번 개편됨 |
| [04-ai-card-generation.md](./04-ai-card-generation.md) | 도움 목표, 프롬프트, 카드 형식 | 프롬프트는 관리자 페이지에서 관리 |
| [05-ai-dlp-gateway.md](./05-ai-dlp-gateway.md) | AI DLP Gateway 설계 | 2026-09-23부터 쓰지 않음(#377) |
| [06-api-spec.md](./06-api-spec.md) | API 초안 | 실제 명세는 서버의 API 문서가 기준 |
| [07-mvp-scope.md](./07-mvp-scope.md) | 해커톤 MVP 범위 | 범위를 넘어 계속 개발 중 |

## 기록 폴더

| 폴더 | 담고 있는 것 |
| --- | --- |
| [meetings/](./meetings/) | 외부 자문과 회의 기록. 기획이 바뀐 근거 |
| [hackathon/](./hackathon/) | 대회 일정, 제출물, 심사 기준 |
| [figma/](./figma/) | 화면별 시안 캡처와 대조 자료 |
| [setup/](./setup/) | 소셜 로그인 설정 기록 |
| [superpowers/](./superpowers/) | 기능별 설계서와 구현 계획 |
| [projectops/](./projectops/) | 이슈 초안, 구현 보고서, 검증 기록 |
| [public-pages/](./public-pages/) | 게시 페이지의 초대 안내 페이지 |
