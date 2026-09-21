import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../data/auth_repository.dart';
import '../data/consent_document_repository.dart';
import '../data/consent_repository.dart';
import '../domain/consent_bundle.dart';
import 'consent_document_screen.dart';
import 'widgets/consent_all_agree_button.dart';
import 'widgets/consent_row.dart';

/// 약관 동의 화면. 로그인 직후, 이룸이 정보를 받기 전에 선다.
///
/// Figma `739:3747`(미동의) · `726:5056`(전체 동의) — 같은 화면의 두 상태다 (이슈 #226).
/// 전체 동의 버튼 344×68 y=223, 항목 344×50 y=308부터 58 간격, CTA y=675.
///
/// **항목을 하나로 뭉치지 않는다.** 개인정보보호법은 필수와 선택을 나누어 받도록
/// 하며, 뭉쳐 받은 동의는 무효가 될 수 있다.
///
/// 문구는 서버에서 온다 (이슈 #278). 서버를 못 보면 캐시, 그것도 없으면 앱에 담긴
/// 기본값으로 떨어지므로 **이 화면이 비는 경우는 없다.**
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  /// 부제 하단(193) → 전체 동의 버튼(223). ElumHeader가 제목·부제를 y=131·177에
  /// 세우므로 여기서 남은 30만 띄운다. `headerToContent`(52)를 쓰면 22가 밀린다.
  static const _headerToAllAgree = 30.0;

  /// 전체 동의 버튼 하단(291) → 첫 항목(308)
  static const _allAgreeToItems = 17.0;

  final _checked = <String>{};

  bool _isSubmitting = false;
  String? _errorMessage;

  bool _allRequiredChecked(ConsentBundle bundle) =>
      bundle.requiredItems.every((item) => _checked.contains(item.key));

  /// 모두 켜져 있는가. 버튼이 `전체 동의`이므로 **선택 항목까지** 본다.
  bool _allChecked(ConsentBundle bundle) =>
      bundle.items.every((item) => _checked.contains(item.key));

  /// 일괄 동의는 **이름 그대로 전부** 켠다 (이슈 #235).
  ///
  /// 전에는 필수만 켰다 (이슈 #189). 화면 아래로 밀린 선택 항목까지 켜면
  /// "본 적 없는 것에 동의하게 된다"는 이유였는데, **해법이 틀렸다.**
  /// `전체 동의`라고 써 놓고 일부만 켜면 사용자는 다 켜진 줄 알고 넘어간다.
  /// 이름과 동작이 어긋나는 쪽이 모르고 동의하는 것보다 나쁘다.
  ///
  /// #189가 걱정한 것은 실은 **켜진 것을 볼 수 없던 것**이다. 항목마다 체크가
  /// 보이고 스크롤하면 확인할 수 있으며, 선택 항목만 따로 끌 수도 있다.
  void _toggleAll(ConsentBundle bundle) {
    setState(() {
      if (_allChecked(bundle)) {
        _checked.clear();
      } else {
        _checked.addAll(bundle.items.map((item) => item.key));
      }
    });
  }

  Future<void> _submit(ConsentBundle bundle) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final saved = await ref.read(consentRepositoryProvider).agree(
          // 켠 것만 동의로 보낸다. 고정값을 보내면 켜지 않은 항목이 동의로 남는다 (#278 QA).
          agreedKeys: Set.of(_checked),
          // **화면에 보여준 것**의 버전이다. 캐시나 기본값을 보여줬다면 그 버전으로
          // 남아야 한다 — 보지 않은 문서에 동의한 것으로 기록하면 안 된다.
          version: bundle.version,
        );

    if (!mounted) return;

    if (!saved) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = '동의를 저장하지 못했어요. 다시 해주세요 (E-CONSENT)';
      });
      return;
    }

    // 동의를 마쳤으니 이제 누가 쓰는 휴대폰인지 묻는다 (이슈 #212).
    // 보호자인지 이룸이인지에 따라 다음 화면이 갈린다 — 여기서 바로 이름을
    // 물으면 이룸이 휴대폰이 보호자 온보딩으로 빨려 들어간다.
    context.go(Routes.roleSelect);
  }

  /// 동의하지 않고 나간다. 서비스를 쓸 수 없으므로 로그아웃 상태로 되돌린다.
  ///
  /// 토큰만 남겨두면 다음 실행에서 동의 화면을 건너뛰고 들어올 수 있어
  /// 동의 없이 서비스가 열린다.
  Future<void> _leave() async {
    await ref.read(authRepositoryProvider).logout();
    if (!mounted) return;
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(consentBundleProvider);

    return PopScope(
      // 뒤로가기로 빠져나가면 동의 없이 화면이 열린다. 나가려면 로그아웃이어야 한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      // 읽어 오는 동안에도 **헤더는 그대로 선다.** 흰 화면을 띄우면 로그인이
      // 실패한 것처럼 보인다. 이 대기는 첫 실행에만 있고 3초를 넘지 않는다.
      //
      // `orElse`로 묶은 이유 — 이 provider는 실패하지 않는다. 서버·캐시가 모두
      // 없으면 앱 번들 기본값이 온다. 그래도 error를 대비해 두는 것은,
      // 예상 못 한 예외로 **가입이 통째로 막히는 것을 막기 위해서**다.
      child: bundle.maybeWhen(
        data: _content,
        orElse: () => bundle.hasError ? _content(ConsentBundle.bundled) : _waiting(),
      ),
    );
  }

  /// 약관을 읽어 오는 동안. 골격은 같고 누를 것만 비활성이다.
  Widget _waiting() {
    return ElumScaffold(
      bottomButton: const ElumButton(label: '다음', onPressed: null),
      child: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              title: '약관에 동의해주세요',
              description: '약관을 불러오고 있어요',
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(ConsentBundle bundle) {
    final space = context.space;
    final allRequired = _allRequiredChecked(bundle);

    return ElumScaffold(
      bottomButton: ElumButton(
        label: _isSubmitting ? '저장하고 있어요' : '다음',
        onPressed:
            allRequired && !_isSubmitting ? () => _submit(bundle) : null,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              title: '약관에 동의해주세요',
              // 부제가 상태를 말한다. 왜 `다음`이 꺼져 있는지 여기서만 알 수 있다 —
              // 고정 문구로 두면 비활성 버튼 앞에서 막힌 사람이 이유를 모른다.
              description: allRequired
                  ? '항목을 눌러 상세 내용을 볼 수 있어요'
                  : '서비스 사용을 위해 약관 동의가 필요해요',
            ),
            SizedBox(height: _headerToAllAgree.h),

            ConsentAllAgreeButton(
              checked: _allChecked(bundle),
              onTap: () => _toggleAll(bundle),
            ),
            SizedBox(height: _allAgreeToItems.h),

            for (final item in bundle.items) ...[
              ConsentRow(
                item: item,
                isChecked: _checked.contains(item.key),
                onToggle: () => setState(() {
                  if (!_checked.remove(item.key)) _checked.add(item.key);
                }),
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConsentDocumentScreen(item: item),
                  ),
                ),
              ),
              SizedBox(height: ConsentRow.gap.h),
            ],

            // 디자인에 에러 자리가 없다. 항목 아래 빈 공간(항목 끝 590 → CTA 675)에
            // 둔다 — CTA를 밀지 않고, 실패했을 때만 나타난다.
            if (_errorMessage != null) ...[
              SizedBox(height: space.sm.h),
              Text(
                _errorMessage!,
                style: context.typo.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
