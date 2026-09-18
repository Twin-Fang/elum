package com.chuseok22.elumserver.ai.core;

/**
 * 생성된 카드 삽화 한 장. 어느 제공자가 만들었는지는 담지 않는다.
 *
 * <p>원래 {@code GeminiImageClient}의 중첩 타입이었다. 그 때문에 저장소·파이프라인·
 * 관리자 서비스가 모두 Gemini라는 이름을 알아야 했고, 제공자를 바꿀 수 없었다.
 * 저장소는 바이트와 확장자만 알면 된다.
 *
 * @param bytes     이미지 원본
 * @param extension 저장 파일 확장자 (png · jpg · webp)
 */
public record GeneratedImage(byte[] bytes, String extension) {

}
