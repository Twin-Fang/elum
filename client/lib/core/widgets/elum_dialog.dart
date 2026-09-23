import 'dart:math' as math;

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

  /// 되돌릴 수 없는 것을 묻는다 — 붉은 원에 느낌표 (`팝업` 변형 `로그아웃/회원탈퇴`).
  ///
  /// `trash`와 나누는 기준 — 지우는 대상이 눈에 보이는 하나면 trash(일과 삭제),
  /// 계정처럼 통째로 끝나는 것이면 alert다.
  alert,
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
    // **화면 전체 가운데에 둔다.** 기본값(true)은 안전영역 안에서 가운데를
    // 잡아, 위 59·아래 21이 다른 만큼 팝업이 19 아래로 내려간다 (#297).
    // 시안(`732:5702`·`931:4879`)은 프레임 정중앙이다.
    useSafeArea: false,
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

  /// 아이콘 40 · 아이콘↔제목 20 · 제목 묶음↔버튼 32
  static const _iconSize = 40.0;
  static const _iconToTitle = 20.0;
  static const _bodyToActions = 32.0;

  static String _iconAsset(ElumDialogIcon icon) => switch (icon) {
    ElumDialogIcon.success => AppAssets.dialogCheck,
    ElumDialogIcon.warning => AppAssets.dialogWarn,
    ElumDialogIcon.trash => AppAssets.dialogTrash,
    ElumDialogIcon.alert => AppAssets.dialogAlert,
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
      child: ElumDialogSurface(
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
              // 앱 본문색이 아니라 시안 그대로 순검정이다 (#318)
              style: context.typo.dialogTitle.copyWith(
                color: colors.dialogTitleText,
              ),
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
            ElumDialogButtonRow(
              children: [
                for (final action in resolved)
                  ElumDialogButton(
                    label: action.label,
                    tone: action.tone,
                    onTap: () => Navigator.of(context).pop(action.value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 팝업 카드 면 — 폭·안쪽 여백·모서리·그림자 (시안 `팝업` 931:4878 공통).
///
/// [ElumDialogCard] 와 공지 팝업(#390, 같은 컴포넌트 세트의 `방침` 변형)이 함께 쓴다.
/// 팝업마다 카드를 따로 그리면 모서리·그림자가 조금씩 어긋난다 — 공지가 한때
/// 웹 공지 모양으로 따로 그려져 앱의 다른 팝업과 달라 보였다 (#390).
class ElumDialogSurface extends StatelessWidget {
  const ElumDialogSurface({
    super.key,
    required this.child,
    this.padTop = defaultPadTop,
    this.padSides = true,
  });

  final Widget child;

  /// 좌우 여백을 카드가 줄지. 공지처럼 **안에서 스크롤되는 글**이 있으면 false 로 두고
  /// 자식이 직접 [padSide] 를 준다 — 그래야 스크롤 막대가 글 위가 아니라 여백에 선다.
  final bool padSides;

  /// 위 여백. 기본 24 는 아이콘·제목이 숨 쉴 자리다. 공지의 그림처럼 **면을 채우는
  /// 것**이 맨 위에 오면 옆·아래와 같은 [padSide] 로 줄인다.
  final double padTop;

  /// 시안 실측 — 카드 322 폭, 좌우 36 여백 (393 − 36×2 = 321).
  static const cardWidth = 322.0;
  static const radius = 20.0;

  /// 카드 안쪽 여백 `24 14 14` — 위가 넓은 것은 아이콘이 숨 쉴 자리다.
  static const defaultPadTop = 24.0;
  static const padSide = 14.0;
  static const padBottom = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: cardWidth.w,
      padding: EdgeInsets.fromLTRB(
        padSides ? padSide.w : 0,
        padTop.h,
        padSides ? padSide.w : 0,
        padBottom.h,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.r),
        boxShadow: [
          BoxShadow(
            color: colors.loginButtonShadow,
            offset: Offset(4.w, 4.h),
            blurRadius: 6.r,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 버튼 줄. 하나면 꽉 채우고, 둘이면 반씩 나눈다.
///
/// **두 버튼 높이를 맞춘다.** 한쪽 문구만 두 줄로 꺾이면(공지의 긴 버튼 문구) 그쪽만
/// 키가 커져 줄이 들쭉날쭉해진다. 한 줄일 때는 둘 다 최소 높이라 모양이 같다.
class ElumDialogButtonRow extends StatelessWidget {
  const ElumDialogButtonRow({super.key, required this.children});

  final List<Widget> children;

  /// 두 개일 때 사이 4.
  ///
  /// **사이는 4다(8이 아니다).** 카드 안쪽 폭이 294라 `145 + 4 + 145`로 딱
  /// 떨어진다. 8로 두면 버튼이 143이 되어 시안보다 2씩 좁아진다 (#318).
  static const gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final row = <Widget>[];
    for (final (i, child) in children.indexed) {
      if (i > 0) row.add(SizedBox(width: gap.w));
      row.add(Expanded(child: child));
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: row),
    );
  }
}

/// 팝업 버튼 하나 — 높이 54 · 모서리 8 · 18/w600 (시안 `팝업` 931:4878 공통).
class ElumDialogButton extends StatelessWidget {
  const ElumDialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = ElumDialogTone.primary,
    this.semanticsLabel,
    this.centerLines = false,
  });

  /// 보이는 문구. 공지처럼 어절 단위로 끊으려면 표시를 넣은 문구를 주고
  /// [semanticsLabel] 에 원문을 준다.
  final String label;
  final VoidCallback? onTap;
  final ElumDialogTone tone;
  final String? semanticsLabel;

  /// 문구가 두 줄로 꺾일 수 있는 버튼(공지의 관리자 문구). 줄마다 가운데로 맞춘다.
  final bool centerLines;

  static const height = 54.0;
  static const radius = 8.0;

  /// 문구가 두 줄로 꺾일 때 가장자리에 붙지 않게 둔다. 한 줄 문구는 가운데라 영향이 없다.
  static const _padH = 8.0;
  static const _padV = 8.0;

  /// 손가락 자리 최소 44 (docs/08 §7-2). 높이는 `.h` 로 줄어드는데, 세로가 짧은
  /// 휴대폰(640)에서는 54 가 41 이 된다. 852 기준 화면에서는 54 그대로라 시안과 같다.
  static const _minTap = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 팝업 전용 토큰을 쓴다. `buttonNeutral`·`danger`는 설정 화면과 연결 암호도
    // 함께 쓰므로, 팝업을 시안에 맞추려고 그것을 건드리면 그쪽까지 바뀐다 (#318).
    final (bg, fg) = switch (tone) {
      ElumDialogTone.primary => (colors.checkDone, colors.surface),
      ElumDialogTone.neutral => (
        colors.dialogNeutral,
        colors.dialogNeutralText,
      ),
      ElumDialogTone.danger => (colors.dialogDanger, colors.dangerText),
      ElumDialogTone.warn => (colors.warn, colors.warnText),
    };

    // 버튼마다 제 접근성 노드를 세운다. 안 세우면 누르는 동작이 위쪽 노드로 합쳐져
    // 버튼의 영역이 제목·본문까지 덮는다 — 공지 `방침 보기`가 그랬다 (#385 C).
    return Semantics(
      container: true,
      button: true,
      child: AppPressable(
        onTap: onTap,
        // Container 로 둔다 — 설정 화면 테스트가 버튼 문구 뒤의 면 색을 Container 로 찾는다.
        child: Container(
          constraints: BoxConstraints(minHeight: math.max(height.h, _minTap)),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV),
          child: Center(
            child: Text(
              label,
              semanticsLabel: semanticsLabel,
              // 한 줄 문구에 가운데 정렬을 걸면 글자가 0.1px 쯤 밀려 기존 팝업 골든이
              // 전부 깨진다. 꺾일 수 있는 문구에만 건다.
              textAlign: centerLines ? TextAlign.center : null,
              style: context.typo.dialogAction.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
