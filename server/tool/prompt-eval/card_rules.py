"""행동카드 채점: 앱 규칙 + 입력별 기대 + 그림 가이드 > 문제 목록

fail: 쓰면 안 되는 카드 (요청 누락, 위험, 개인정보, 진단명, 10장 초과)
warn: 보호자가 고쳐야 할 카드 (길이, 어미, 행동 연결, 그림 가이드 위험)
"""
import re

import lib

MAXIMUM_STEP_COUNT = 10
# 보호자가 많이 적어도 간소화해야 하는 기준. 8장부터 경고
NORMAL_STEP_COUNT = 7
MAXIMUM_TITLE_WORDS = 4
MAXIMUM_DESCRIPTION_LENGTH = 16
MAXIMUM_IMAGE_GUIDE_WORDS = 25

# 진단명·전문어: 카드에 나오면 안 됨 (입력에 있어도)
BANNED_CARD_TERMS = re.compile(r"자폐|장애|ADHD|진단|발달|치료|중재|강화물|훈육|문제\s?행동")
# 호칭: '아이스크림' 같은 낱말은 제외
CHILD_TERMS = re.compile(r"(?<![가-힣])아이(?:가|는|를|의|도|에게|랑|와)?(?=\s|$|[.,!?])|우리 애|아동")
VAGUE_ADVERBS = re.compile(r"(?<![가-힣])(잘|적절히|알아서|조심히|예쁘게|얌전히|똑바로)(?=\s)")
NEGATIVE_WORDS = re.compile(r"(?<![가-힣])(안|못)\s|않아요|말아요|하지\s?마|안돼|안 돼")
# 한 문장에 동작 둘: 인용 '~라고' 제외
ACTION_CHAINING = re.compile(r"(?<!라)고\s|[아어해]서\s|한\s뒤|하면서|(?<=[가-힣])며\s|,|\s때\s")
NON_KOREAN_LETTERS = re.compile(r"[぀-ヿ一-鿿]")
LATIN_LETTERS = re.compile(r"[A-Za-z]")
HANGUL_LETTERS = re.compile(r"[가-힣]")

GUIDE_OTHER_BEINGS = re.compile(
    r"\b(mother|mom|father|dad|parent|teacher|doctor|nurse|dentist|friend|person|people|adult|grandmother|grandma|"
    r"grandfather|driver|staff|stranger|dog|puppy|cat|kitten|classmate|child|children|boy|girl|man|woman)\b", re.I)
GUIDE_TEXT_TRIGGERS = re.compile(
    r"\b(exit|sign|label|menu|clock|title|card|ticket|number|letter|word|text|book cover|calendar|poster|"
    r"receipt|screen|phone|tablet)\b", re.I)
GUIDE_BACKGROUND = re.compile(
    r"\b(room|classroom|school(?! ?bag| ?backpack)|hospital|park|road|street|kitchen|bathroom|outside|house|"
    r"building|store|subway station|playground)\b", re.I)
GUIDE_INVISIBLE_ACTIONS = re.compile(
    r"\b(feels?|calms?|happy|sad|angry|understands?|remembers?|thinks?|waits?|learns?|knows?|decides?|tries|"
    r"swallows?|asks?|asking|listens?|looks? at)\b", re.I)
GUIDE_SEQUENCE = re.compile(r"\b(then|after|before|next|finally)\b", re.I)
GUIDE_PASSIVE_OTHER = re.compile(r"\b(is|are) (placed|held|handed|given|put)\b", re.I)
# 물건을 들고만 있는 정지 자세: 동작이 그림에 안 보임
GUIDE_STATIC_HOLD = re.compile(r"^The character (stands and |sits and )?(holds|keeps|has)\b(?!.*\b(and|while)\b)", re.I)
# 보호자가 말하지 않은 채우기 카드
FILLER_TITLES = re.compile(r"계속|제자리|원래 자리|내려놓")
NEIGHBOR_SIMILARITY_LIMIT = 0.55
GUIDE_DANGER = re.compile(r"\b(knife|blade|fire|flame|stove|blood|needle|syringe|injection)\b", re.I)


def contains_any(text: str, keywords: list) -> bool:
    return any(keyword in text for keyword in keywords)


def _first_position(steps: list, keywords: list) -> int:
    """키워드가 처음 나온 카드 번호 (없으면 -1)"""
    for position, step in enumerate(steps):
        if contains_any(f"{step.get('title', '')} {step.get('description', '')}", keywords):
            return position
    return -1


def _grade_structure(card: dict, may_be_empty: bool) -> list:
    """앱 규칙: 장수, 제목, 설명, 낱말"""
    steps = card.get("steps") or []
    issues = []
    if not steps and not may_be_empty:
        issues.append(("fail", "카드없음", "steps 비어 있음"))
    if len(steps) > MAXIMUM_STEP_COUNT:
        issues.append(("fail", "10장초과", f"{len(steps)}장: 서버가 ROUTINE_STEP_LIMIT_EXCEEDED 로 거절"))
    elif len(steps) > NORMAL_STEP_COUNT:
        issues.append(("warn", "장수많음", f"{len(steps)}장: 간소화 대상"))
    if not (card.get("title") or "").strip():
        issues.append(("fail", "일과제목없음", ""))
    seen_titles = set()
    catalog = set(lib.pictogram_ids())
    for step in steps:
        title, description = step.get("title", ""), step.get("description", "")
        if not title.strip():
            issues.append(("fail", "카드제목없음", description))
        if len(title.split()) > MAXIMUM_TITLE_WORDS:
            issues.append(("warn", "제목김", title))
        if not title.endswith("요"):
            issues.append(("warn", "제목어미", title))
        if not description.endswith("요"):
            issues.append(("warn", "설명어미", description))
        if len(description) > MAXIMUM_DESCRIPTION_LENGTH:
            issues.append(("warn", "설명김", f"{len(description)}자: {description}"))
        if ACTION_CHAINING.search(description + " "):
            issues.append(("warn", "행동연결", description))
        if VAGUE_ADVERBS.search(f"{title} {description} "):
            issues.append(("warn", "모호한부사", f"{title} / {description}"))
        if NEGATIVE_WORDS.search(f"{title} {description} "):
            issues.append(("warn", "부정형", f"{title} / {description}"))
        if title in seen_titles:
            issues.append(("warn", "제목중복", title))
        seen_titles.add(title)
        picture_id = step.get("pictogramId")
        if picture_id and picture_id not in catalog:
            issues.append(("warn", "없는픽토그램", picture_id))
    return issues


def _grade_language(case: dict, card: dict) -> list:
    """글자 섞임, 진단명, 호칭 (보호자가 직접 쓴 장소 이름 '치료실'은 허용, 지어낸 '치료'만 금지)"""
    issues = []
    texts = [card.get("title", "")]
    for step in card.get("steps") or []:
        texts += [step.get("title", ""), step.get("description", "")]
    for text in texts:
        if NON_KOREAN_LETTERS.search(text):
            issues.append(("fail", "한자일본어", text))
        if LATIN_LETTERS.search(text):
            issues.append(("warn", "영어섞임", text))
        banned = BANNED_CARD_TERMS.search(text)
        if banned and not (banned.group(0) == "치료" and "치료실" in text and "치료실" in case.get("text", "")):
            issues.append(("fail", "금지어", text))
        if CHILD_TERMS.search(text + " "):
            issues.append(("warn", "호칭", text))
    return issues


def _grade_expectations(case: dict, card: dict) -> list:
    """입력별 기대: 꼭 들어갈 행동, 나오면 안 되는 말, 순서, 장수 상한"""
    steps = card.get("steps") or []
    korean_text = " ".join(
        [card.get("title", "")] + [f"{step.get('title', '')} {step.get('description', '')}" for step in steps])
    issues = []
    for keywords in case.get("must", []):
        if not contains_any(korean_text, keywords):
            issues.append(("fail", "요청누락", "/".join(keywords)))
    for step in steps:
        match = FILLER_TITLES.search(step.get("title", ""))
        if match and match.group(0) not in case.get("text", ""):
            issues.append(("warn", "채우기카드", step.get("title", "")))
    for keyword in case.get("must_not", []):
        if keyword in korean_text:
            issues.append(("fail", "나오면안됨", keyword))
    # 말린 행동을 시키는 문장 (빈칸 차이 무시)
    spaceless_text = korean_text.replace(" ", "")
    for sentence in case.get("forbidden_actions", []):
        if sentence.replace(" ", "") in spaceless_text:
            issues.append(("fail", "말린행동", sentence))
    for keyword in case.get("pii", []):
        if keyword in korean_text:
            issues.append(("fail", "개인정보노출", keyword))
    for earlier, later in case.get("order", []):
        earlier_position, later_position = _first_position(steps, earlier), _first_position(steps, later)
        if earlier_position >= 0 and later_position >= 0 and earlier_position > later_position:
            issues.append(("fail", "순서틀림", f"{'/'.join(earlier)} > {'/'.join(later)}"))
    if case.get("max_steps") and len(steps) > case["max_steps"]:
        issues.append(("warn", "간소화부족", f"{len(steps)}장 > 기대 {case['max_steps']}장"))
    return issues


def _grade_image_guides(case: dict, card: dict) -> list:
    """그림 가이드(imagePromptEn): 서버 스키마 규칙 + 글자·사람 그림이 되는 낱말"""
    issues = []
    previous_words = set()
    for step in card.get("steps") or []:
        guide = (step.get("imagePromptEn") or "").strip()
        if not guide:
            issues.append(("fail", "그림가이드없음", step.get("title", "")))
            continue
        if not guide.startswith("The character"):
            issues.append(("warn", "그림시작어", guide))
        if len(guide.split()) > MAXIMUM_IMAGE_GUIDE_WORDS:
            issues.append(("warn", "그림가이드김", f"{len(guide.split())}단어: {guide}"))
        if HANGUL_LETTERS.search(guide):
            issues.append(("warn", "그림한글", guide))
        checks = (
            (GUIDE_OTHER_BEINGS, "그림다른사람"), (GUIDE_TEXT_TRIGGERS, "그림글자위험"), (GUIDE_BACKGROUND, "그림배경"),
            (GUIDE_INVISIBLE_ACTIONS, "그림안보이는행동"), (GUIDE_SEQUENCE, "그림연속동작"), (GUIDE_DANGER, "그림위험물"),
            (GUIDE_PASSIVE_OTHER, "그림남이해줌"), (GUIDE_STATIC_HOLD, "그림정지자세"),
        )
        for pattern, code in checks:
            match = pattern.search(guide)
            if match:
                issues.append(("warn", code, f"{match.group(0)}: {guide}"))
        if guide.lower() and previous_words:
            words = set(guide.lower().split())
            if len(words & previous_words) / len(words | previous_words) > NEIGHBOR_SIMILARITY_LIMIT:
                issues.append(("warn", "그림이웃비슷", guide))
        previous_words = set(guide.lower().split())
        for keyword in case.get("image_must_not", []):
            if keyword.lower() in guide.lower():
                issues.append(("fail", "그림나오면안됨", f"{keyword}: {guide}"))
    return issues


def grade_card(case: dict, card: dict) -> dict:
    """카드 1벌 채점 > 판정(pass/warn/fail) + 문제 목록"""
    issues = (_grade_structure(card, case.get("may_be_empty", False)) + _grade_language(case, card)
              + _grade_expectations(case, card) + _grade_image_guides(case, card))
    levels = {level for level, _, _ in issues}
    verdict = "fail" if "fail" in levels else "warn" if "warn" in levels else "pass"
    return {"verdict": verdict, "issues": [{"level": level, "code": code, "detail": detail}
                                           for level, code, detail in issues]}
