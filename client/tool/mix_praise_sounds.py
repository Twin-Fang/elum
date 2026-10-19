# 이룸이 칭찬 소리 원본 생성 (#777): 효과음(반짝 아르페지오) + 칭찬 음성 > 한 파일
# 순서: 서버 TTS(engine=supertonic, voice=F1)로 p1~p4.wav 받기 > 이 스크립트 > afconvert 로 AAC
#   p1 잘했어요! · p2 멋져요! · p3 최고예요! · p4 다 해냈어요! 정말 멋져요!
#   python3 -I tool/mix_praise_sounds.py <wav 폴더>
#   afconvert -f m4af -d aac -b 64000 praise_check_1.wav assets/sounds/praise_check_1.m4a
import math, struct, sys, wave
src_dir = sys.argv[1]
RATE = 44100

def chime(notes, note_seconds, volume):
    samples = []
    for index, freq in enumerate(notes):
        count = int(RATE * note_seconds)
        for n in range(count):
            t = n / RATE
            envelope = math.exp(-6 * t)  # 종소리처럼 빠르게 줄어듦
            tone = math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 2 * t)
            samples.append(volume * envelope * tone)
    return samples

def read(path):
    with wave.open(path) as w:
        frames = w.readframes(w.getnframes())
    return [s / 32768 for s in struct.unpack('<%dh' % (len(frames) // 2), frames)]

def write(path, samples):
    with wave.open(path, 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples))

check = chime([1046.5, 1318.5, 1568.0], 0.11, 0.35)
done = chime([784.0, 1046.5, 1318.5, 1568.0, 2093.0], 0.12, 0.35)
gap = [0.0] * int(RATE * 0.08)
write(f'{src_dir}/chime_check.wav', check)
for i in (1, 2, 3):
    write(f'{src_dir}/praise_check_{i}.wav', check + gap + read(f'{src_dir}/p{i}.wav'))
write(f'{src_dir}/praise_done.wav', done + gap + read(f'{src_dir}/p4.wav'))
