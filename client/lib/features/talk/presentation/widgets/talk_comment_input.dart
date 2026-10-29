import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../domain/talk_text_limits.dart';

/// 댓글 입력줄 (시안 1806:7485): 바탕색 띠 위 반투명 입력칸 362×52 + 칸 안 보내기
/// 보내기에 실패하면(false) 적은 글을 그대로 둔다
class TalkCommentInput extends StatefulWidget {
  const TalkCommentInput({super.key, required this.onSubmit});

  /// 보냈으면 true (입력창을 비운다), 실패·취소면 false
  final Future<bool> Function(String body) onSubmit;

  @override
  State<TalkCommentInput> createState() => _TalkCommentInputState();
}

class _TalkCommentInputState extends State<TalkCommentInput> {
  final _controller = TextEditingController();
  bool _isSending = false;

  /// 공백만 있는 글은 보내지 않는다
  bool get _canSend => !_isSending && _controller.text.trim().isNotEmpty;

  /// 입력줄이 늘어날 수 있는 최대 줄 수
  static const _maxVisibleLines = 4;

  /// 시안 실측: 띠 위 8 · 아래 4(+ 홈 인디케이터 = 띠 98) · 좌우 16 · 칸 최소 높이 52 · 반지름 20 · 글자 왼쪽 18 · 배경 흐림 10
  static const _barTop = 8.0;
  static const _barBottom = 4.0;
  static const _sideInset = 16.0;
  static const _fieldMinHeight = 52.0;
  static const _fieldRadius = 20.0;
  static const _textLeft = 18.0;
  static const _textVertical = 16.0;
  static const _backdropBlur = 10.0;

  /// 그림자 (0 2 5 · 검정 5%)
  static const _shadowBlur = 5.0;
  static const _shadowOffsetY = 2.0;

  /// 보내기 버튼 자리 (칸 오른쪽 안쪽 6)
  static const _sendInset = 6.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _isSending = true);
    final isSent = await widget.onSubmit(_controller.text.trim());
    if (!mounted) return;
    setState(() => _isSending = false);
    if (isSent) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final radius = BorderRadius.circular(_fieldRadius.r);

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _sideInset.w,
          _barTop.h,
          _sideInset.w,
          _barBottom.h,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: colors.glassShadow,
                blurRadius: _shadowBlur,
                offset: const Offset(0, _shadowOffsetY),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _backdropBlur,
                sigmaY: _backdropBlur,
              ),
              child: Container(
                constraints: BoxConstraints(minHeight: _fieldMinHeight.h),
                color: colors.talkCommentFieldFill,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_isSending,
                        minLines: 1,
                        maxLines: _maxVisibleLines,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            TalkTextLimits.maxCommentLength,
                          ),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: typo.talkCommentField.copyWith(
                          color: colors.textPrimary,
                        ),
                        cursorColor: colors.talkAccentText,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: context.l10n.talkCommentHint,
                          hintStyle: typo.talkCommentField.copyWith(
                            color: colors.promptMuted,
                          ),
                          contentPadding: EdgeInsets.fromLTRB(
                            _textLeft.w,
                            _textVertical.h,
                            0,
                            _textVertical.h,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(_sendInset.w),
                      child: _SendButton(
                        isSending: _isSending,
                        onPressed: _canSend ? _send : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보내기: 글이 없으면 연회색 종이비행기, 쓰면 짙은 민트 원에 흰 종이비행기로 톡 커진다
class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onPressed});

  final bool isSending;
  final VoidCallback? onPressed;

  static const _size = 40.0;
  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = onPressed != null;
    final isActive = isEnabled || isSending;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: context.l10n.talkCommentSend,
      child: AppPressable(
        onTap: onPressed,
        scaleDown: AppPressable.scaleIcon,
        child: AnimatedScale(
          scale: isActive ? 1 : 0.86,
          duration: AppMotion.normal,
          curve: isActive ? AppMotion.springOut : AppMotion.standard,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            width: _size.w,
            height: _size.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? colors.talkAccentText : Colors.transparent,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: isSending
                  ? ElumSpinner(
                      key: const ValueKey('sending'),
                      size: _iconSize.w,
                      color: colors.surface,
                    )
                  : SvgPicture.asset(
                      AppAssets.iconNotificationPaperPlane,
                      key: ValueKey(isEnabled),
                      width: _iconSize.w,
                      height: _iconSize.w,
                      excludeFromSemantics: true,
                      colorFilter: ColorFilter.mode(
                        isEnabled ? colors.surface : colors.talkMetaIcon,
                        BlendMode.srcIn,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
