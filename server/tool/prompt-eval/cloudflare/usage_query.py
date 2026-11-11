# 오늘(UTC) Workers AI 호출 건별 > neurons, 픽셀, 타일, step, 시간 (분석 토큰 사용)
import json, os, urllib.request
query = """query($account: String!, $start: Time!, $end: Time!) { viewer { accounts(filter: {accountTag: $account}) {
  aiInferenceAdaptive(limit: 1000, filter: {datetime_geq: $start, datetime_leq: $end}, orderBy: [datetime_ASC]) {
    datetime modelId neurons processedPixels processedTiles totalTiles inferenceSteps inferenceTimeMs errorCode sampleInterval
  } } } }"""
body = json.dumps({"query": query, "variables": {"account": os.environ["CLOUDFLARE_ACCOUNT_ID"],
                   "start": "2026-11-11T00:00:00Z", "end": "2026-11-11T23:59:59Z"}}).encode()
request = urllib.request.Request("https://api.cloudflare.com/client/v4/graphql", data=body, method="POST",
    headers={"Authorization": "Bearer " + os.environ["CLOUDFLARE_ANALYTICS_TOKEN"], "Content-Type": "application/json"})
data = json.loads(urllib.request.urlopen(request, timeout=60).read())
if data.get("errors"):
    print(data["errors"]); raise SystemExit
rows = data["data"]["viewer"]["accounts"][0]["aiInferenceAdaptive"]
json.dump(rows, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "results", "cloudflare", "usage_rows.json"), "w"), indent=1)
print(len(rows), "rows")
for r in rows:
    print(r["datetime"][11:19], r["modelId"].split("/")[-1], "neurons", round(r["neurons"], 2), "px", r["processedPixels"],
          "tiles", r["processedTiles"], "/", r["totalTiles"], "steps", r["inferenceSteps"], "ms", r["inferenceTimeMs"], "err", r["errorCode"], "si", r["sampleInterval"])
