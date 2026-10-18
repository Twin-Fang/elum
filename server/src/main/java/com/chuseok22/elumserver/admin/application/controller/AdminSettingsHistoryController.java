package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.service.AdminSettingsHistoryService;
import com.chuseok22.elumserver.admin.application.service.AdminSettingsHistoryService.HistoryPageResult;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 설정 변경 이력: 전체 이력 화면(키·변경자·기간 필터 + 페이지), 한 키의 이력(설정 화면 패널용 JSON)
 */
@Controller
@RequiredArgsConstructor
public class AdminSettingsHistoryController {

  private static final String HISTORY_PATH = "/admin/settings/history";

  private final AdminSettingsHistoryService adminSettingsHistoryService;
  private final SystemConfigHistoryService systemConfigHistoryService;
  private final AdminDateFormatter adminDateFormatter;

  @GetMapping(HISTORY_PATH)
  public String history(
    @RequestParam(value = "q", required = false) String q,
    @RequestParam(value = "key", required = false) String key,
    @RequestParam(value = "changedBy", required = false) String changedBy,
    @RequestParam(value = "from", required = false) String from,
    @RequestParam(value = "to", required = false) String to,
    @RequestParam(value = "sort", required = false) String sort,
    @RequestParam(value = "page", required = false) String page,
    Model model
  ) {
    Map<String, String> filters = new LinkedHashMap<>();
    filters.put(AdminSettingsHistoryService.FILTER_KEY, key);
    filters.put(AdminSettingsHistoryService.FILTER_CHANGED_BY, changedBy);
    filters.put(AdminSettingsHistoryService.FILTER_FROM, from);
    filters.put(AdminSettingsHistoryService.FILTER_TO, to);
    AdminListQuery query = AdminListQuery.of(q, filters, sort, page, AdminSettingsHistoryService.DEFINITION);
    HistoryPageResult result = adminSettingsHistoryService.search(query);

    model.addAttribute("definition", AdminSettingsHistoryService.DEFINITION);
    model.addAttribute("query", result.query());
    model.addAttribute("page", result.page());
    model.addAttribute("rows", result.rows());
    // 페이저 링크: 조건과 정렬을 유지한 기준 주소 (페이저가 page 를 덧붙임)
    model.addAttribute("baseUrl", HISTORY_PATH + result.query().toQueryString(result.query().sort(), 1));
    model.addAttribute("configKeyNames", Arrays.stream(ConfigKey.values()).map(Enum::name).toList());
    return "admin/settings-history";
  }

  /// 한 키의 최근 이력 (최신순). 비밀값은 이력에 가림 표시만 있음
  @GetMapping("/admin/settings/{key}/history")
  @ResponseBody
  public List<Map<String, String>> keyHistory(@PathVariable ConfigKey key) {
    return systemConfigHistoryService.recentOf(key.name()).stream()
      .map(history -> Map.of(
        "at", adminDateFormatter.format(history.getCreatedAt()),
        "by", history.getChangedBy() == null ? "" : history.getChangedBy(),
        "oldValue", history.getOldValue() == null ? "" : history.getOldValue(),
        "newValue", history.getNewValue() == null ? "" : history.getNewValue(),
        "reason", history.getReason() == null ? "" : history.getReason()))
      .toList();
  }
}
