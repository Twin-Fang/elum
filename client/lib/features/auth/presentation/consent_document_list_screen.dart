import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_tile.dart';
import '../data/consent_document_repository.dart';
import '../domain/consent_bundle.dart';
import 'consent_document_screen.dart';

/// 가입한 뒤에도 약관과 개인정보처리방침을 다시 읽는 화면 (이슈 #289).
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
    );
  }

  Widget _list(BuildContext context, ConsentBundle? bundle) {
    final space = context.space;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: space.xl),
          Text(
            '약관 및 개인정보처리방침',
            style: context.typo.pinTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: space.xl),
          if (bundle == null)
            // 캐시가 없는 첫 실행에서만 잠깐 보인다. 상한은 약관 대기 시간과 같다.
            Padding(
              padding: EdgeInsets.only(top: space.xl),
              child: Text(
                '약관을 불러오고 있어요',
                textAlign: TextAlign.center,
                style: context.typo.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            )
          else
            for (final item in bundle.items)
              SettingsTile(
                label: item.label,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConsentDocumentScreen(item: item),
                  ),
                ),
              ),
          SizedBox(height: space.xl),
        ],
      ),
    );
  }
}
