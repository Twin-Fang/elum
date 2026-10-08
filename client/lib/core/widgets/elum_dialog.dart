import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';
import '../text/keep_words.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 팝업 위쪽에 놓이는 원형 아이콘.
///
/// 시안 `팝업`(931:4878)의 변형과 1:1 이다. **노란 경고는 없다** — 시안에 그런
/// 변형이 없다. 주의·실패는 모두 [alert] 다.
enum ElumDialogIcon {
  success,

  /// 삭제 — 붉은 원에 휴지통. **보호자 화면에만 쓴다**.
  ///
  /// `warning`과 나누는 기준 — 만들던 것이 사라지면 warning, 이미 저장된
  /// 것이 사라지면 trash다.
  trash,

  /// 붉은 원에 느낌표 — 실패(`로그인실패`)와 확인(`로그아웃/회원탈퇴`) 변형이 함께 쓴다.
  ///
  /// `trash`와 나누는 기준 — 지우는 대상이 눈에 보이는 하나면 trash(일과 삭제),
  /// 그 밖의 실패·주의는 alert다. 이룸이 화면도 같다.
  alert,
}

/// 버튼의 무게. 색만 바꾼다 — 크기·모서리는 어느 쪽이든 같다.
enum ElumDialogTone {
  /// 주 동작. 민트 배경 + 흰 글자.
  primary,

  /// 보조 동작(닫기·취소). 회색 배경 + 검정 글자.
  neutral,

  /// 되돌릴 수 없는 동작·실패 확인. 붉은 배경 + 흰 글자.
  ///
  /// 시안에 노란 버튼이 없어 잃는 나가기도 이 톤이다.
  danger,
}

/// 팝업 버튼 하나.
///
/// [value]는 팝업이 닫히며 돌려주는 값이다. 확인/취소를 구분해 받을 때 쓴다.
class ElumDialogAction<T> {
  const ElumDialogAction({
    required this.label,
    this.value,
    this.tone = ElumDialogTone.primary,
    this.centerLines = false,
  });

  final String label;
  final T? value;
  final ElumDialogTone tone;

  /// 문구가 두 줄로 꺾일 수 있는 버튼 — 줄마다 가운데로 맞춘다.
  /// 두 버튼이 나란한 팝업에서 긴 문구(광고 보고 더 만들기)가 꺾일 때 쓴다.
  final bool centerLines;
}

/// 앱 공통 팝업 (Figma `팝업` 732:5835).
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
///
/// [keepWordsInMessage] 를 켜면 설명을 **띄어쓰기에서만** 줄바꿈한다([keepWords]).
/// 기본은 꺼 둔다 — 다른 팝업은 시안 대조가 글자 단위 줄에 맞춰져 있어, 앱 전체
/// 규칙으로 바꾸면 골든이 함께 흔들린다 (보상 도움말에만 켠다).
Future<T?> showElumDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  ElumDialogIcon? icon,
  List<ElumDialogAction<T>> actions = const [],
  bool barrierDismissible = false,
  bool keepWordsInMessage = false,
  String? code,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    // 배경 막을 읽어 줄 이름. 안 넘기면 기본값이 영어 `Dismiss` 로 읽힌다.
    barrierLabel: context.l10n.commonPopupClose,
    // 시안의 dim — 검정 50%.
    barrierColor: Colors.black.withValues(alpha: 0.5),
    // **화면 전체 가운데에 둔다.** 기본값(true)은 안전영역 안에서 가운데를
    // 잡아, 위 59·아래 21이 다른 만큼 팝업이 19 아래로 내려간다.
    // 시안(`732:5702`·`931:4879`)은 프레임 정중앙이다.
    useSafeArea: false,
    builder: (context) => ElumDialogCard<T>(
      title: title,
      message: message,
      icon: icon,
      actions: actions,
      keepWordsInMessage: keepWordsInMessage,
      code: code,
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
    this.keepWordsInMessage = false,
    this.code,
  });

  final String title;
  final String? message;
  final ElumDialogIcon? icon;
  final List<ElumDialogAction<T>> actions;

  /// 설명을 낱말 단위로 줄바꿈한다 — [showElumDialog] 참조.
  final bool keepWordsInMessage;

  /// 추적용 식별자(`E-AUTH` 등). 문장 아래에 작은 글자로 적는다.
  ///
  /// 문장 안 괄호로 넣지 않는다 — 시안 `로그인실패` 는 문장 하나뿐이라 식별자가
  /// 섞이면 두 줄 문장이 세 줄로 꺾인다. 그래도 제보 단서라 **반드시 보인다**.
  final String? code;

  /// 아이콘 40 · 아이콘↔제목 20 · 제목 묶음↔버튼 32
  static const _iconSize = 40.0;
  static const _iconToTitle = 20.0;
  static const _bodyToActions = 32.0;

  static String _iconAsset(ElumDialogIcon icon) => switch (icon) {
    ElumDialogIcon.success => AppAssets.dialogCheck,
    ElumDialogIcon.trash => AppAssets.dialogTrash,
    ElumDialogIcon.alert => AppAssets.dialogAlert,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 버튼을 넘기지 않은 쪽이 더 흔하다. 확인 하나가 기본값이다.
    final resolved = actions.isEmpty
        ? <ElumDialogAction<T>>[
            ElumDialogAction(label: context.l10n.commonConfirm),
          ]
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
              // 앱 본문색이 아니라 시안 그대로 순검정이다.
              // 두 줄 문장은 시안 `로그인실패` 처럼 줄 간격을 벌린다.
              style: (title.contains('\n')
                      ? context.typo.dialogSentence
                      : context.typo.dialogTitle)
                  .copyWith(color: colors.dialogTitleText),
            ),
            if (message != null) ...[
              SizedBox(height: context.space.sm),
              Text(
                keepWordsInMessage
                    ? keepWords(message!, locale: context.appLocale)
                    : message!,
                // 끊지 말라는 표시가 낭독기에 섞이지 않게 원문을 준다
                semanticsLabel: keepWordsInMessage ? message : null,
                textAlign: TextAlign.center,
                style: context.typo.body.copyWith(color: colors.textSecondary),
              ),
            ],
            if (code != null) ...[
              SizedBox(height: context.space.sm),
              Text(
                code!,
                textAlign: TextAlign.center,
                style: context.typo.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            SizedBox(height: _bodyToActions.h),
            ElumDialogButtonRow(
              children: [
                for (final action in resolved)
                  ElumDialogButton(
                    label: action.label,
                    tone: action.tone,
                    centerLines: action.centerLines,
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
/// [ElumDialogCard] 와 공지 팝업(같은 컴포넌트 세트의 `방침` 변형)이 함께 쓴다.
/// 팝업마다 카드를 따로 그리면 모서리·그림자가 조금씩 어긋나 앱의 다른 팝업과 달라 보인다.
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
  /// 떨어진다. 8로 두면 버튼이 143이 되어 시안보다 2씩 좁아진다.
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
    // 함께 쓰므로, 팝업을 시안에 맞추려고 그것을 건드리면 그쪽까지 바뀐다.
    final (bg, fg) = switch (tone) {
      ElumDialogTone.primary => (colors.checkDone, colors.surface),
      ElumDialogTone.neutral => (
        colors.dialogNeutral,
        colors.dialogNeutralText,
      ),
      ElumDialogTone.danger => (colors.dialogDanger, colors.dangerText),
    };

    // 버튼마다 제 접근성 노드를 세운다. 안 세우면 누르는 동작이 위쪽 노드로 합쳐져
    // 버튼의 영역이 제목·본문까지 덮는다 — 공지 `방침 보기`가 그렇다.
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
