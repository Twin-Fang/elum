package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsEditorView;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsSectionLink;
import com.chuseok22.elumserver.systemconfig.core.ConfigGroup;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 화면별 설정 칸: 그 화면 행만 고르기, 필터 칩, 다른 화면 바로가기 수
 * 행은 SystemConfigOverviewService 가 만든 전체 행에서 SettingsSection 기준으로 거름
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SettingsEditorService {

  static final String LOAD_ERROR_MESSAGE = "설정을 불러오지 못했어요. 새로고침해 주세요 (E-CFG-LOAD)";

  private final SystemConfigOverviewService overviewService;

  /// 화면 설정 칸: 전체 행 > 그 화면 행 > 묶음 칩(선언 순서)·규칙 경고 수
  public SettingsEditorView buildEditor(SettingsSection section, List<SettingRow> allRows, LocalDate today) {
    List<SettingRow> sectionRows = allRows.stream().filter(row -> isIn(row, section)).toList();
    Map<String, String> groupLabelByName = new LinkedHashMap<>();
    sectionRows.stream()
      .sorted(Comparator.comparing(row -> groupOf(row).ordinal()))
      .forEach(row -> groupLabelByName.putIfAbsent(row.groupName(), row.groupLabel()));
    long ruleWarningCount = sectionRows.stream().filter(SettingRow::hasValidationWarning).count();
    return new SettingsEditorView(section.getPath(), sectionRows, groupLabelByName, ruleWarningCount, today, null);
  }

  /// 다른 기능 화면(광고 보상·공지·서버 이전)에 얹는 설정 칸. 읽기 실패면 안내만 (그 화면은 그대로 뜸)
  public SettingsEditorView buildEditorOrFailure(SettingsSection section) {
    try {
      return buildEditor(section, overviewService.buildRows(), LocalDate.now());
    } catch (RuntimeException e) {
      log.warn("[admin settings] editor load failed : section={}", section, e);
      return SettingsEditorView.failed(section.getPath(), LOAD_ERROR_MESSAGE);
    }
  }

  /// 시스템 설정 밖 화면별 설정 수·기본값과 다른 수 (화면 선언 순서)
  public List<SettingsSectionLink> sectionLinksOf(List<SettingRow> allRows) {
    return Arrays.stream(SettingsSection.values())
      .filter(section -> section != SettingsSection.SYSTEM)
      .map(section -> {
        List<SettingRow> sectionRows = allRows.stream().filter(row -> isIn(row, section)).toList();
        long differsCount = sectionRows.stream().filter(SettingRow::isDifferent).count();
        return new SettingsSectionLink(section.getLabel(), section.getPath(), sectionRows.size(), differsCount);
      })
      .toList();
  }

  private static boolean isIn(SettingRow row, SettingsSection section) {
    return SettingsSection.of(groupOf(row)) == section;
  }

  private static ConfigGroup groupOf(SettingRow row) {
    return ConfigGroup.valueOf(row.groupName());
  }
}
