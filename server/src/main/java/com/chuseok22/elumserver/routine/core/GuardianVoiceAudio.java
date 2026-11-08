package com.chuseok22.elumserver.routine.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.nio.charset.StandardCharsets;
import java.util.OptionalLong;

/**
 * 보호자 녹음 검사: 크기 > 형식(MP4/M4A 머리 ftyp) > 길이(moov/mvhd) (#787)
 * 올린 쪽이 말한 형식(Content-Type·파일명)은 믿지 않고 바이트로 판정. ADTS(.aac 날것)·WAV 등은 받지 않음
 */
public final class GuardianVoiceAudio {

  // 녹음 파일 최대 크기 (1MB, 앱 64kbps·15초 ≈ 120KB)
  public static final long MAX_BYTES = 1024L * 1024L;

  // 녹음 최대 길이 (15초). 앱이 15초에 멈추고, 인코더 마무리 오차로 1초까지 더 받음
  public static final long MAX_DURATION_MILLIS = 15_000L;
  private static final long DURATION_GRACE_MILLIS = 1_000L;

  private static final int BOX_HEADER_BYTES = 8;
  private static final int LARGE_SIZE_BYTES = 8;

  private GuardianVoiceAudio() {
  }

  /**
   * 녹음 1건 검사 > 길이(밀리초). 형식 아님·길이 모름 > INVALID_TYPE, 15초 초과 > TOO_LONG
   */
  public static long inspect(byte[] audio) {
    if (audio == null || audio.length == 0) {
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);
    }
    if (audio.length > MAX_BYTES) {
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_TOO_LARGE);
    }
    if (!isMp4Container(audio)) {
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);
    }
    long durationMillis = durationMillisOf(audio)
      .orElseThrow(() -> new CustomException(ErrorCode.GUARDIAN_VOICE_INVALID_TYPE));
    if (durationMillis <= 0) {
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);
    }
    if (durationMillis > MAX_DURATION_MILLIS + DURATION_GRACE_MILLIS) {
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_TOO_LONG);
    }
    return durationMillis;
  }

  /**
   * 첫 상자가 ftyp 인가 (바이트 4~7 = "ftyp")
   */
  public static boolean isMp4Container(byte[] audio) {
    return audio.length >= BOX_HEADER_BYTES && "ftyp".equals(typeAt(audio, 4));
  }

  /**
   * 최상위 moov > mvhd 의 길이 / 시간 단위 > 밀리초. 못 찾거나 깨졌으면 빈 값
   */
  static OptionalLong durationMillisOf(byte[] audio) {
    BoxRange moov = findBox(audio, 0, audio.length, "moov");
    if (moov == null) {
      return OptionalLong.empty();
    }
    BoxRange mvhd = findBox(audio, moov.bodyStart(), moov.end(), "mvhd");
    if (mvhd == null) {
      return OptionalLong.empty();
    }
    return mvhdDurationMillis(audio, mvhd);
  }

  /// mvhd 본문: 버전(1) 플래그(3) > v0 생성(4) 수정(4) 시간단위(4) 길이(4) / v1 생성(8) 수정(8) 시간단위(4) 길이(8)
  private static OptionalLong mvhdDurationMillis(byte[] audio, BoxRange mvhd) {
    int body = mvhd.bodyStart();
    if (body >= mvhd.end()) {
      return OptionalLong.empty();
    }
    int version = audio[body] & 0xFF;
    int timescaleAt = version == 1 ? body + 4 + 16 : body + 4 + 8;
    int durationAt = timescaleAt + 4;
    int durationBytes = version == 1 ? 8 : 4;
    if (durationAt + durationBytes > mvhd.end()) {
      return OptionalLong.empty();
    }
    long timescale = readUnsigned(audio, timescaleAt, 4);
    long duration = readUnsigned(audio, durationAt, durationBytes);
    if (timescale <= 0 || duration < 0) {
      return OptionalLong.empty();
    }
    return OptionalLong.of(duration * 1000L / timescale);
  }

  /// [from, to) 안에서 이름이 같은 상자 찾기. 크기 0 = 끝까지, 1 = 64비트 크기
  private static BoxRange findBox(byte[] audio, int from, int to, String type) {
    int position = from;
    while (position + BOX_HEADER_BYTES <= to) {
      long size = readUnsigned(audio, position, 4);
      int header = BOX_HEADER_BYTES;
      if (size == 1) {
        if (position + BOX_HEADER_BYTES + LARGE_SIZE_BYTES > to) {
          return null;
        }
        size = readUnsigned(audio, position + BOX_HEADER_BYTES, LARGE_SIZE_BYTES);
        header += LARGE_SIZE_BYTES;
      } else if (size == 0) {
        size = to - position;
      }
      // 깨진 크기 (머리보다 작음, 범위 밖) > 더 읽지 않음
      if (size < header || position + size > to) {
        return null;
      }
      int end = (int) (position + size);
      if (type.equals(typeAt(audio, position + 4))) {
        return new BoxRange(position + header, end);
      }
      position = end;
    }
    return null;
  }

  private static String typeAt(byte[] audio, int offset) {
    return new String(audio, offset, 4, StandardCharsets.ISO_8859_1);
  }

  private static long readUnsigned(byte[] audio, int offset, int length) {
    long unsignedNumber = 0;
    for (int index = 0; index < length; index++) {
      unsignedNumber = (unsignedNumber << 8) | (audio[offset + index] & 0xFF);
    }
    return unsignedNumber;
  }

  /// 상자 본문 시작 ~ 끝 (머리 제외)
  private record BoxRange(int bodyStart, int end) {

  }
}
