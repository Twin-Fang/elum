package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminNotificationMemberSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminNotificationMemberSummary.TypeSwitch;
import com.chuseok22.elumserver.admin.application.dto.response.AdminNotificationRow;
import com.chuseok22.elumserver.admin.application.list.AdminListPaging;
import com.chuseok22.elumserver.admin.application.list.AdminListPeriod;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminNotificationList;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationAdminView;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationPushSettingAdminView;
import com.chuseok22.elumserver.notification.application.service.NotificationAdminQueryService;
import com.chuseok22.elumserver.notification.application.service.NotificationAdminSearch;
import com.chuseok22.elumserver.notification.core.NotificationType;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;

/**
 * 알림 기록 관리자 화면: 알림 목록(회원 조건 > 검색 > 이름 붙이기), 회원 요약 카드(안 읽음 수·푸시 설정)
 * 트랜잭션을 걸지 않는다 — 요약 카드 조회가 실패해도 목록은 그대로 보이게 각 조회를 따로 둔다
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminNotificationService {

  private final NotificationAdminQueryService notificationAdminQueryService;
  private final AdminMemberFilter adminMemberFilter;

  /// 목록 한 쪽 + 회원 검색이 잘렸는지
  public record SearchResult(Page<AdminNotificationRow> rows, boolean isMemberSearchTruncated) {

  }

  /// 알림 목록: 회원 조건 > 기간·종류·읽음 검색(범위 밖 페이지 보정) > 받는 보호자 표시 이름
  public SearchResult search(AdminListQuery query) {
    AdminMemberFilter.Resolved members = adminMemberFilter.resolve(AdminNotificationList.memberIdOf(query), query.q());
    Page<NotificationAdminView> notifications = AdminListPaging.fetchWithPageCorrection(query,
      corrected -> notificationAdminQueryService.search(searchOf(corrected, members),
        AdminNotificationList.pageableOf(corrected)));
    Map<String, String> displayNameById = adminMemberFilter.displayNamesOf(
      notifications.getContent().stream().map(NotificationAdminView::recipientMemberId).distinct().toList());
    return new SearchResult(
      notifications.map(row -> AdminNotificationRow.of(row, displayNameById.get(row.recipientMemberId()))),
      members.isTruncated());
  }

  /// 회원 요약 카드: 표시 이름, 안 읽음 수, 푸시 설정 (실패하면 비움 — 목록은 그대로 보임)
  public Optional<AdminNotificationMemberSummary> summarizeMember(String memberId) {
    try {
      String displayName = adminMemberFilter.displayNamesOf(List.of(memberId)).get(memberId);
      NotificationPushSettingAdminView setting = notificationAdminQueryService.pushSettingOf(memberId);
      List<TypeSwitch> typeSwitches = Arrays.stream(NotificationType.values())
        .map(type -> new TypeSwitch(type.name(), AdminNotificationList.typeLabelOf(type),
          setting.isTypeEnabledByType().getOrDefault(type, true), setting.isPushDelivered(type)))
        .toList();
      return Optional.of(new AdminNotificationMemberSummary(memberId, displayName,
        notificationAdminQueryService.countUnread(memberId), setting.hasSavedSetting(), setting.isAllEnabled(),
        typeSwitches));
    } catch (RuntimeException e) {
      log.warn("[admin notification] member summary failed : {}", e.getClass().getSimpleName(), e);
      return Optional.empty();
    }
  }

  private static NotificationAdminSearch searchOf(AdminListQuery query, AdminMemberFilter.Resolved members) {
    return new NotificationAdminSearch(AdminListPeriod.periodStart(query), AdminListPeriod.periodEndExclusive(query),
      members.memberIds(), AdminNotificationList.typeOf(query), AdminNotificationList.isReadOf(query));
  }
}
