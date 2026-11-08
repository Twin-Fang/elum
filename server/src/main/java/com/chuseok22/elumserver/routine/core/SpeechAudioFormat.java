package com.chuseok22.elumserver.routine.core;

/**
 * 단계 음성 저장 형식 2개: WAV(압축 전·변환 실패 시), AAC(m4a, 기본) (#1211)
 * 형식은 저장 열쇠 확장자로 판정. 열쇠 {stepId}/{문장 해시}{확장자}
 */
public enum SpeechAudioFormat {

  WAV(".wav", "audio/wav"),
  AAC(".m4a", "audio/mp4");

  private final String extension;
  private final String mediaType;

  SpeechAudioFormat(String extension, String mediaType) {
    this.extension = extension;
    this.mediaType = mediaType;
  }

  public String extension() {
    return extension;
  }

  public String mediaType() {
    return mediaType;
  }

  /**
   * 단계 id·문장 해시 > 저장 열쇠
   */
  public String keyOf(String stepId, String textHash) {
    return stepId + "/" + textHash + extension;
  }

  /**
   * 저장 열쇠 > 형식 (.m4a 면 AAC, 그 외는 WAV)
   */
  public static SpeechAudioFormat ofKey(String speechKey) {
    return speechKey != null && speechKey.endsWith(AAC.extension) ? AAC : WAV;
  }

  /**
   * 저장 열쇠 > 문장 해시 (폴더·확장자 뗀 파일 이름)
   */
  public static String textHashOf(String speechKey) {
    String fileName = speechKey.substring(speechKey.lastIndexOf('/') + 1);
    int extensionStart = fileName.lastIndexOf('.');
    return extensionStart < 0 ? fileName : fileName.substring(0, extensionStart);
  }
}
