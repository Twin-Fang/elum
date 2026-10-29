import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_fade_slide_in.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../member/application/member_providers.dart';
import '../../notification/application/unread_summary_provider.dart';
import 'widgets/ai_credit_card.dart';
import 'widgets/my_info_elumi_group.dart';
import 'widgets/my_info_nickname_card.dart';

/// 하단 바 내정보 칸의 첫 화면 (시안 1736:8780): AI 크레딧 > 닉네임 > 이룸이 > 바로가기
///
/// 카드 묶음이 위에서부터 차례로 올라오며 나타남 (탭을 처음 열 때 한 번).
/// 회원 정보를 못 받으면 이룸이 카드만 빠지고 나머지는 그대로 뜸 (화면이 회원 정보에 막히지 않게)
class GuardianMyInfoScreen extends ConsumerWidget {
  const GuardianMyInfoScreen({super.key});

  /// 카드 묶음 사이 간격 (시안 gap 16)
  static const _groupGap = 16.0;

  /// 시안 실측: 제목 줄 왼쪽 24 · 카드 좌우 16 · 제목 줄 > 첫 카드 20
  static const _cardsH = 16.0;
  static const _titleToCards = 20.0;

  /// 설정 톱니 그림 24 · 누름 영역 44
  static const _gearIconSize = 24.0;
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

    // 위에서부터 차례로 나타날 묶음 (크레딧이 꺼져 있으면 자리도 간격도 없음 > 카드가 아래 간격을 가짐)
    final sections = <Widget>[
      const AiCreditCard(),
      MyInfoNicknameCard(account: account),
      if (profiles != null && profiles.isNotEmpty) ...[
        SizedBox(height: _groupGap.h),
        MyInfoElumiGroup(profiles: profiles),
      ],
      SizedBox(height: _groupGap.h),
      _buildShortcuts(context, ref),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTitleRow(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  _cardsH.w,
                  _titleToCards.h,
                  _cardsH.w,
                  space.lg.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _staggered(sections),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 간격이 아닌 묶음만 순서대로 늦춰 등장 (간격은 그대로 자리만 지킴)
  List<Widget> _staggered(List<Widget> sections) {
    var order = 0;
    return [
      for (final section in sections)
        if (section is SizedBox)
          section
        else
          AppFadeSlideIn(
            delay: AppMotion.sectionStagger * order++,
            child: section,
          ),
    ];
  }

  /// 제목 줄: 제목 | 설정 톱니 (톱니 누름 영역이 오른쪽 여백을 겸함)
  Widget _buildTitleRow(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    return Padding(
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
              style: context.typo.libraryTitle.copyWith(
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
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.iconSettings,
                  width: _gearIconSize.w,
                  height: _gearIconSize.w,
                  colorFilter: ColorFilter.mode(
                    colors.myInfoMetaText,
                    BlendMode.srcIn,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 바로가기 5줄: 함께하는 사람 · 임시저장 · 내가 쓴 글 · 공지사항 · 숨긴 보호자
  Widget _buildShortcuts(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
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
          label: context.l10n.talkMyPostsTitle,
          onTap: () => context.push(Routes.guardianTalkMine),
        ),
        SettingsTile(
          isInCard: true,
          label: context.l10n.notificationTabNotices,
          onTap: () => _openNotices(context, ref),
        ),
        SettingsTile(
          isInCard: true,
          label: context.l10n.talkBlockedGuardiansTitle,
          onTap: () => context.push(Routes.guardianTalkBlocks),
        ),
      ],
    );
  }
}

/// 공지사항 탭 열기 > 돌아오면 종 아이콘 점 다시 받기 (본 공지 기록이 바뀌었을 수 있음)
Future<void> _openNotices(BuildContext context, WidgetRef ref) async {
  await context.push(Routes.guardianNotices);
  await ref.read(unreadSummaryProvider.notifier).refresh();
}
