package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.Highlight;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.PlanRow;
import com.chuseok22.elumserver.systemconfig.application.service.ConfigDateTime;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigView;
import com.chuseok22.elumserver.systemconfig.core.ConfigGroup;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.ConfigValueType;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 설정 화면 데이터: 표 행(현재·기본값·마지막 변경), 상단 요약(기본값과 다름·켜진 이벤트), Free/Pro 비교
 * 마지막 변경은 키별 최신 이력을 쿼리 1회로 가져와 붙임 (키마다 조회하지 않음)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SystemConfigOverviewService {

  private static final String TURNED_ON_TEXT = "켜짐";
  private static final String TURNED_OFF_TEXT = "꺼짐";
  private static final String SECRET_SET_TEXT = "설정됨";
  private static final String SECRET_NOT_SET_TEXT = "설정 안 됨";
  private static final String EMPTY_VALUE_TEXT = "(비어 있음)";
  /** 플랜 한도의 -1: 제한 없음 */
  private static final String UNLIMITED_TEXT = "무제한";
  private static final String UNLIMITED_VALUE = "-1";
  /** 플랜 비교에서 Free 키 이름에서 Pro 키 이름을 만들 때 바꾸는 접두사 */
  private static final String FREE_KEY_PREFIX = "FREE_";
  private static final String PRO_KEY_PREFIX = "PRO_";

  private final SystemConfigService systemConfigService;
  private final SystemConfigHistoryService historyService;

  /// 전체 설정 표 행 (기본 정렬: 최근 변경순, 이력 없는 키는 맨 뒤)
  public List<SettingRow> buildRows() {
    Map<String, SystemConfigHistory> latestByKey = historyService.latestByKey();
    List<SettingRow> rows = new ArrayList<>();
    for (SystemConfigView view : systemConfigService.getAllViews()) {
      rows.add(toRow(view, latestByKey.get(view.key())));
    }
    // 최근 변경순 (이력 없는 키 맨 뒤, 같으면 선언 순서 유지)
    rows.sort(Comparator.comparing(SettingRow::lastChangedAt, Comparator.nullsLast(Comparator.reverseOrder())));
    return rows;
  }

  /// 상단 요약: 기본값과 다른 설정 수, 지금 적용 중 항목, Free/Pro 비교
  public SettingsOverview buildOverview(List<SettingRow> rows, LocalDateTime now) {
    Map<String, SettingRow> rowByKey = rows.stream()
      .collect(Collectors.toMap(SettingRow::key, Function.identity()));
    int differsFromDefaultCount = (int) rows.stream().filter(SettingRow::isDifferent).count();
    return new SettingsOverview(differsFromDefaultCount, highlightsOf(rowByKey, now), planComparisonOf(rowByKey));
  }

  private SettingRow toRow(SystemConfigView view, SystemConfigHistory latest) {
    boolean isSecret = view.valueType() == ConfigValueType.SECRET;
    // 비밀값은 값 자체를 화면으로 보내지 않음 (설정 여부만)
    String currentValue = isSecret ? "" : view.value();
    String displayValue = isSecret
      ? (view.changed() ? SECRET_SET_TEXT : SECRET_NOT_SET_TEXT)
      : displayText(view.valueType(), view.value());
    return new SettingRow(
      view.key(), view.label(), view.description(), view.group().name(), view.group().getLabel(),
      view.valueType().name(), view.allowedValues(), view.minValue(), view.maxValue(),
      currentValue, displayValue, view.defaultValue(),
      isSecret ? "" : displayText(view.valueType(), view.defaultValue()),
      !isSecret && view.changed(), isSecret,
      latest != null, latest == null ? null : latest.getCreatedAt(),
      latest == null ? null : latest.getChangedBy(), latest == null ? null : latest.getReason());
  }

  private static String displayText(ConfigValueType valueType, String value) {
    if (valueType == ConfigValueType.BOOLEAN) {
      return "true".equalsIgnoreCase(value == null ? "" : value.trim()) ? TURNED_ON_TEXT : TURNED_OFF_TEXT;
    }
    return value == null || value.isBlank() ? EMPTY_VALUE_TEXT : value;
  }

  private List<Highlight> highlightsOf(Map<String, SettingRow> rowByKey, LocalDateTime now) {
    List<Highlight> highlights = new ArrayList<>();
    highlights.add(signupProEventHighlight(rowByKey, now));
    highlights.add(toggleHighlight(rowByKey.get(ConfigKey.MAINTENANCE_MODE.name()), "점검 모드"));
    highlights.add(toggleHighlight(rowByKey.get(ConfigKey.FREE_ADS_REMOVED.name()), "Free 광고 제거"));
    highlights.add(toggleHighlight(rowByKey.get(ConfigKey.AD_REWARD_ENABLED.name()), "광고 보상"));
    highlights.add(valueHighlight(rowByKey.get(ConfigKey.TEXT_PROVIDER_SELECTED.name()), "텍스트 제공자"));
    highlights.add(valueHighlight(rowByKey.get(ConfigKey.IMAGE_PROVIDER_SELECTED.name()), "이미지 제공자"));
    return highlights;
  }

  private static Highlight toggleHighlight(SettingRow row, String label) {
    return new Highlight(row.key(), label, row.displayValue(),
      "true".equalsIgnoreCase(row.currentValue()), row.isDifferent());
  }

  private static Highlight valueHighlight(SettingRow row, String label) {
    return new Highlight(row.key(), label, row.displayValue(), false, row.isDifferent());
  }

  /**
   * 신규가입 PRO 이벤트: 켜짐 + 지금이 가입 기간 안일 때만 진행 중
   * 켰어도 기간이 비었거나 읽을 수 없으면 적용 안 됨 (SystemConfigEntitlementService 판정과 같은 규칙)
   */
  private static Highlight signupProEventHighlight(Map<String, SettingRow> rowByKey, LocalDateTime now) {
    SettingRow enabledRow = rowByKey.get(ConfigKey.SIGNUP_PRO_EVENT_ENABLED.name());
    String label = "신규가입 PRO 이벤트";
    boolean isEnabled = "true".equalsIgnoreCase(enabledRow.currentValue());
    boolean isDifferent = enabledRow.isDifferent();
    if (!isEnabled) {
      return new Highlight(enabledRow.key(), label, TURNED_OFF_TEXT, false, isDifferent);
    }
    String startText = rowByKey.get(ConfigKey.SIGNUP_PRO_EVENT_START_AT.name()).currentValue();
    String endText = rowByKey.get(ConfigKey.SIGNUP_PRO_EVENT_END_AT.name()).currentValue();
    if (startText.isBlank() || endText.isBlank()) {
      return new Highlight(enabledRow.key(), label, "켜짐 · 기간 미설정 (적용 안 됨)", false, isDifferent);
    }
    try {
      LocalDateTime start = ConfigDateTime.parse(startText);
      LocalDateTime end = ConfigDateTime.parse(endText);
      String period = startText + " ~ " + endText;
      if (now.isBefore(start)) {
        return new Highlight(enabledRow.key(), label, "예정 · " + period, false, isDifferent);
      }
      if (now.isAfter(end)) {
        return new Highlight(enabledRow.key(), label, "종료 · " + period, false, isDifferent);
      }
      return new Highlight(enabledRow.key(), label, "진행 중 · " + period, true, isDifferent);
    } catch (DateTimeParseException e) {
      return new Highlight(enabledRow.key(), label, "켜짐 · 날짜 오류 (적용 안 됨)", false, isDifferent);
    }
  }

  /// Free 키마다 짝이 되는 Pro 키를 찾아 한 줄로 (짝이 없으면 건너뜀)
  private List<PlanRow> planComparisonOf(Map<String, SettingRow> rowByKey) {
    List<PlanRow> planRows = new ArrayList<>();
    for (ConfigKey freeKey : ConfigKey.values()) {
      if (freeKey.getGroup() != ConfigGroup.PLAN_FREE) {
        continue;
      }
      SettingRow freeRow = rowByKey.get(freeKey.name());
      SettingRow proRow = rowByKey.get(PRO_KEY_PREFIX + freeKey.name().substring(FREE_KEY_PREFIX.length()));
      if (freeRow == null || proRow == null) {
        continue;
      }
      planRows.add(new PlanRow(
        freeRow.label(),
        freeRow.key(), planValueText(freeRow), freeRow.isDifferent(),
        proRow.key(), planValueText(proRow), proRow.isDifferent()));
    }
    return planRows;
  }

  private static String planValueText(SettingRow row) {
    return UNLIMITED_VALUE.equals(row.currentValue()) ? UNLIMITED_TEXT : row.displayValue();
  }
}
