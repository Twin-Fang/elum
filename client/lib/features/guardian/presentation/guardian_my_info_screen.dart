import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../member/application/member_providers.dart';
import '../../member/domain/guardian_account.dart';
import '../../notification/application/unread_summary_provider.dart';
import 'widgets/ai_credit_card.dart';
import 'widgets/my_info_elumi_group.dart';
import 'widgets/sign_in_provider_badge.dart';

/// 하단 바 내정보 칸의 첫 화면: 보호자 프로필 > 이룸이 > AI 크레딧(사용 내역 링크 포함) > 바로가기 (#817)
///
/// 설정은 오른쪽 위 아이콘으로만 들어간다. 이룸이가 여러 명이어도(교육 라이선스) 같은 구조로 늘어난다.
/// 회원 정보를 못 받으면 이룸이 영역만 빠지고 나머지는 그대로 뜬다 (화면이 회원 정보에 막히지 않게).
class GuardianMyInfoScreen extends ConsumerWidget {
  const GuardianMyInfoScreen({super.key});

  /// 카드 묶음 사이 간격 (설정 화면과 같다)
  static const _groupGap = 16.0;

  /// 설정 아이콘 크기 · 누름 영역 한 변
  static const _gearIconSize = 26.0;
  static const _gearTapSize = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final colors = context.colors;
    final profiles = ref.watch(
      memberProvider.select((member) => member.value?.profiles),
    );
    final account = ref.watch(
      memberProvider.select((member) => member.value?.account),
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 제목 줄 (제목 | 설정 아이콘)
            Padding(
              padding: EdgeInsets.fromLTRB(
                space.screenH.w,
                space.sm.h,
                space.screenH.w - (_gearTapSize - _gearIconSize) / 2,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.guardianTabMe,
                      style: context.typo.greeting.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  AppPressable(
                    onTap: () => context.push(Routes.guardianSettings),
                    scaleDown: AppPressable.scaleIcon,
                    semanticLabel: context.l10n.guardianSettingsTitle,
                    child: SizedBox(
                      width: _gearTapSize.w,
                      height: _gearTapSize.w,
                      child: Icon(
                        Icons.settings_outlined,
                        size: _gearIconSize.w,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  space.screenH.w,
                  space.md.h,
                  space.screenH.w,
                  space.lg.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(account: account),
                    // 이룸이 목록: 회원 정보를 받았고 1명 이상일 때만
                    if (profiles != null && profiles.isNotEmpty) ...[
                      SizedBox(height: _groupGap.h),
                      MyInfoElumiGroup(profiles: profiles),
                    ],
                    SizedBox(height: _groupGap.h),
                    // 이번 주 AI 생성: 꺼져 있으면 자리도 없고, 아래 간격은 카드가 가진다
                    const AiCreditCard(),
                    SettingsGroup(
                      hasDividers: false,
                      children: [
                        SettingsTile(
                          isInCard: true,
                          label: context.l10n.guardianSettingsPeople,
                          onTap: () => context.push(Routes.guardianPeople),
                        ),
                        SettingsTile(
                          isInCard: true,
                          label: context.l10n.guardianSettingsDrafts,
                          onTap: () => context.push(Routes.guardianDrafts),
                        ),
                        SettingsTile(
                          isInCard: true,
                          label: context.l10n.notificationTabNotices,
                          onTap: () => _openNotices(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공지사항 탭 열기 > 돌아오면 종 아이콘 점 다시 받기 (본 공지 기록이 바뀌었을 수 있음)
Future<void> _openNotices(BuildContext context, WidgetRef ref) async {
  await context.push(Routes.guardianNotices);
  await ref.read(unreadSummaryProvider.notifier).refresh();
}

/// 보호자 프로필 카드: 역할 > 닉네임 > 가입 방법 배지 + 가린 이메일 > 가입일 (#849)
///
/// 회원 정보를 못 받았거나 닉네임이 아직 없으면 "보호자"만 이름 자리에 둔다.
/// 사진 변경은 지원하지 않아 사람 아이콘 자리를 두지 않는다.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.account});

  final GuardianAccount? account;

  /// 정보 줄 아이콘(배지 포함) 한 변
  static const _infoIconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;
    final nickname = account?.nickname;
    final joinedAt = account?.joinedAt;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(space.md.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 역할 (닉네임 있을 때만 작은 글씨로 위에)
            if (nickname != null) ...[
              Text(
                context.l10n.guardianMyInfoProfileName,
                style: typo.bodySmall.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: space.xs.h),
            ],
            Text(
              nickname ?? context.l10n.guardianMyInfoProfileName,
              style: typo.sectionTitle.copyWith(color: colors.textPrimary),
            ),
            // 계정 정보 (회원 정보 받았을 때만)
            if (account != null) ...[
              SizedBox(height: space.sm.h),
              _InfoRow(
                leading: _emailLeading(context, account!),
                text: account!.maskedEmail ?? context.l10n.guardianMyInfoEmailPrivate,
                isMuted: account!.maskedEmail == null,
              ),
              if (joinedAt != null) ...[
                SizedBox(height: space.xs.h),
                _InfoRow(
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    size: _infoIconSize.w,
                    color: colors.textSecondary,
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

  /// 가입 방법 배지 (아이디·비밀번호 가입이면 편지 아이콘)
  Widget _emailLeading(BuildContext context, GuardianAccount account) {
    final provider = account.signInProvider;
    if (provider == null) {
      return Icon(
        Icons.mail_outline_rounded,
        size: _infoIconSize.w,
        color: context.colors.textSecondary,
      );
    }
    return SignInProviderBadge(provider: provider, size: _infoIconSize);
  }
}

/// 아이콘 + 한 줄 글 (길면 말줄임)
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
    return Row(
      children: [
        leading,
        SizedBox(width: context.space.sm.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typo.bodySmall.copyWith(
              color: isMuted ? colors.textPlaceholder : colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
