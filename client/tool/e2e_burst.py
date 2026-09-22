#!/usr/bin/env python3
"""**금방 사라지는 화면**을 연사로 잡는다.

    python3 tool/e2e_burst.py splash android
    python3 tool/e2e_burst.py splash ios --frames 60

결과: e2e/shots/<platform>/<flow>.png (시안에 가장 가까운 한 장)

## 왜 Maestro 로 안 되나

`launchApp` 은 **프로세스가 떴을 때** 돌아온다 — 첫 프레임이 아니다. 그래서
"화면이 뜬 것"을 기다리려면 화면 안의 무엇을 봐야 하는데, 명령과 명령 사이가
에뮬레이터에서 수백 ms 다. 시작 화면은 **1.7초만** 떠 있어서 그 사이에 로그인으로
넘어가 버린다 — 실제로 `assertNotVisible` 을 통과한 직후 찍은 것이 로그인이었다.

그래서 **찍고 나서 고른다.** 앱을 올리며 쉬지 않고 찍은 뒤, 시안과 가장 가까운
한 장을 남긴다. 고른 값이 크면(20% 넘으면) 그 화면을 **한 번도 못 잡은 것이므로**
경고한다 — 엉뚱한 프레임을 증적으로 남기지 않기 위해서다.

시안이 없는 플로우는 쓸 수 없다. 무엇에 가까운지를 잴 수 없기 때문이다.
"""
import argparse
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESIGN = (393, 852)
THRESHOLD = 24
MASK_TOP, MASK_BOTTOM = 59, 21   # 상태바·홈 인디케이터는 앱이 그리지 않는다
WARN_AT = 0.20                   # 이보다 크면 그 화면을 못 잡은 것으로 본다

APP_ID = 'kr.twinfang.elum'


def adb():
    home = os.environ.get('ANDROID_HOME') or os.path.expanduser('~/Library/Android/sdk')
    return os.path.join(home, 'platform-tools', 'adb')


def design_path(spec, platform):
    """이 플랫폼이 따를 시안 (플랫폼별로 갈린 화면이 있다 — #338)."""
    fig = spec.get('figma')
    if isinstance(fig, dict):
        fig = fig.get(platform)
    return os.path.normpath(os.path.join(ROOT, fig)) if fig else None


def restart(platform, serial):
    if platform == 'android':
        subprocess.run([adb(), '-s', serial, 'shell', 'am', 'force-stop', APP_ID], check=False)
        subprocess.run([adb(), '-s', serial, 'shell', 'monkey', '-p', APP_ID,
                        '-c', 'android.intent.category.LAUNCHER', '1'],
                       check=False, capture_output=True)
    else:
        subprocess.run(['xcrun', 'simctl', 'terminate', serial, APP_ID],
                       check=False, capture_output=True)
        subprocess.run(['xcrun', 'simctl', 'launch', serial, APP_ID],
                       check=False, capture_output=True)


def shoot(platform, serial, path):
    if platform == 'android':
        with open(path, 'wb') as f:
            subprocess.run([adb(), '-s', serial, 'exec-out', 'screencap', '-p'],
                           stdout=f, check=False)
    else:
        subprocess.run(['xcrun', 'simctl', 'io', serial, 'screenshot', path],
                       check=False, capture_output=True)


def score(path, design):
    """시안과 얼마나 다른가 (0~1). 못 읽는 파일은 최악으로 본다."""
    try:
        a = np.asarray(Image.open(path).convert('RGB').resize(DESIGN, Image.LANCZOS),
                       dtype=np.int16)
    except Exception:
        return 1.0
    lo, hi = MASK_TOP, DESIGN[1] - MASK_BOTTOM
    return float((np.abs(a[lo:hi] - design[lo:hi]).max(axis=2) > THRESHOLD).mean())


def serial_of(platform):
    if platform == 'android':
        out = subprocess.run([adb(), 'devices'], capture_output=True, text=True).stdout
        for line in out.splitlines()[1:]:
            parts = line.split()
            if len(parts) == 2 and parts[1] == 'device':
                return parts[0]
        return None
    out = subprocess.run(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j'],
                         capture_output=True, text=True).stdout
    for devs in json.loads(out)['devices'].values():
        for d in devs:
            if d.get('state') == 'Booted':
                return d['udid']
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('flow')
    ap.add_argument('platform', choices=['ios', 'android'])
    ap.add_argument('--frames', type=int, default=40)
    args = ap.parse_args()

    meta = json.load(open(os.path.join(ROOT, 'e2e', 'flows.json')))
    if args.flow not in meta:
        print(f'e2e/flows.json 에 {args.flow} 가 없다', file=sys.stderr)
        return 2
    spec = meta[args.flow]
    dpath = design_path(spec, args.platform)
    if not dpath or not os.path.exists(dpath):
        print(f'{args.flow}: {args.platform} 시안이 없다 — 연사는 시안이 있어야 고를 수 있다',
              file=sys.stderr)
        return 2
    serial = serial_of(args.platform)
    if not serial:
        print(f'{args.platform}: 켜진 기기가 없다', file=sys.stderr)
        return 2

    design = np.asarray(Image.open(dpath).convert('RGB').resize(DESIGN, Image.LANCZOS),
                        dtype=np.int16)
    import tempfile
    work = tempfile.mkdtemp()
    restart(args.platform, serial)

    best = (1.0, None)
    for i in range(args.frames):
        p = os.path.join(work, f'f{i:03d}.png')
        shoot(args.platform, serial, p)
        s = score(p, design)
        if s < best[0]:
            best = (s, p)

    if best[1] is None:
        print('찍힌 것이 없다', file=sys.stderr)
        return 1

    out_dir = os.path.join(ROOT, 'e2e', 'shots', args.platform)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f'{args.flow}.png')
    Image.open(best[1]).save(out)

    mark = '⚠️ 못 잡았을 수 있다' if best[0] > WARN_AT else 'OK'
    print(f'  {args.platform}: {out}  (시안과 {100 * best[0]:.2f}% 다름 · {mark})')
    return 1 if best[0] > WARN_AT else 0


if __name__ == '__main__':
    sys.exit(main())
