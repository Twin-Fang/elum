import 'dart:typed_data';

/// 받은 소리 바이트 형식 판정 (HTML 오류 페이지 등을 걸러냄)
///
/// 서버 단계 음성(m4a·wav, #1211)과 보호자 목소리(m4a, #787)가 함께 씀.
abstract final class AudioFileHeader {
  /// 판정에 필요한 머리 길이 (WAV `RIFF....WAVE` 12바이트)
  static const headerLength = 12;

  /// WAV 머리 `RIFF....WAVE`
  static bool isWav(Uint8List bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45;

  /// MP4(m4a) 머리 `....ftyp`
  static bool isM4a(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70;
}
