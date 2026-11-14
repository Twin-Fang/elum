package com.chuseok22.elumserver.admin.application.dto.response;

// 푸시 문구 보기 한 줄: 키, ko 문구, 고른 언어 문구 (없으면 null > 앱은 en 으로 대체)
public record AdminPushMessageCompareRow(String key, String koText, String selectedText) {

  public boolean isMissing() {
    return selectedText == null || selectedText.isBlank();
  }
}
