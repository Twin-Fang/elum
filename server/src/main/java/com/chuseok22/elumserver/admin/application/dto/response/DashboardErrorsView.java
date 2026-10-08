package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/** 대시보드 카드용. 시각은 화면에 그대로 찍도록 서버에서 KST 문자열로 만든다. */
public record DashboardErrorsView(
  int last24h,
  String since,
  List<Item> recent
) {

  public record Item(
    String time,
    String logger,
    String message
  ) {

  }
}
