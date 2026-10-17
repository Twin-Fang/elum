import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_tile.dart';
import '../data/consent_document_repository.dart';
import '../domain/consent_bundle.dart';
import '../domain/consent_documents.dart';
import 'consent_document_screen.dart';

/// 가입한 뒤에도 약관과 개인정보처리방침을 다시 읽는 화면.
///
/// 지금까지는 가입할 때 동의 화면에서만 볼 수 있었다. Apple은 앱 안에서도
/// 쉽게 찾을 수 있어야 한다고 요구한다(가이드라인 5.1.1(i)).
///
/// **문서를 새로 만들지 않고 동의 화면과 같은 묶음을 쓴다.** 서버 → 캐시 →
/// 앱 번들 순서도 그대로 따라가므로, 관리자가 고친 최신본이 보이고 네트워크가
/// 없어도 읽을 수 있다. 여기에 별도 본문을 두면 동의 화면과 조용히 어긋난다.
class ConsentDocumentListScreen extends ConsumerWidget {
  const ConsentDocumentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(consentBundleProvider);

    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      // 제목은 뒤로가기와 같은 줄에 선다 (Figma `1274:9315`)
      title: context.l10n.consentListTitle,
      // 설정 계열 머리: 뒤로가기 y=67, 줄 x=16
      backTop: 67,
      horizontalPadding: 16,
      // 스크롤 고정 영역 높이 115 (뒤로가기 하단 107 + 8), 스크롤하는 줄이 제목 아래로 비치지 않게 한다
      child: Padding(
        padding: EdgeInsets.only(top: _fixedAreaExtraHeight.h),
        child: SingleChildScrollView(
          // 읽어 오는 동안에도 제목은 그대로 선다. 흰 화면을 띄우면 멈춘 것처럼 보인다.
          //
          // 이 provider는 실패하지 않는다 — 서버·캐시가 모두 없으면 앱 번들 기본값이
          // 온다. 그래도 error를 대비하는 것은, 예상 못 한 예외로 **약관을 아예 못 읽는
          // 상태**가 되는 것을 막기 위해서다.
          child: bundle.maybeWhen(
            data: (data) => _list(context, data),
            orElse: () => bundle.hasError
                ? _list(context, ConsentBundle.bundled)
                : _list(context, null),
          ),
        ),
      ),
    );
  }

  /// 스크롤 고정 영역(115)과 뒤로가기 하단(107)의 차
  static const _fixedAreaExtraHeight = 8.0;

  /// 고정 영역 하단(115) > 첫 묶음 제목(131)
  static const _firstGroupTop = 16.0;

  /// 첫 묶음 카드 하단(383) > 두 번째 묶음 제목(407)
  static const _groupGap = 24.0;

  Widget _list(BuildContext context, ConsentBundle? bundle) {
    final space = context.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _firstGroupTop.h),
        if (bundle == null)
          // 캐시가 없는 첫 실행에서만 잠깐 보인다. 상한은 약관 대기 시간과 같다.
          Padding(
            padding: EdgeInsets.only(top: space.xl),
            child: Text(
              context.l10n.consentLoading,
              textAlign: TextAlign.center,
              style: context.typo.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          )
        else ...[
          // 필수와 선택을 나눠 보여준다 (무엇을 빼도 되는지 구분)
          _ConsentGroup(
            title: context.l10n.consentGroupRequired,
            items: bundle.requiredItems.toList(),
          ),
          if (bundle.optionalItems.isNotEmpty) ...[
            SizedBox(height: _groupGap.h),
            _ConsentGroup(
              title: context.l10n.consentGroupOptional,
              items: bundle.optionalItems.toList(),
            ),
          ],
        ],
        SizedBox(height: space.xl),
      ],
    );
  }
}

/// 묶음 하나: 제목(`필수항목`) > 흰 카드 안 문서 줄들
class _ConsentGroup extends StatelessWidget {
  const _ConsentGroup({required this.title, required this.items});

  final String title;
  final List<ConsentItem> items;

  /// 제목 하단 > 카드 상단 (제목 높이 16, 카드 y=28)
  static const _titleToCardGap = 12.0;

  /// 제목 글자 시작선: 카드 왼쪽에서 20
  static const _titleLeft = 20.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: _titleLeft.w),
          child: Text(
            title,
            style: context.typo.settingsTileLabel.copyWith(
              color: context.colors.settingsCardLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: _titleToCardGap.h),
        SettingsGroup(
          hasDividers: false,
          children: [
            for (final item in items)
              SettingsTile(
                isInCard: true,
                label: item.label,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConsentDocumentScreen(item: item),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
