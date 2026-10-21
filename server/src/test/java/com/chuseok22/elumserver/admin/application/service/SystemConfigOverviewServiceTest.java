package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.Highlight;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.PlanRow;
import com.chuseok22.elumserver.member.application.service.MemberPickerService;
import com.chuseok22.elumserver.systemconfig.application.service.ConfigValueSource;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigView;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.ConfigValueType;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 설정 화면 요약·표 구성: 기본값과 다름, 이력 없는 키, 비밀값 가림, 켜진 이벤트, Free/Pro 비교
 */
@ExtendWith(MockitoExtension.class)
class SystemConfigOverviewServiceTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 20, 12, 0);

  @Mock private SystemConfigService systemConfigService;
  @Mock private SystemConfigHistoryService historyService;
  @Mock private MemberPickerService memberPickerService;

  private SystemConfigOverviewService service;
  /** 키 > 현재 값 (없으면 기본값). 테스트가 바꿔 끼움 */
  private final Map<ConfigKey, String> currentValueByKey = new LinkedHashMap<>();
  private final Map<String, SystemConfigHistory> latestByKey = new LinkedHashMap<>();
  private boolean isSecretStored;

  @BeforeEach
  void setUp() {
    service = new SystemConfigOverviewService(systemConfigService, historyService, memberPickerService);
  }

  private void stubViews() {
    List<SystemConfigView> views = new ArrayList<>();
    for (ConfigKey key : ConfigKey.values()) {
      if (key.getValueType() == ConfigValueType.SECRET) {
        views.add(new SystemConfigView(key.name(), key.getGroup(), key.getLabel(), key.getDescription(),
          key.getValueType(), key.getAllowedValues(), isSecretStored ? "••••••••" : "", "", isSecretStored,
          key.getMinValue(), key.getMaxValue(), key.getFormat(), null,
          isSecretStored ? ConfigValueSource.STORED : ConfigValueSource.CODE_DEFAULT, null));
        continue;
      }
      String current = currentValueByKey.getOrDefault(key, key.getDefaultValue());
      views.add(new SystemConfigView(key.name(), key.getGroup(), key.getLabel(), key.getDescription(),
        key.getValueType(), key.getAllowedValues(), current, key.getDefaultValue(),
        !current.equals(key.getDefaultValue()), key.getMinValue(), key.getMaxValue(), key.getFormat(), null,
        ConfigValueSource.CODE_DEFAULT, null));
    }
    when(systemConfigService.getAllViews()).thenReturn(views);
    lenient().when(historyService.latestByKey()).thenReturn(latestByKey);
  }

  private static SystemConfigHistory history(ConfigKey key, LocalDateTime at, String by, String reason) {
    SystemConfigHistory history = new SystemConfigHistory();
    history.setConfigKey(key.name());
    history.setChangedBy(by);
    history.setReason(reason);
    ReflectionTestUtils.setField(history, "createdAt", at);
    return history;
  }

  private SettingRow rowOf(List<SettingRow> rows, ConfigKey key) {
    return rows.stream().filter(row -> row.key().equals(key.name())).findFirst().orElseThrow();
  }

  @Test
  @DisplayName("이력 없는 키는 마지막 변경이 비고, 이력 있는 키는 시각·변경자·사유가 붙는다")
  void rows_withoutHistory_haveNoLastChange() {
    latestByKey.put(ConfigKey.MAINTENANCE_MODE.name(),
      history(ConfigKey.MAINTENANCE_MODE, NOW.minusHours(1), "admin", "점검"));
    stubViews();

    List<SettingRow> rows = service.buildRows();

    SettingRow withHistory = rowOf(rows, ConfigKey.MAINTENANCE_MODE);
    assertThat(withHistory.hasHistory()).isTrue();
    assertThat(withHistory.lastChangedBy()).isEqualTo("admin");
    assertThat(withHistory.lastReason()).isEqualTo("점검");
    SettingRow withoutHistory = rowOf(rows, ConfigKey.FREE_ROUTINE_MAX_COUNT);
    assertThat(withoutHistory.hasHistory()).isFalse();
    assertThat(withoutHistory.lastChangedAt()).isNull();
  }

  @Test
  @DisplayName("기본 정렬은 최근 변경순이고 이력 없는 키는 맨 뒤에 온다")
  void rows_sortedByRecentChangeFirst_noHistoryLast() {
    latestByKey.put(ConfigKey.MAINTENANCE_MODE.name(), history(ConfigKey.MAINTENANCE_MODE, NOW.minusDays(2), "a", null));
    latestByKey.put(ConfigKey.FREE_ADS_REMOVED.name(), history(ConfigKey.FREE_ADS_REMOVED, NOW.minusHours(1), "b", null));
    stubViews();

    List<SettingRow> rows = service.buildRows();

    assertThat(rows.get(0).key()).isEqualTo(ConfigKey.FREE_ADS_REMOVED.name());
    assertThat(rows.get(1).key()).isEqualTo(ConfigKey.MAINTENANCE_MODE.name());
    assertThat(rows.get(rows.size() - 1).hasHistory()).isFalse();
  }

  @Test
  @DisplayName("Free 광고 제거를 켜면 기본값과 다름 표시와 요약·Free/Pro 비교에 반영된다")
  void freeAdsRemoved_true_isDifferentEverywhere() {
    currentValueByKey.put(ConfigKey.FREE_ADS_REMOVED, "true");
    stubViews();

    SettingRow row = rowOf(service.buildRows(), ConfigKey.FREE_ADS_REMOVED);
    SettingsOverview overview = service.buildOverview(service.buildRows(), NOW);

    assertThat(row.isDifferent()).isTrue();
    assertThat(row.displayValue()).isEqualTo("켜짐");
    assertThat(row.defaultDisplayValue()).isEqualTo("꺼짐");
    assertThat(overview.differsFromDefaultCount()).isEqualTo(1);
    Highlight adsHighlight = overview.highlights().stream()
      .filter(highlight -> highlight.key().equals(ConfigKey.FREE_ADS_REMOVED.name())).findFirst().orElseThrow();
    assertThat(adsHighlight.isOn()).isTrue();
    assertThat(adsHighlight.isDifferent()).isTrue();
    PlanRow adsPlanRow = overview.planComparison().stream()
      .filter(planRow -> planRow.freeKey().equals(ConfigKey.FREE_ADS_REMOVED.name())).findFirst().orElseThrow();
    assertThat(adsPlanRow.freeValueText()).isEqualTo("켜짐");
    assertThat(adsPlanRow.isFreeDifferent()).isTrue();
    assertThat(adsPlanRow.proValueText()).isEqualTo("켜짐");
    assertThat(adsPlanRow.isProDifferent()).isFalse();
  }

  @Test
  @DisplayName("값이 -1 이면 무제한으로 보이고, 기본값과 같으면 다름이 아니다")
  void unlimitedNumber_andSameAsDefault() {
    stubViews();

    SettingsOverview overview = service.buildOverview(service.buildRows(), NOW);

    PlanRow maxCountRow = overview.planComparison().stream()
      .filter(planRow -> planRow.freeKey().equals(ConfigKey.FREE_ROUTINE_MAX_COUNT.name())).findFirst().orElseThrow();
    assertThat(maxCountRow.freeValueText()).isEqualTo("무제한");
    assertThat(maxCountRow.isFreeDifferent()).isFalse();
    assertThat(overview.differsFromDefaultCount()).isZero();
  }

  @Test
  @DisplayName("비밀값은 값 대신 설정됨으로만 보이고 기본값과 다름 수에 세지 않는다")
  void secret_isMasked_andNotCounted() {
    isSecretStored = true;
    latestByKey.put(ConfigKey.OPENAI_API_KEY.name(),
      history(ConfigKey.OPENAI_API_KEY, NOW.minusDays(1), "admin", null));
    stubViews();

    List<SettingRow> rows = service.buildRows();
    SettingRow secretRow = rowOf(rows, ConfigKey.OPENAI_API_KEY);

    assertThat(secretRow.isSecret()).isTrue();
    assertThat(secretRow.displayValue()).isEqualTo("설정됨");
    assertThat(secretRow.currentValue()).isEmpty();
    assertThat(secretRow.searchText()).doesNotContain("••••");
    assertThat(secretRow.lastChangedAt()).isEqualTo(NOW.minusDays(1));
    assertThat(service.buildOverview(rows, NOW).differsFromDefaultCount()).isZero();
  }

  @Test
  @DisplayName("신규가입 PRO 이벤트는 켜져 있고 지금이 가입 기간 안일 때만 진행 중으로 요약된다")
  void signupProEvent_activeOnlyInsideWindow() {
    currentValueByKey.put(ConfigKey.SIGNUP_PRO_EVENT_ENABLED, "true");
    currentValueByKey.put(ConfigKey.SIGNUP_PRO_EVENT_START_AT, "2026-10-19T00:00");
    currentValueByKey.put(ConfigKey.SIGNUP_PRO_EVENT_END_AT, "2026-10-26");
    stubViews();

    List<SettingRow> rows = service.buildRows();
    Highlight inside = eventHighlight(service.buildOverview(rows, NOW));
    Highlight before = eventHighlight(service.buildOverview(rows, LocalDateTime.of(2026, 10, 18, 0, 0)));
    Highlight after = eventHighlight(service.buildOverview(rows, LocalDateTime.of(2026, 10, 27, 0, 0)));

    assertThat(inside.isOn()).isTrue();
    assertThat(inside.valueText()).contains("진행 중");
    assertThat(before.isOn()).isFalse();
    assertThat(before.valueText()).contains("예정");
    assertThat(after.isOn()).isFalse();
    assertThat(after.valueText()).contains("종료");
  }

  @Test
  @DisplayName("이벤트를 켰어도 기간이 비었거나 읽을 수 없으면 적용 안 됨으로 요약하고 화면은 깨지지 않는다")
  void signupProEvent_blankOrBrokenWindow_isNotApplied() {
    currentValueByKey.put(ConfigKey.SIGNUP_PRO_EVENT_ENABLED, "true");
    stubViews();
    Highlight blank = eventHighlight(service.buildOverview(service.buildRows(), NOW));

    currentValueByKey.put(ConfigKey.SIGNUP_PRO_EVENT_START_AT, "어제");
    currentValueByKey.put(ConfigKey.SIGNUP_PRO_EVENT_END_AT, "내일");
    stubViews();
    Highlight broken = eventHighlight(service.buildOverview(service.buildRows(), NOW));

    assertThat(blank.isOn()).isFalse();
    assertThat(blank.valueText()).contains("기간 미설정");
    assertThat(broken.isOn()).isFalse();
    assertThat(broken.valueText()).contains("날짜 오류");
  }

  private Highlight eventHighlight(SettingsOverview overview) {
    return overview.highlights().stream()
      .filter(highlight -> highlight.key().equals(ConfigKey.SIGNUP_PRO_EVENT_ENABLED.name()))
      .findFirst().orElseThrow();
  }
}
