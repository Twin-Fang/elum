import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_label_chip.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/min_tap_target.dart';
import '../../../member/domain/guardian_account.dart';
import 'guardian_nickname_sheet.dart';
import 'sign_in_provider_badge.dart';

/// 내 정보 닉네임 카드 (시안 1736:8780): 닉네임 + 보호자 칩 + 연필 > 가입 배지 + 가린 이메일 > 가입일
///
/// 회원 정보를 못 받았거나 닉네임이 없으면 "보호자"만 이름 자리에 두고 칩·연필은 숨김
class MyInfoNicknameCard extends StatelessWidget {
  const MyInfoNicknameCard({super.key, required this.account});

  final GuardianAccount? account;

  /// 시안 실측 (카드 높이 138): 위 7 > 제목 줄 44(연필 누름) > 7 > 이메일 줄 24 > 14 > 가입일 줄 24 > 아래 18
  static const _padTop = 7.0;
  static const _padBottom = 18.0;
  static const _padH = 20.0;
  static const _titleToEmail = 7.0;
  static const _emailToJoined = 14.0;

  /// 정보 줄 아이콘 자리 24 · 달력 그림 20 · 아이콘과 글 사이 8
  static const _infoIconSlot = 24.0;
  static const _calendarIconSize = 20.0;
  static const _infoIconToText = 8.0;

  /// 이름과 칩 사이 8 · 연필 그림 16 (누름 영역 44 가 칩 옆 여백을 겸함)
  static const _nameToChip = 8.0;
  static const _pencilIconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final account = this.account;
    final nickname = account?.nickname;
    final joinedAt = account?.joinedAt;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(_padH.w, _padTop.h, _padH.w, _padBottom.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleRow(context, nickname),
            // 계정 정보 (회원 정보 받았을 때만)
            if (account != null) ...[
              SizedBox(height: _titleToEmail.h),
              _InfoRow(
                leading: _emailLeading(context, account),
                text:
                    account.maskedEmail ??
                    context.l10n.guardianMyInfoEmailPrivate,
                isMuted: account.maskedEmail == null,
              ),
              if (joinedAt != null) ...[
                SizedBox(height: _emailToJoined.h),
                _InfoRow(
                  leading: SvgPicture.asset(
                    AppAssets.iconCalendar,
                    width: _calendarIconSize.w,
                    height: _calendarIconSize.w,
                    colorFilter: ColorFilter.mode(
                      colors.myInfoMutedIcon,
                      BlendMode.srcIn,
                    ),
                    excludeFromSemantics: true,
                  ),
                  text: context.l10n.guardianMyInfoJoinedOn(joinedAt),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 제목 줄: 닉네임(바뀌면 겹쳐 바뀜) + 보호자 칩 + 연필 (닉네임 있을 때만 칩·연필)
  Widget _buildTitleRow(BuildContext context, String? nickname) {
    final colors = context.colors;
    final name = Text(
      nickname ?? context.l10n.guardianMyInfoProfileName,
      key: ValueKey(nickname),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typo.myInfoNickname.copyWith(color: colors.textPrimary),
    );
    return SizedBox(
      height: MinTapTarget.minimumSize.w,
      child: Row(
        children: [
          Flexible(
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: name,
            ),
          ),
          if (nickname != null) ...[
            SizedBox(width: _nameToChip.w),
            ElumLabelChip(
              label: context.l10n.guardianMyInfoProfileName,
              background: colors.peopleGuardianChipBg,
              foreground: colors.peopleGuardianChipText,
              border: colors.peopleGuardianChipBorder,
            ),
            AppPressable(
              onTap: () => _openNicknameSheet(context, nickname),
              scaleDown: AppPressable.scaleIcon,
              semanticLabel: context.l10n.guardianNicknameEditLabel,
              child: MinTapTarget(
                child: SvgPicture.asset(
                  AppAssets.iconPencilEdit,
                  width: _pencilIconSize.w,
                  height: _pencilIconSize.w,
                  colorFilter: ColorFilter.mode(
                    colors.myInfoMutedIcon,
                    BlendMode.srcIn,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 연필: 7일 제한 중이면 언제부터인지 알림 > 아니면 시트 > 저장했으면 알림
  Future<void> _openNicknameSheet(BuildContext context, String nickname) async {
    final account = this.account;
    final changeableAt = account?.nicknameChangeableAt;
    if (account != null &&
        changeableAt != null &&
        !account.canChangeNicknameAt(DateTime.now())) {
      final l10n = context.l10n;
      showElumToast(
        context,
        l10n.guardianNicknameChangeableFrom(l10n.monthDaySince(changeableAt)),
      );
      return;
    }
    // 시트가 닫힌 뒤 카드가 다시 그려져도 알림은 띄울 수 있게 미리 잡아 둠
    final messenger = ScaffoldMessenger.maybeOf(context);
    final changedMessage = context.l10n.guardianNicknameChanged;
    final isSaved = await showGuardianNicknameSheet(
      context,
      currentNickname: nickname,
    );
    if (isSaved) showElumToastOn(messenger, changedMessage);
  }

  /// 가입 방법 배지 (아이디·비밀번호 가입이면 편지 아이콘)
  Widget _emailLeading(BuildContext context, GuardianAccount account) {
    final provider = account.signInProvider;
    if (provider == null) {
      return Icon(
        Icons.mail_outline_rounded,
        size: _calendarIconSize.w,
        color: context.colors.myInfoMutedIcon,
      );
    }
    return SignInProviderBadge(provider: provider, size: _infoIconSlot);
  }
}

/// 아이콘 자리(24) + 한 줄 글 (길면 말줄임)
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.leading,
    required this.text,
    this.isMuted = false,
  });

  final Widget leading;
  final String text;

  /// 비공개처럼 값이 없는 줄은 흐리게
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final slot = MyInfoNicknameCard._infoIconSlot.w;
    return Row(
      children: [
        SizedBox(
          width: slot,
          height: slot,
          child: Center(child: leading),
        ),
        SizedBox(width: MyInfoNicknameCard._infoIconToText.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typo.myInfoMeta.copyWith(
              color: isMuted ? colors.textPlaceholder : colors.myInfoMetaText,
            ),
          ),
        ),
      ],
    );
  }
}
