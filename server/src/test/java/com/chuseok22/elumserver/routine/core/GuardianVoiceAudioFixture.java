package com.chuseok22.elumserver.routine.core;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

/**
 * 시험용 최소 m4a: ftyp > (mdat) > moov{mvhd v0}. 실제 녹음기처럼 moov 를 뒤에 둔다
 */
public final class GuardianVoiceAudioFixture {

  private GuardianVoiceAudioFixture() {
  }

  /**
   * 길이(밀리초) > m4a 바이트 (시간 단위 1000)
   */
  public static byte[] m4aOfMillis(long durationMillis) {
    return m4a(1000, durationMillis);
  }

  public static byte[] m4a(long timescale, long duration) {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    write(out, box("ftyp", ByteBuffer.allocate(8).put("M4A ".getBytes(StandardCharsets.ISO_8859_1)).putInt(0).array()));
    write(out, box("mdat", new byte[32]));
    byte[] mvhdBody = ByteBuffer.allocate(20)
      .putInt(0)
      .putInt(0)
      .putInt(0)
      .putInt((int) timescale)
      .putInt((int) duration)
      .array();
    write(out, box("moov", box("mvhd", mvhdBody)));
    return out.toByteArray();
  }

  private static byte[] box(String type, byte[] body) {
    return ByteBuffer.allocate(8 + body.length)
      .putInt(8 + body.length)
      .put(type.getBytes(StandardCharsets.ISO_8859_1))
      .put(body)
      .array();
  }

  private static void write(ByteArrayOutputStream out, byte[] bytes) {
    out.write(bytes, 0, bytes.length);
  }
}
