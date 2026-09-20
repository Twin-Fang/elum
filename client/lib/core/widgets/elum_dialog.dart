import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 팝업 위쪽에 놓이는 원형 아이콘.
///
/// 지금은 성공 하나뿐이다. 경고·물음이 생기면 여기에 값을 더하고
/// [_iconAsset]에 에셋을 한 줄 추가한다 — 화면 코드는 건드리지 않는다.
enum ElumDialogIcon {
  success,

  /// 주의 — **붉지 않다.** 아동도 보는 화면이라 빨간 경고를 쓰지 않는다 (#242).
  warning,

  /// 삭제 — 붉은 원에 휴지통. **보호자 화면에만 쓴다** (#258).
  ///
  /// `warning`과 나누는 기준 — 만들던 것이 사라지면 warning, 이미 저장된
  /// 것이 사라지면 trash다.
  trash,
}

/// 버튼의 무게. 색만 바꾼다 — 크기·모서리는 어느 쪽이든 같다.
enum ElumDialogTone {
  /// 주 동작. 민트 배경 + 흰 글자.
  primary,

  /// 보조 동작(닫기·취소). 회색 배경 + 검정 글자.
  neutral,

  /// 되돌릴 수 없는 동작. 붉은 배경 + 흰 글자.
  danger,

  /// 지금 나가면 **잃는다**. 노란 배경 + 흰 글자 (#242).
  ///
  /// `danger`와 나누는 기준 — 계정이나 저장된 것이 사라지면 `danger`,
  /// 만들던 중인 것만 사라지면 `warn`이다.
  warn,
}

/// 팝업 버튼 하나.
///
/// [value]는 팝업이 닫히며 돌려주는 값이다. 확인/취소를 구분해 받을 때 쓴다.
class ElumDialogAction<T> {
  const ElumDialogAction({
    required this.label,
    this.value,
    this.tone = ElumDialogTone.primary,
  });

  final String label;
  final T? value;
  final ElumDialogTone tone;
}

/// 앱 공통 팝업 (Figma `팝업` 732:5835 · 이슈 #232).
///
/// **화면마다 팝업을 새로 그리지 않는다.** 지금 필요한 것은 연결 성공 하나지만
/// 확인·경고·삭제 확인이 곧 따라온다. 그때마다 카드·여백·버튼을 다시 그리면
/// 화면마다 모서리와 간격이 조금씩 어긋난다 — 실제로 하단 시트에서 그랬다.
///
/// 확장 지점은 셋이다.
///
/// - [icon] 위쪽 원형 아이콘. 없으면 그 자리가 통째로 사라진다
/// - [message] 제목 아래 설명. 없으면 생략한다
/// - [actions] 버튼. 비우면 `확인` 하나가 선다. 두 개면 가로로 나눈다
///
/// 돌아오는 값은 눌린 버튼의 [ElumDialogAction.value]다. 바깥을 눌러 닫으면
/// null이므로, **null을 "취소"로 다루는 쪽이 안전하다.**
Future<T?> showElumDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  ElumDialogIcon? icon,
  List<ElumDialogAction<T>> actions = const [],
  bool barrierDismissible = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    // 시안의 dim — 검정 50%.
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => ElumDialogCard<T>(
      title: title,
      message: message,
      icon: icon,
      actions: actions,
    ),
  );
}

/// 팝업 본체. [showElumDialog]가 쓰지만, 골든·테스트에서 직접 세울 수 있게 공개한다.
class ElumDialogCard<T> extends StatelessWidget {
  const ElumDialogCard({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final ElumDialogIcon? icon;
  final List<ElumDialogAction<T>> actions;

  /// 시안 실측 — 카드 322 폭, 좌우 36 여백 (393 − 36×2 = 321).
  static const _cardWidth = 322.0;
  static const _cardRadius = 20.0;

  /// 카드 안쪽 여백 `24 14 14` — 위가 넓은 것은 아이콘이 숨 쉴 자리다.
  static const _padTop = 24.0;
  static const _padSide = 14.0;
  static const _padBottom = 14.0;

  /// 아이콘 40 · 아이콘↔제목 20 · 제목 묶음↔버튼 32
  static const _iconSize = 40.0;
  static const _iconToTitle = 20.0;
  static const _bodyToActions = 32.0;

  /// 버튼 높이 54 · 모서리 8 · 두 개일 때 사이 8
  static const _actionHeight = 54.0;
  static const _actionRadius = 8.0;
  static const _actionGap = 8.0;

  static String _iconAsset(ElumDialogIcon icon) => switch (icon) {
        ElumDialogIcon.success => AppAssets.dialogCheck,
        ElumDialogIcon.warning => AppAssets.dialogWarn,
        ElumDialogIcon.trash => AppAssets.dialogTrash,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 버튼을 넘기지 않은 쪽이 더 흔하다. 확인 하나가 기본값이다.
    final resolved = actions.isEmpty
        ? <ElumDialogAction<T>>[const ElumDialogAction(label: '확인')]
        : actions;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: _cardWidth.w,
        padding: EdgeInsets.fromLTRB(
          _padSide.w,
          _padTop.h,
          _padSide.w,
          _padBottom.h,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(_cardRadius.r),
          boxShadow: [
            BoxShadow(
              color: colors.loginButtonShadow,
              offset: Offset(4.w, 4.h),
              blurRadius: 6.r,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              SvgPicture.asset(
                _iconAsset(icon!),
                width: _iconSize.w,
                height: _iconSize.w,
              ),
              SizedBox(height: _iconToTitle.h),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.typo.dialogTitle
                  .copyWith(color: colors.textPrimary),
            ),
            if (message != null) ...[
              SizedBox(height: context.space.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.typo.body.copyWith(color: colors.textSecondary),
              ),
            ],
            SizedBox(height: _bodyToActions.h),
            _actions(context, resolved),
          ],
        ),
      ),
    );
  }

  /// 버튼 줄. 하나면 꽉 채우고, 둘이면 반씩 나눈다.
  Widget _actions(BuildContext context, List<ElumDialogAction<T>> items) {
    final buttons = <Widget>[];
    for (final (i, action) in items.indexed) {
      if (i > 0) buttons.add(SizedBox(width: _actionGap.w));
      buttons.add(Expanded(child: _button(context, action)));
    }
    return Row(children: buttons);
  }

  Widget _button(BuildContext context, ElumDialogAction<T> action) {
    final colors = context.colors;
    final (bg, fg) = switch (action.tone) {
      ElumDialogTone.primary => (colors.checkDone, colors.surface),
      ElumDialogTone.neutral => (colors.buttonNeutral, colors.buttonNeutralText),
      ElumDialogTone.danger => (colors.danger, colors.dangerText),
      ElumDialogTone.warn => (colors.warn, colors.warnText),
    };

    return AppPressable(
      onTap: () => Navigator.of(context).pop(action.value),
      child: Container(
        height: _actionHeight.h,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_actionRadius.r),
        ),
        alignment: Alignment.center,
        child: Text(
          action.label,
          style: context.typo.dialogAction.copyWith(color: fg),
        ),
      ),
    );
  }
}
