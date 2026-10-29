package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.application.format.AdminValuePreview;
import com.chuseok22.elumserver.admin.application.list.AdminAdRewardList;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionAdminView;

/**
 * 광고 보상 목록·상세의 한 건: 세션 + 회원 표시 이름 + 상태·사유 표시 이름 + 가린 nonce·transaction id
 *
 * @param memberDisplayName 없는 회원(완전 삭제)이면 null
 * @param reasonLabel       거절·만료 사유, 없으면 null
 */
public record AdminAdRewardRow(
  AdRewardSessionAdminView session,
  String memberDisplayName,
  String statusLabel,
  String statusBadgeClass,
  String reasonLabel,
  String noncePreview,
  String transactionIdPreview
) {

  public static AdminAdRewardRow of(AdRewardSessionAdminView session, String memberDisplayName) {
    return new AdminAdRewardRow(session, memberDisplayName,
      AdminAdRewardList.statusLabelOf(session.effectiveStatus()),
      AdminAdRewardList.statusBadgeClassOf(session.effectiveStatus()),
      reasonLabelOf(session),
      AdminValuePreview.previewOf(session.nonce()),
      AdminValuePreview.previewOf(session.transactionId()));
  }

  // 사유: 저장된 거절 사유 > 콜백 없이 만료 > 없음
  private static String reasonLabelOf(AdRewardSessionAdminView session) {
    if (session.rejectReason() != null) {
      return AdminAdRewardList.reasonLabelOf(session.rejectReason());
    }
    return session.isExpiredWithoutCallback() ? AdminAdRewardList.NO_CALLBACK_LABEL : null;
  }
}
