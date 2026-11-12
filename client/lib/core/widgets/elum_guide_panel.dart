import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../haptics/tap_haptics.dart';
import '../l10n/l10n_context.dart';
import '../text/keep_words.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'app_fade_slide_in.dart';
import 'elum_bottom_sheet.dart';
import 'elum_dialog.dart';
import 'elum_sheet_frame.dart';

export 'elum_guide_motion.dart';
export 'elum_guide_parts.dart';

/// 안내 창·시트를 띄우는 자리 2개: 가운데 창 (한 번 읽고 닫음) · 아래 시트 (고를 길이 여럿)
enum ElumGuidePlacement { dialog, sheet }

/// 안내 창·시트 뼈대 (docs/08-design-principles.md 「안내 창·시트 규칙」)
/// 순서: 그림 > 제목(이모지 1개 · 옆 칩) > 한 줄 설명 > 내용 줄 > 주 버튼 1개 > 보조 글자 버튼
class ElumGuidePanel extends StatelessWidget {
  const ElumGuidePanel({
    super.key,
    required this.placement,
    required this.title,
    this.illustration,
    this.titleAccessory,
    this.description,
    this.content = const [],
    this.primaryAction,
    this.secondaryActions = const [],
  });

  final ElumGuidePlacement placement;

  /// 제목 (앞에 이모지 1개까지, 문구에 포함)
  final String title;

  /// 맨 위 그림 ([ElumGuideIllustration] 또는 진행 표시). null 이면 자리 없음
  final Widget? illustration;

  /// 제목 아래 붙는 작은 표지 (요금제 칩 등)
  final Widget? titleAccessory;

  /// 제목 아래 한 줄 설명
  final String? description;

  /// 내용 줄 ([ElumGuideRow] · [ElumGuideNote] · [ElumGuideDivider] · 칸 카드)
  final List<Widget> content;

  /// 채운 주 버튼 (한 화면에 하나). 내용 칸이 제 버튼을 가지면 null
  final ElumGuideAction? primaryAction;

  /// 보조 동작 (글자 버튼 · 닫기)
  final List<Widget> secondaryActions;

  /// 묶음이 떠오르는 거리
  static const _staggerOffset = 8.0;

  /// 머리 > 내용 · 내용 > 주 버튼 간격 (창은 좁아 한 단계 작게)
  double _sectionGap(BuildContext context) =>
      placement == ElumGuidePlacement.sheet ? context.space.lg : context.space.md;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final illustration = this.illustration;
    final titleAccessory = this.titleAccessory;
    final description = this.description;
    final primaryAction = this.primaryAction;
    final sectionGap = _sectionGap(context);
    // 묶음 3개(머리 · 내용 · 버튼)가 위에서부터 차례로 떠오름 (동작 줄이기면 바로 보임)
    Widget stagger(int order, List<Widget> children) => AppFadeSlideIn(
      delay: AppMotion.sectionStagger * order,
      offset: _staggerOffset,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 머리: 그림 > 제목 > 칩 > 한 줄 설명
        stagger(0, [
          if (illustration != null) ...[Center(child: illustration), SizedBox(height: space.md.h)],
          // 제목 · 설명은 어절 단위로 줄바꿈 (날짜가 끼어 길이가 바뀌는 문장)
          Text(
            keepWords(title, locale: context.appLocale),
            semanticsLabel: title,
            textAlign: TextAlign.center,
            style: context.typo.sheetTitle.copyWith(color: colors.sheetTitleText),
          ),
          if (titleAccessory != null) ...[SizedBox(height: space.xs.h), Center(child: titleAccessory)],
          if (description != null) ...[
            SizedBox(height: space.xs.h),
            Text(
              keepWords(description, locale: context.appLocale),
              semanticsLabel: description,
              textAlign: TextAlign.center,
              style: context.typo.sheetDescription.copyWith(color: colors.textSecondary),
            ),
          ],
        ]),
        // 내용 줄
        if (content.isNotEmpty) stagger(1, [SizedBox(height: sectionGap.h), ...content]),
        // 버튼: 주 버튼 1개 > 보조 글자 버튼
        stagger(2, [
          if (primaryAction != null) ...[
            SizedBox(height: sectionGap.h),
            ElumDialogButton(label: primaryAction.label, onTap: withTapHaptic(primaryAction.onTap)),
          ],
          if (secondaryActions.isNotEmpty) ...[SizedBox(height: space.xs.h), ...secondaryActions],
        ]),
      ],
    );
  }
}

/// 주 버튼 하나 (채운 민트)
@immutable
class ElumGuideAction {
  const ElumGuideAction({required this.label, required this.onTap});

  final String label;

  /// null 이면 꺼진 버튼
  final VoidCallback? onTap;
}

/// 안내 창 띄우기 (가운데, 팝업 면 위에 [builder] 의 [ElumGuidePanel])
Future<T?> showElumGuideDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) => showElumDialogContent<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (dialogContext) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: EdgeInsets.zero,
    child: ElumDialogSurface(child: SingleChildScrollView(child: builder(dialogContext))),
  ),
);

/// 안내 시트 띄우기 (아래, 시트 틀 위에 [builder] 의 [ElumGuidePanel])
Future<T?> showElumGuideSheet<T>({required BuildContext context, required WidgetBuilder builder}) =>
    showElumSheet<T>(context: context, builder: (sheetContext) => ElumSheetFrame(child: builder(sheetContext)));
