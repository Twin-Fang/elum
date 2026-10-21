package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.application.dto.response.NotificationAdminView;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationPushSettingAdminView;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 알림 관리자 조회: 목록 검색, 보호자 안 읽음 수, 보호자 푸시 설정 (읽기 전용)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationAdminQueryService {

  private final NotificationRepository notificationRepository;
  private final NotificationSettingRepository notificationSettingRepository;

  /// 알림 목록 한 쪽: 조건 > Specification, 정렬·페이지는 호출부가 정함
  public Page<NotificationAdminView> search(NotificationAdminSearch search, Pageable pageable) {
    if (search.memberIds() != null && search.memberIds().isEmpty()) {
      return Page.empty(pageable);
    }
    return notificationRepository.findAll(specificationOf(search), pageable).map(NotificationAdminView::from);
  }

  public long countUnread(String memberId) {
    return notificationRepository.countByRecipientMemberIdAndReadAtIsNull(memberId);
  }

  /// 보호자 푸시 설정: 저장한 행이 없으면 모두 켜짐 (기본값)
  public NotificationPushSettingAdminView pushSettingOf(String memberId) {
    return notificationSettingRepository.findById(memberId)
      .map(setting -> new NotificationPushSettingAdminView(true, setting.isAllEnabled(), typeSwitchesOf(setting)))
      .orElseGet(() -> new NotificationPushSettingAdminView(false, true, allTypesOn()));
  }

  // 종류 7개 > 설정 칸 (PushDispatcher.isTypeEnabled 와 같은 짝)
  private static Map<NotificationType, Boolean> typeSwitchesOf(NotificationSetting setting) {
    Map<NotificationType, Boolean> isTypeEnabledByType = new EnumMap<>(NotificationType.class);
    for (NotificationType type : NotificationType.values()) {
      isTypeEnabledByType.put(type, switch (type) {
        case ROUTINE_COMPLETED -> setting.isRoutineCompletedEnabled();
        case ROUTINE_SENT_BY_CO_GUARDIAN -> setting.isRoutineSentEnabled();
        case CO_GUARDIAN_JOINED -> setting.isCoGuardianJoinedEnabled();
        case CREDIT_REFILLED -> setting.isCreditRefilledEnabled();
        case FEEDBACK_RESOLVED -> setting.isFeedbackResolvedEnabled();
      });
    }
    return isTypeEnabledByType;
  }

  private static Map<NotificationType, Boolean> allTypesOn() {
    Map<NotificationType, Boolean> isTypeEnabledByType = new EnumMap<>(NotificationType.class);
    for (NotificationType type : NotificationType.values()) {
      isTypeEnabledByType.put(type, true);
    }
    return isTypeEnabledByType;
  }

  // 조건 4개: 마지막 발생 기간(필수), 받는 보호자, 종류, 읽음 여부 (값 없는 조건은 빠짐)
  private static Specification<Notification> specificationOf(NotificationAdminSearch search) {
    return (root, criteriaQuery, builder) -> {
      List<Predicate> predicates = new ArrayList<>();
      predicates.add(builder.greaterThanOrEqualTo(root.get("lastOccurredAt"), search.from()));
      predicates.add(builder.lessThan(root.get("lastOccurredAt"), search.to()));
      if (search.memberIds() != null) {
        predicates.add(root.get("recipientMemberId").in(search.memberIds()));
      }
      if (search.type() != null) {
        predicates.add(builder.equal(root.get("type"), search.type()));
      }
      if (search.isRead() != null) {
        predicates.add(search.isRead() ? builder.isNotNull(root.get("readAt")) : builder.isNull(root.get("readAt")));
      }
      return builder.and(predicates.toArray(new Predicate[0]));
    };
  }
}
