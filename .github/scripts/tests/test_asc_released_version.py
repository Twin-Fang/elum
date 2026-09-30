"""asc_released_version.py 판정 로직과 조회 흐름의 단위 테스트 (이슈 #452).

실행:  python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
네트워크는 로컬 가짜 서버로 대신한다. 실제 Apple 서버는 부르지 않는다.
"""
import base64
import http.server
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "asc_released_version", Path(__file__).resolve().parent.parent / "asc_released_version.py"
)
asc = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(asc)


class ParseVersionTest(unittest.TestCase):
    def test_점_표기는_세_칸_튜플로(self):
        self.assertEqual(asc.parse_version("2.1.2"), (2, 1, 2))
        self.assertEqual(asc.parse_version("2.1"), (2, 1, 0))

    def test_숫자가_아니면_None(self):
        self.assertIsNone(asc.parse_version("2.1.2-beta"))
        self.assertIsNone(asc.parse_version(""))
        self.assertIsNone(asc.parse_version(None))

    def test_숫자_크기로_비교한다_문자열_비교가_아니다(self):
        self.assertGreater(asc.parse_version("2.1.10"), asc.parse_version("2.1.9"))


class DecideTest(unittest.TestCase):
    # 실측(2026-09-30): 2.1.2 판매 중, 1.45.0 / 1.43.0 판매 중
    VERSIONS = [
        ("2.1.2", "READY_FOR_SALE"),
        ("1.45.0", "READY_FOR_SALE"),
        ("1.43.0", "READY_FOR_SALE"),
    ]

    def test_출시된_버전과_같으면_막는다(self):
        status, released, reason = asc.decide("2.1.2", self.VERSIONS)
        self.assertEqual((status, released), ("blocked", "2.1.2"))
        self.assertIn("2.1.2", reason)

    def test_출시된_버전보다_낮아도_막는다(self):
        self.assertEqual(asc.decide("2.1.1", self.VERSIONS)[0], "blocked")

    def test_출시된_버전보다_높으면_통과(self):
        # 통제 시험에서 2.1.99 는 실제로 TestFlight 에 올라갔다
        self.assertEqual(asc.decide("2.1.99", self.VERSIONS)[0], "ok")
        self.assertEqual(asc.decide("2.1.3", self.VERSIONS)[0], "ok")

    def test_심사_중이나_준비_중인_버전은_닫힌_것이_아니다(self):
        versions = [("2.1.2", "READY_FOR_SALE"), ("2.1.3", "IN_REVIEW"), ("2.1.4", "PREPARE_FOR_SUBMISSION")]
        self.assertEqual(asc.decide("2.1.3", versions)[0], "ok")
        self.assertEqual(asc.decide("2.1.4", versions)[0], "ok")

    def test_거절된_버전은_닫힌_것이_아니다(self):
        versions = [("2.1.2", "READY_FOR_SALE"), ("2.1.3", "REJECTED")]
        self.assertEqual(asc.decide("2.1.3", versions)[0], "ok")

    def test_출시_대기와_처리_중은_닫힌_것이다(self):
        for state in ("PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE"):
            self.assertEqual(asc.decide("2.1.3", [("2.1.3", state)])[0], "blocked", state)

    def test_출시_이력이_없으면_통과(self):
        self.assertEqual(asc.decide("1.0.0", [])[0], "ok")

    def test_버전_문자열을_못_읽으면_건너뛴다_막지_않는다(self):
        self.assertEqual(asc.decide("abc", self.VERSIONS)[0], "skipped")


class _Handler(http.server.BaseHTTPRequestHandler):
    routes = {}
    seen = []

    def do_GET(self):  # noqa: N802
        _Handler.seen.append((self.path, self.headers.get("Authorization", "")))
        for prefix, (code, body) in _Handler.routes.items():
            if self.path.startswith(prefix):
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(body).encode())
                return
        self.send_response(404)
        self.end_headers()

    def log_message(self, *args):
        pass


def _gen_key_b64():
    with tempfile.TemporaryDirectory() as tmp:
        key = os.path.join(tmp, "k.pem")
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", key], check=True, capture_output=True)
        pkcs8 = os.path.join(tmp, "k8.pem")
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", key, "-out", pkcs8], check=True, capture_output=True)
        return base64.b64encode(Path(pkcs8).read_bytes()).decode()


class EndToEndTest(unittest.TestCase):
    """스크립트를 실제 프로세스로 돌려 stdout 계약(status/reason)을 확인한다."""

    @classmethod
    def setUpClass(cls):
        cls.server = http.server.HTTPServer(("127.0.0.1", 0), _Handler)
        cls.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.key_b64 = _gen_key_b64()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def _run(self, version, env_extra=None):
        script = Path(__file__).resolve().parent.parent / "asc_released_version.py"
        env = {
            "PATH": os.environ["PATH"],
            "APP_STORE_CONNECT_API_KEY_ID": "KEYID12345",
            "APP_STORE_CONNECT_ISSUER_ID": "00000000-0000-0000-0000-000000000000",
            "APP_STORE_CONNECT_API_KEY_BASE64": self.key_b64,
            "IOS_BUNDLE_ID": "kr.example.app",
            "ASC_API_BASE": f"http://127.0.0.1:{self.port}",
        }
        env.update(env_extra or {})
        proc = subprocess.run([sys.executable, str(script), version], capture_output=True, text=True, env=env, timeout=60)
        out = dict(line.split("=", 1) for line in proc.stdout.splitlines() if "=" in line)
        return proc.returncode, out

    def _routes(self, versions):
        _Handler.seen.clear()
        _Handler.routes = {
            "/v1/apps?": (200, {"data": [{"id": "111"}]}),
            "/v1/apps/111/appStoreVersions": (
                200,
                {"data": [{"attributes": {"versionString": v, "appStoreState": s}} for v, s in versions]},
            ),
        }

    def test_출시된_버전이면_blocked_이고_종료코드는_0(self):
        self._routes([("2.1.2", "READY_FOR_SALE")])
        code, out = self._run("2.1.2")
        self.assertEqual(code, 0)
        self.assertEqual(out["status"], "blocked")
        self.assertEqual(out["released_max"], "2.1.2")
        self.assertTrue(out["reason"])

    def test_더_높은_버전이면_ok(self):
        self._routes([("2.1.2", "READY_FOR_SALE")])
        self.assertEqual(self._run("2.1.99")[1]["status"], "ok")

    def test_요청에_JWT_가_실린다(self):
        self._routes([("2.1.2", "READY_FOR_SALE")])
        self._run("2.1.3")
        auths = [a for _, a in _Handler.seen]
        self.assertTrue(auths and all(a.startswith("Bearer ") and a.count(".") == 2 for a in auths))

    def test_시크릿이_없으면_skipped_막지_않는다(self):
        code, out = self._run("2.1.2", {"APP_STORE_CONNECT_ISSUER_ID": ""})
        self.assertEqual((code, out["status"]), (0, "skipped"))

    def test_서버가_오류를_내면_skipped_막지_않는다(self):
        _Handler.routes = {"/v1/apps?": (401, {"errors": []})}
        code, out = self._run("2.1.2")
        self.assertEqual((code, out["status"]), (0, "skipped"))
        self.assertIn("401", out["reason"])

    def test_앱을_못_찾으면_skipped(self):
        _Handler.routes = {"/v1/apps?": (200, {"data": []})}
        self.assertEqual(self._run("2.1.2")[1]["status"], "skipped")

    def test_서버에_닿지_않아도_skipped(self):
        code, out = self._run("2.1.2", {"ASC_API_BASE": "http://127.0.0.1:9"})
        self.assertEqual((code, out["status"]), (0, "skipped"))

    def test_reason_은_한_줄이다(self):
        self._routes([("2.1.2", "READY_FOR_SALE")])
        _, out = self._run("2.1.2")
        self.assertNotIn("\n", out["reason"])


if __name__ == "__main__":
    unittest.main()
