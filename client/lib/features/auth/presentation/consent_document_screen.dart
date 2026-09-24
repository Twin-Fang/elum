import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../domain/consent_body.dart';
import '../domain/consent_documents.dart';

/// 약관 전문 화면.
///
/// **웹으로 보내지 않는다.** 외부 링크로 넘기면 로그인 흐름이 끊기고,
/// 네트워크가 없으면 읽을 수조차 없다. 읽을 수 없는 상태에서 받은 동의는
/// 고지로서 성립하지 않으므로 본문을 앱에 담아 보여준다.
///
/// ## 🔴 글자 색을 반드시 준다 (이슈 #235)
///
/// `AppTypography.toTextTheme`이 `bodyMedium`에 **보조색(회색)** 을 넣는다.
/// `Text`는 색 없는 스타일을 받으면 그 기본값과 합치므로, 색을 빼먹으면
/// **약관 전체가 회색으로 나온다.** 제목까지 회색이던 것을 여기서 고쳤다.
///
/// ## 시안(`1027:4831`)과 한 군데 다르다 — 덩이 나누기는 남긴다
///
/// 시안은 문서 이름을 뒤로가기 줄에 올리고(600/18, y=78) 본문을 147부터
/// **12/w400 · 줄높이 120%** 로 쭉 흘린다. 그 셋은 그대로 맞췄다.
///
/// 다만 시안 본문은 원문을 통째로 붙여 넣은 TEXT 한 덩이라 섹션도 불릿도
/// 굵기가 같다. 그건 #235가 **일부러 고친 상태**다 — 글자 벽이라 무엇을 읽고
/// 있는지 알 수 없었다. 게다가 시안이 쓴 원문은 지금 서버 문서와 다르다
/// (`아이를 부르는 이름`이라 적혀 있고 OpenAI가 빠져 있다). 본문은 서버가
/// 주는 것이 기준이므로(`figma-dump-vs-png`) 덩이 나누기는 유지했다 (#349).
class ConsentDocumentScreen extends StatelessWidget {
  const ConsentDocumentScreen({super.key, required this.item});

  final ConsentItem item;

  /// 설정 묶음 시안의 뒤로가기 y와 머리↔본문 간격 (`1027:4831`).
  static const _backTop = 67.0;
  static const _headToBody = 40.0;

  /// 섹션 제목 위 여백. 앞 덩이와 붙어 있으면 어디서 장이 바뀌는지 안 보인다.
  static const _sectionTop = 26.0;

  /// 소제목 위 여백 — 섹션보다 얕다.
  static const _subsectionTop = 16.0;

  /// 문단 사이 — **원문의 빈 줄 하나와 같은 14.** 시안(`1027:4831`)은 문단
  /// 사이가 28, 문단 안의 줄 사이가 14다. 즉 빈 줄 하나만큼만 벌어진다.
  /// 10으로 두면 24가 되어 시안보다 4 좁다.
  static const _blockGap = 14.0;

  /// 불릿 점과 글 사이
  static const _bulletGap = 8.0;

  /// 표 행의 이름 칸과 값 칸 사이 (#376). 불릿 점 간격보다 넓어야 이름과 값이
  /// 한 문장으로 읽히지 않는다.
  static const _rowGap = 12.0;

  /// 이름 칸이 본문 폭의 이만큼을 넘으면 값을 이름 아래로 내린다 (#376 L4).
  /// 393 · 글꼴 1.3 에서 가장 긴 이름(`이전되는 국가`)이 약 1/3 이라 나란히 두고,
  /// 360 · 글꼴 2.0 에서는 절반을 넘어 값 칸이 한두 글자씩 꺾이므로 쌓는다.
  static const _stackRatio = 0.4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final blocks = parseConsentBody(item.body);
    final labelWidth = _labelWidth(context, blocks);

    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      // 문서 이름이 곧 제목이다. 본문 위에 다시 쓰지 않는다 (시안 `1027:4831`).
      title: item.label,
      backTop: _backTop,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 머리 하단(67+40=107) → 본문 첫 줄(147). 설정 묶음 공통 40.
            SizedBox(height: _headToBody.h),
            for (final (i, block) in blocks.indexed)
              _block(
                context,
                block,
                i == 0 ? null : blocks[i - 1].kind,
                labelWidth,
              ),
            // 버전은 시안에 없지만 **지운 것이 아니라 끝으로 옮겼다.**
            // 제보를 받았을 때 어느 판을 읽고 동의했는지 맞춰 볼 수 있어야 한다.
            // 첫 화면 밖이라 시안과 맞대는 자리에는 걸리지 않는다.
            SizedBox(height: space.lg.h),
            Text(
              '${item.required ? '필수' : '선택'} · 버전 ${item.version}',
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: space.xl.h),
          ],
        ),
      ),
    );
  }

  /// 덩이 **위**에 둘 여백. 아래가 아니라 위에 두는 이유 —
  /// 앞 덩이가 무엇이었는지에 따라 값이 달라지기 때문이다. 아래에 두면
  /// 불릿 뒤에 오는 문단이 붙어버린다 (불릿끼리는 붙여야 하므로).
  double _gapAbove(ConsentBlockKind? prev, ConsentBlockKind kind) {
    // 첫 덩이는 본문 시작선(147)에 그대로 붙는다.
    if (prev == null) return 0;
    return switch (kind) {
      ConsentBlockKind.section => _sectionTop,
      ConsentBlockKind.subsection => _subsectionTop,
      // 불릿끼리는 붙고, 다른 덩이 뒤에 처음 오는 불릿만 한 줄 띄운다 (시안 실측).
      // 표 행도 원문에서 줄마다 이어 적은 목록이라 불릿과 같이 붙인다 (#376) —
      // 개인정보처리방침 9조는 불릿과 표 행이 섞여 한 목록을 이룬다.
      ConsentBlockKind.bullet ||
      ConsentBlockKind.row => _isList(prev) ? 0.0 : _blockGap,
      ConsentBlockKind.paragraph => _blockGap,
    };
  }

  static bool _isList(ConsentBlockKind kind) =>
      kind == ConsentBlockKind.bullet || kind == ConsentBlockKind.row;

  /// 표 행 이름 칸의 폭 — 문서 안 이름 중 가장 긴 것에 맞춘다.
  ///
  /// 원문은 이름 뒤를 공백으로 채워 **값의 시작선을 맞춘다.** 행마다 이름 폭만큼만
  /// 두면 값이 들쭉날쭉해 표로 안 읽힌다. 글꼴 배율을 넣어 재야 큰 글꼴에서도 맞다.
  static double _labelWidth(BuildContext context, List<ConsentBlock> blocks) {
    final style = _labelStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final b in blocks) {
      final label = b.label;
      if (label == null) continue;
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  static TextStyle _labelStyle(BuildContext context) => context.typo.docBody.copyWith(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w700,
      );

  Widget _block(
    BuildContext context,
    ConsentBlock block,
    ConsentBlockKind? prev,
    double labelWidth,
  ) {
    final colors = context.colors;
    final typo = context.typo;

    final body = switch (block.kind) {
      ConsentBlockKind.section => Text(
          block.text,
          style: typo.docSection.copyWith(color: colors.textPrimary),
        ),
      ConsentBlockKind.subsection => Text(
          block.text,
          style: typo.docBody.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      // 점을 따로 그린다. 글이 두 줄로 넘어가도 점 자리에 물리지 않는다.
      ConsentBlockKind.bullet => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '·',
              style: typo.docBody.copyWith(color: colors.textSecondary),
            ),
            SizedBox(width: _bulletGap.w),
            Expanded(
              child: Text(
                block.text,
                style: typo.docBody.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ConsentBlockKind.paragraph => Text(
          block.text,
          style: typo.docBody.copyWith(color: colors.textPrimary),
        ),
      ConsentBlockKind.row => _row(context, block, labelWidth),
    };

    return Padding(
      padding: EdgeInsets.only(top: _gapAbove(prev, block.kind).h),
      child: body,
    );
  }

  /// 표 행 — 이름 칸과 값 칸을 나란히 둔다 (#376).
  ///
  /// 이름이 본문 폭의 [_stackRatio] 를 넘으면(360 폭 · 글꼴 2.0) 값 칸이 좁아져
  /// 한두 글자씩 꺾이므로 **이름 아래로 값을 내린다** (L4). 어느 쪽이든 자르지 않는다.
  Widget _row(BuildContext context, ConsentBlock block, double labelWidth) {
    final colors = context.colors;
    final typo = context.typo;
    final label = Text(block.label ?? '', style: _labelStyle(context));
    final value = Text(
      block.text,
      style: typo.docBody.copyWith(color: colors.textPrimary),
    );

    final cells = LayoutBuilder(
      builder: (context, constraints) {
        final column = labelWidth + _rowGap.w;
        if (column > constraints.maxWidth * _stackRatio) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, value],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: column, child: label),
            Expanded(child: value),
          ],
        );
      },
    );

    if (!block.bulleted) return cells;
    // 불릿 안의 표 행은 점을 남긴다 — 9조처럼 불릿과 섞인 목록에서 줄이 맞는다.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('·', style: typo.docBody.copyWith(color: colors.textSecondary)),
        SizedBox(width: _bulletGap.w),
        Expanded(child: cells),
      ],
    );
  }
}
