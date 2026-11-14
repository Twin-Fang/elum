# 동의 문서 번역 (en · ja · zh · es)

동의 문서 5종의 영어·일본어·중국어(간체)·스페인어 번역본이다 (#1379).

| 파일 | 내용 |
| --- | --- |
| `{en,ja,zh,es}/terms.txt` | 서비스 이용약관 |
| `{en,ja,zh,es}/privacy.txt` | 개인정보 수집·이용 |
| `{en,ja,zh,es}/overseas.txt` | 개인정보 국외 이전 |
| `{en,ja,zh,es}/age.txt` | 만 14세 이상 확인 |
| `{en,ja,zh,es}/marketing.txt` | 서비스 소식 받기 |
| `labels.json` | 언어·항목별 화면 제목(`label`)과 한 줄 설명(`summary`) |

- 원본: `server/src/main/resources/consent/*.txt` (한국어, 법적 효력 있는 원문), 제목·설명은 `ConsentKey.java`
- **AI 번역본이다. 전문가(법률·번역) 검토 전이므로 그대로 게시하지 않는다.**
- 용어는 `docs/i18n/glossary.md` 를 따른다 (이룸이 = Elumi, 보호자 = guardian · 保護者 · 监护人 · tutor)
- 한국 법령·기관명·법률 용어는 첫 등장 시 한국어 원어를 괄호로 남긴다
  (예: `Personal Information Protection Act of Korea (개인정보 보호법)`)

## 게시

서버가 자동으로 넣지 않는다 (#531). 검토가 끝나면 **관리자 화면 > 동의 문서**에서 언어(locale)별로
본문을 붙여 넣고 게시한다.
그 언어 게시본이 없으면 앱은 한국어 본문을 받는다 (`isFallbackLocale: true`). 원문(한국어)을 고치면 번역본도 함께 다시 맞춘다.

## 우선 언어 조항

모든 번역본 끝에 "편의를 위한 번역이며, 한국어판과 다르면 한국어판이 우선한다"는 문장을
그 언어로 붙였다. 지우지 않는다.
