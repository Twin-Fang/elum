import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/show_failure.dart';
import '../../member/application/member_providers.dart';
import '../../profile/application/profile_session.dart';
import '../../profile/domain/profile_summary.dart';
import '../domain/notification_type.dart';
import 'notification_target.dart';

final notificationNavigatorProvider = Provider<NotificationNavigator>(
  NotificationNavigator.new,
);

/// 알림 > 화면 이동: 다른 이룸이 알림이면 그 이룸이로 바꾼 뒤 종류별 화면으로
class NotificationNavigator {
  NotificationNavigator(this._ref);

  final Ref _ref;

  // 이동 중 중복 호출 방지 (연타)
  bool _isOpening = false;

  /// 이룸이 맞추기 > 종류별 이동 (진행 중이면 무시)
  Future<void> open(BuildContext context, NotificationTarget target) async {
    if (_isOpening) return;
    _isOpening = true;
    try {
      final isProfileReady = await _selectProfileIfNeeded(context, target.profileId);
      if (!isProfileReady || !context.mounted) return;
      _goTo(context, target);
    } finally {
      _isOpening = false;
    }
  }

  /// 알림의 이룸이가 지금과 다르면 바꿈. 내 이룸이 목록에 없으면 안내 후 false
  Future<bool> _selectProfileIfNeeded(BuildContext context, String? profileId) async {
    if (profileId == null) return true;
    if (_ref.read(profileSessionProvider).selectedId == profileId) return true;

    final ProfileSummary? profile;
    try {
      profile = await _findAccessibleProfile(profileId);
    } catch (e) {
      // 목록을 못 받은 것과 접근 못 하는 것을 구분
      if (!context.mounted) return false;
      await showFailure(
        context,
        e,
        fallback: context.l10n.notificationListFailed,
        fallbackCode: 'E-NOTIF-PROFILE-LOAD',
      );
      return false;
    }
    if (profile == null) {
      if (!context.mounted) return false;
      await showFailure(
        context,
        null,
        fallback: context.l10n.notificationProfileUnavailable,
        fallbackCode: 'E-NOTIF-PROFILE',
      );
      return false;
    }
    try {
      await _ref.read(profileSessionProvider.notifier).select(profile);
    } catch (e) {
      if (!context.mounted) return false;
      await showFailure(
        context,
        e,
        fallback: context.l10n.notificationListFailed,
        fallbackCode: 'E-NOTIF-PROFILE-SELECT',
      );
      return false;
    }
    return true;
  }

  // 회원 정보의 이룸이 목록에서 찾기 (아직 못 받았으면 한 번 기다림, 받기 실패는 던짐)
  Future<ProfileSummary?> _findAccessibleProfile(String profileId) async {
    var profiles = _ref.read(memberProvider).value?.profiles;
    profiles ??= (await _ref.read(memberProvider.future))?.profiles;
    return profiles?.where((profile) => profile.id == profileId).firstOrNull;
  }

  void _goTo(BuildContext context, NotificationTarget target) {
    switch (target.type) {
      case NotificationType.routineCompleted:
      case NotificationType.routineSentByCoGuardian:
        context.go(Routes.guardian);
      case NotificationType.coGuardianJoined:
        context.push(Routes.guardianPeople);
      case NotificationType.creditRefilled:
        context.push(Routes.guardianCreditHistory);
      case NotificationType.feedbackResolved:
        break; // 이동할 화면 없음
      case NotificationType.talkPostCommented:
      case NotificationType.talkPostImported:
        // 글 id 가 없으면 이야기 칸으로 (지워진 글은 상세 화면이 안내)
        final postId = target.targetId;
        if (postId == null) {
          context.go(Routes.guardianTalk);
        } else {
          context.push(Routes.guardianTalkPostOf(postId));
        }
    }
  }
}
