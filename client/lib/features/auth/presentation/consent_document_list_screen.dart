import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_tile.dart';
import '../data/consent_document_repository.dart';
import '../domain/consent_bundle.dart';
import '../domain/consent_documents.dart';
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
      // 시안(`1027:4683`)은 제목이 뒤로가기와 같은 줄에 선다 (#349).
      title: '약관 및 개인정보처리방침',
      // 줄이 x=16 에서 시작한다.
      backTop: 67,
      horizontalPadding: 16,
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
          // 시안 `필수항목` 글자가 y=147 이다. 뒤로가기 상자 하단(119)에서 28.
          SizedBox(height: 40.h),
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
          else ...[
            // **필수와 선택을 나눠 보여준다.** 시안이 그렇게 그렸고, 무엇을 빼도
            // 되는지는 묶어 두면 알 수 없다.
            _GroupLabel('필수항목'),
            for (final item in bundle.requiredItems) _tile(context, item),
            if (bundle.optionalItems.isNotEmpty) ...[
              // 시안 — 마지막 필수 줄 하단(410)에서 `선택항목`(450)까지 40.
              SizedBox(height: 40.h),
              _GroupLabel('선택항목'),
              for (final item in bundle.optionalItems) _tile(context, item),
            ],
          ],
          SizedBox(height: space.xl),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, ConsentItem item) => SettingsTile(
    label: item.label,
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConsentDocumentScreen(item: item),
      ),
    ),
  );
}

/// `필수항목` · `선택항목` 묶음 이름 (16/w600 Pretendard, Figma `1027:4683`).
///
/// 줄 라벨(16/w400)과 크기는 같고 굵기만 다르다 — 시안 그대로다.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 줄 안쪽 여백과 같은 16. 글자 왼쪽이 줄 라벨과 한 선에 선다 (x=32).
      padding: EdgeInsets.only(left: 16.w, bottom: 6.h),
      child: Text(
        text,
        style: context.typo.settingsTileLabel.copyWith(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
