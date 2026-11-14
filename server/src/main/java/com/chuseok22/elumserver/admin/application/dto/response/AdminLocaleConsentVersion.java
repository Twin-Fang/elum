package com.chuseok22.elumserver.admin.application.dto.response;

// 언어 현황 약관 칸 한 줄: 문서 이름, 그 언어 게시 버전 (없으면 null)
public record AdminLocaleConsentVersion(String label, String version) {

  public boolean hasVersion() {
    return version != null && !version.isBlank();
  }
}
