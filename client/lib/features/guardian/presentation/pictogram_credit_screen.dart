import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/app_status/store_launcher.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';

/// 주소를 여는 함수. 테스트는 실제 브라우저 대신 가짜를 넣는다.
typedef LinkLauncher = Future<bool> Function(Uri url);

/// [openStore] 는 이름만 스토어일 뿐 외부 앱으로 주소를 여는 함수다 — 새로 짜지 않고 재사용한다.
final linkLauncherProvider = Provider<LinkLauncher>((ref) => openStore);

/// `그림 출처` 화면 — 카드 그림에 쓰는 무료 픽토그램의 저작자 표기 (#469).
///
/// Mulberry Symbols 는 CC BY-SA 4.0 이라 **앱 안에서 저작자와 라이선스를 밝혀야** 한다.
/// 표기문은 저작자가 권장한 원문 그대로 둔다 — 번역하거나 줄이면 표기가 성립하지 않는다.
///
/// ⚠️ **임시 시안이다.** 시안이 없어 설정의 약관 화면 모양을 따랐다 (디자인 요청 #459).
///
/// 주소는 글자로도 항상 보여준다. 브라우저를 못 열어도(기기 설정·제한) 직접 찾아갈 수 있어야 한다.
class PictogramCreditScreen extends ConsumerWidget {
  const PictogramCreditScreen({super.key});

  /// 저작자가 권장한 표기문 원문 (mulberrysymbols.org). **고치지 않는다.**
  static const attribution =
      'Mulberry Symbols by Steve Lee are licenced under the Creative Commons '
      'Attribution-ShareAlike 4.0 License. See https://mulberrysymbols.org for details';

  static const copyright = 'Copyright 2018-2026 Steve Lee';
  static const siteUrl = 'https://mulberrysymbols.org';
  static const licenseUrl = 'https://creativecommons.org/licenses/by-sa/4.0/';

  /// 링크 줄의 키 — 테스트가 누른다.
  static const siteKey = ValueKey('credit-site-link');
  static const licenseKey = ValueKey('credit-license-link');

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final opened = await ref.read(linkLauncherProvider)(Uri.parse(url));
    if (opened || !context.mounted) return;
    // 열지 못해도 화면은 그대로다. 주소가 아래에 적혀 있어 직접 찾아갈 수 있다.
    await showFailure(
      context,
      null,
      title: '주소를 열지 못했어요',
      fallback: '화면에 적힌 주소를 직접 열어주세요',
      fallbackCode: 'E-LINK',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;

    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      title: '그림 출처',
      // 설정 묶음 화면과 같은 자리 (뒤로가기 y=67, 첫 줄 y=147)
      backTop: 67,
      horizontalPadding: 16,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40.h),
              Text(
                // 해요체·능동형 두 줄. 법적 문구가 아니라 앱이 하는 설명이다.
                '카드에 나오는 그림 중 일부는 Mulberry Symbols 예요.\n'
                '만든 분을 밝히고 같은 조건으로 나누는 조건(CC BY-SA 4.0)으로 쓸 수 있는 무료 그림이에요. '
                '색이나 모양을 바꾸지 않고 그대로 써요.',
                // 약관 본문(12)보다 크게 — 이 화면의 설명은 누구나 한 번에 읽혀야 한다
                style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: space.lg.h),
              Text(
                '표기',
                style: context.typo.docSection.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: space.xs.h),
              // 복사·검색이 되게 선택 가능하게 둔다
              SelectableText(
                attribution,
                style: context.typo.docBody.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: space.sm.h),
              SelectableText(
                copyright,
                style: context.typo.docBody.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: space.lg.h),
              _LinkRow(
                key: siteKey,
                label: '그림 원본 사이트',
                url: siteUrl,
                onTap: () => _open(context, ref, siteUrl),
              ),
              _LinkRow(
                key: licenseKey,
                label: '라이선스 전문',
                url: licenseUrl,
                onTap: () => _open(context, ref, licenseUrl),
              ),
              SizedBox(height: space.xl.h),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이름과 주소를 함께 보여주는 눌리는 줄. 누름 영역은 48 이상이다.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.label,
    required this.url,
    required this.onTap,
  });

  final String label;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      semanticLabel: '$label 열기',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 56.h),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      url,
                      style: context.typo.docBody.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20.w, color: colors.settingsChevron),
            ],
          ),
        ),
      ),
    );
  }
}
