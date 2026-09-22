import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_shake.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../data/device_link_repository.dart';
import '../domain/link_code.dart';
import 'widgets/code_boxes.dart';

/// 연결 암호 넣기 — **이룸이 휴대폰** (이슈 #205 · 명세 §5-2).
///
/// 로그인 전에 서는 화면이다. 여기서 암호를 넣으면 계정에 붙고 이룸이 홈으로 간다.
///
/// PIN 화면과 달리 **시스템 키보드**를 쓴다 — 암호에 영문이 섞여 숫자패드로는 칠 수 없다.
/// 6칸 모양은 PIN과 맞추되 글자를 드러낸다(가리면 받아적을 수 없다).
class LinkEnterScreen extends ConsumerStatefulWidget {
  const LinkEnterScreen({super.key});

  @override
  ConsumerState<LinkEnterScreen> createState() => _LinkEnterScreenState();
}

class _LinkEnterScreenState extends ConsumerState<LinkEnterScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String? _errorMessage;

  /// 틀린 횟수. 값이 바뀔 때마다 칸이 한 번 흔들린다.
  int _failCount = 0;

  /// 서버에 보내는 중. 같은 암호를 두 번 보내지 않는다 — 1회용이라 두 번째는 반드시 실패한다.
  bool _sending = false;

  String get _typed => LinkCode.normalize(_controller.text);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_sending) return;
    setState(() {});
    // 여섯 자를 채우면 바로 보낸다 — 확인 버튼을 따로 누르게 하지 않는다 (§5-2).
    if (_typed.length == LinkCode.length) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final code = _typed;
    if (!LinkCode.hasValidShape(code)) {
      // 우리가 만들 수 없는 모양은 서버에 보내지 않는다 — 시도 횟수만 축낸다.
      _fail('암호가 맞지 않아요');
      return;
    }

    setState(() => _sending = true);
    _focusNode.unfocus();
    final result = await ref.read(deviceLinkRepositoryProvider).redeem(code);
    if (!mounted) return;
    setState(() => _sending = false);

    // 서버가 이유를 알려줬으면 그 문구가 아래 기본 문구를 이긴다 (#352).
    String say(String fallback, String code) =>
        result.failure?.describe(fallback, code) ?? '$fallback ($code)';

    switch (result.outcome) {
      case RedeemOutcome.linked:
        context.go(Routes.child);
      case RedeemOutcome.notFound:
        _fail('암호가 맞지 않아요');
      case RedeemOutcome.expired:
        _fail('암호가 만료됐어요. 새 암호를 받아주세요');
      case RedeemOutcome.tooManyAttempts:
        _fail(say('잠시 후 다시 해주세요', 'E-LINK-429'));
      case RedeemOutcome.offline:
        _fail(say('연결하지 못했어요. 인터넷을 확인해주세요', 'E-NET'));
      case RedeemOutcome.failed:
        _fail(say('연결하지 못했어요. 다시 해주세요', 'E-LINK'));
    }
  }

  /// 실패 — 입력을 비우고 흔들어 알린다. 붉은 경고를 크게 쓰지 않는다 (§5-2).
  void _fail(String message) {
    _controller.clear();
    setState(() {
      _errorMessage = message;
      _failCount++;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return ElumScaffold(
      onBack: _sending ? null : () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            title: '보호자에게 연결 암호를\n받아주세요',
            description: _errorMessage,
          ),
          SizedBox(height: space.lg),
          // 어디서 받는지 적어 준다. 이 안내는 **보호자가 읽어도 말이 되게** 쓴다 —
          // 보호자가 대신 넣어 주는 경우가 많다 (§5-2).
          Container(
            padding: EdgeInsets.all(space.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(space.cardRadius.r),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('보호자 휴대폰에서',
                    style: context.typo.body.copyWith(color: colors.textSecondary)),
                SizedBox(height: space.sm),
                Text('설정 → 이룸이 휴대폰 연결하기',
                    style: context.typo.subtitle.copyWith(color: colors.textPrimary)),
                SizedBox(height: space.sm),
                Text('여섯 글자가 나와요',
                    style: context.typo.body.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
          SizedBox(height: space.xl),
          GestureDetector(
            onTap: _focusNode.requestFocus,
            behavior: HitTestBehavior.opaque,
            child: AppShake(
              trigger: _failCount,
              child: CodeBoxes(value: _typed, hasError: _errorMessage != null),
            ),
          ),
          if (_sending) ...[
            SizedBox(height: space.lg),
            Center(child: SizedBox(
              width: space.lg.w, height: space.lg.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )),
          ],
          // 화면에 보이지 않는 실제 입력칸. 시스템 키보드를 쓰되 자동완성·자동수정을 끈다 —
          // 켜 두면 영문 여섯 자를 단어로 고쳐 버린다.
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword,
                maxLength: LinkCode.length + 2, // 공백을 끼워 쳐도 받아준다
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
