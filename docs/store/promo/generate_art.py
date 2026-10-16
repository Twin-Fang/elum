# 홍보 그림 생성: 프롬프트 + 캐릭터 참조 그림 > PNG (gemini-2.5-flash-image, 장당 약 $0.039)
# 사용: python3 -I generate_art.py <출력.png> <비율 16:9|1:1> <프롬프트.txt> <참조.png...>
# 키는 로컬 서버 설정(git 제외)에서 읽음 — 명령줄·로그에 남기지 않음
import base64, json, pathlib, re, sys, urllib.request
REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
yml = (REPO_ROOT / 'server/src/main/resources/application-prod.yml').read_text()
key = re.search(r'gemini:\s*\n\s*api-key:\s*(\S+)', yml).group(1)
out, aspect, prompt_file, *refs = sys.argv[1:]
parts = [{"text": pathlib.Path(prompt_file).read_text()}]
for r in refs:
    parts.append({"inline_data": {"mime_type": "image/png", "data": base64.b64encode(pathlib.Path(r).read_bytes()).decode()}})
body = {"contents": [{"parts": parts}], "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect}}}
req = urllib.request.Request('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent',
    data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": key})
try:
    res = json.load(urllib.request.urlopen(req, timeout=180))
except urllib.error.HTTPError as e:
    print('HTTP', e.code, e.read().decode()[:400]); sys.exit(1)
for c in res.get('candidates', []):
    for p in c.get('content', {}).get('parts', []):
        if 'inlineData' in p:
            pathlib.Path(out).write_bytes(base64.b64decode(p['inlineData']['data'])); print('saved', out); sys.exit(0)
print('no image', json.dumps(res)[:500]); sys.exit(1)
