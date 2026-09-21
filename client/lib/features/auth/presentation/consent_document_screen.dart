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
class ConsentDocumentScreen extends StatelessWidget {
  const ConsentDocumentScreen({super.key, required this.item});

  final ConsentItem item;

  /// 섹션 제목 위 여백. 앞 덩이와 붙어 있으면 어디서 장이 바뀌는지 안 보인다.
  static const _sectionTop = 26.0;

  /// 소제목 위 여백 — 섹션보다 얕다.
  static const _subsectionTop = 16.0;

  /// 문단·불릿 사이
  static const _blockGap = 10.0;

  /// 불릿 점과 글 사이
  static const _bulletGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final blocks = parseConsentBody(item.body);

    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: space.md.h),
            Text(
              item.required ? '[필수] ${item.label}' : '[선택] ${item.label}',
              // 색을 준다 — 없으면 회색으로 나온다 (클래스 주석 참조).
              style: context.typo.headline.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: space.xs.h),
            Text(
              '버전 ${item.version}',
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: space.md.h),
            for (final block in blocks) _block(context, block),
            SizedBox(height: space.xl.h),
          ],
        ),
      ),
    );
  }

  Widget _block(BuildContext context, ConsentBlock block) {
    final colors = context.colors;
    final typo = context.typo;

    return switch (block.kind) {
      ConsentBlockKind.section => Padding(
          padding: EdgeInsets.only(top: _sectionTop.h, bottom: _blockGap.h / 2),
          child: Text(
            block.text,
            style: typo.docSection.copyWith(color: colors.textPrimary),
          ),
        ),
      ConsentBlockKind.subsection => Padding(
          padding:
              EdgeInsets.only(top: _subsectionTop.h, bottom: _blockGap.h / 2),
          child: Text(
            block.text,
            style: typo.docBody.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      // 점을 따로 그린다. 글이 두 줄로 넘어가도 점 자리에 물리지 않는다.
      ConsentBlockKind.bullet => Padding(
          padding: EdgeInsets.only(bottom: _blockGap.h / 2),
          child: Row(
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
        ),
      ConsentBlockKind.paragraph => Padding(
          padding: EdgeInsets.only(bottom: _blockGap.h),
          child: Text(
            block.text,
            style: typo.docBody.copyWith(color: colors.textPrimary),
          ),
        ),
    };
  }
}
