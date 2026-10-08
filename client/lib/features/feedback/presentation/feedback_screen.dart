import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/feedback_sender.dart';
import '../data/feedback_repository.dart';
import 'widgets/feedback_check_row.dart';
import 'widgets/feedback_text_box.dart';

/// 의견 보내기 화면. 글과 (선택) 앱 상태 기록을 보낸다.
///
/// 실패해도 적은 글과 체크 상태는 그대로 두고 다시 보낼 수 있게 한다.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _controller = TextEditingController();
  bool _includeLog = true;
  bool _sending = false;

  /// 공백만 있는 글은 보내지 않는다.
  bool get _canSend => !_sending && _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    // 화면을 닫은 뒤에는 이 context 가 없다 — 토스트에 쓸 messenger 를 미리 잡는다
    final messenger = ScaffoldMessenger.maybeOf(context);
    final sentText = context.l10n.feedbackSent;
    setState(() => _sending = true);

    final result = await ref
        .read(feedbackSenderProvider)
        .send(message: _controller.text, includeLog: _includeLog);

    if (!mounted) return;
    setState(() => _sending = false);

    if (result.isOk) {
      showElumToastOn(messenger, sentText);
      context.popOrHome();
      return;
    }
    await showFailure(
      context,
      result.failure,
      title: context.l10n.feedbackFailedTitle,
      fallback: context.l10n.feedbackFailedFallback,
      fallbackCode: FeedbackRepository.failureCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 뼈대는 키보드가 올라와도 줄지 않아 버튼을 가린다 — 키보드 높이만큼 직접 올린다.
    // 뼈대가 이미 홈 인디케이터 높이를 비워 두므로 그만큼은 뺀다.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final lift = (keyboard - safeBottom).clamp(0.0, double.infinity);

    return ElumScaffold(
      onBack: _sending ? null : context.popOrHome,
      title: l10n.feedbackTitle,
      backTop: 67,
      horizontalPadding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // 글자를 키우거나 키보드가 올라와 좁아져도 넘치지 않게 스크롤로 둔다
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 24.h),
                  FeedbackTextBox(
                    controller: _controller,
                    hintText: l10n.feedbackHint,
                    maxLength: FeedbackSender.maxMessageLength,
                    enabled: !_sending,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 8.h),
                  FeedbackCheckRow(
                    label: l10n.feedbackIncludeLog,
                    checked: _includeLog,
                    onChanged: _sending
                        ? null
                        : (v) => setState(() => _includeLog = v),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.space.md.h),
          _SendButton(
            label: l10n.feedbackSend,
            sending: _sending,
            onPressed: _canSend ? _send : null,
          ),
          SizedBox(height: lift > 0 ? lift + 12.h : 24.h),
        ],
      ),
    );
  }
}

/// 보내기 버튼. 전송 중에는 비활성이 되고 오른쪽에 스피너가 돈다.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.label,
    required this.sending,
    required this.onPressed,
  });

  final String label;
  final bool sending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        ElumButton(label: label, onPressed: sending ? null : onPressed),
        if (sending)
          Padding(
            padding: EdgeInsets.only(right: 24.w),
            child: ElumSpinner(
              size: 22.w,
              color: context.colors.buttonDisabledText,
            ),
          ),
      ],
    );
  }
}
