import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../data/device_link_repository.dart';
import '../domain/link_code.dart';
import '../domain/link_status.dart';

/// 연결 암호 만들기 — **보호자 휴대폰** (이슈 #205 · 명세 §5-1).
///
/// 진입은 두 곳이다 — PIN 설정 직후(온보딩), 홈 → 설정.
/// 온보딩에서 들어온 경우에만 `나중에 할게요`를 보여준다.
///
/// 이 화면의 주인공은 **여섯 글자**다. QR이 빠지면서 화면이 비었으므로 암호를 크게 키운다.
class LinkCodeScreen extends ConsumerStatefulWidget {
  const LinkCodeScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  ConsumerState<LinkCodeScreen> createState() => _LinkCodeScreenState();
}

class _LinkCodeScreenState extends ConsumerState<LinkCodeScreen> {
  IssuedLinkCode? _issued;
  bool _loading = true;
  String? _errorMessage;

  /// 남은 시간을 1초마다 다시 그린다. 카운트다운을 숫자로 보여주지는 않는다 —
  /// 쫓기게 만들지 않으려고 `10분 동안 쓸 수 있어요`로 쓴다 (§5-1).
  Timer? _ticker;

  /// 연결됐는지 주기적으로 확인한다. 보호자가 이 화면을 보고 있는 동안
  /// 이룸이 휴대폰이 암호를 넣으면 **여기서 바로 알아야** 한다.
  Timer? _poller;

  bool _linked = false;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final issued = await ref.read(deviceLinkRepositoryProvider).issue();
    if (!mounted) return;

    if (issued == null) {
      setState(() {
        _loading = false;
        _errorMessage = '암호를 만들지 못했어요. 다시 해주세요 (E-LINK-NEW)';
      });
      return;
    }

    setState(() {
      _issued = issued;
      _loading = false;
    });
    _startTimers();
  }

  void _startTimers() {
    _ticker?.cancel();
    _poller?.cancel();
    // 만료 표시를 갱신하려고 1초마다 다시 그린다. 만료되면 멈춘다.
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_issued?.isExpired ?? true) t.cancel();
      setState(() {});
    });
    // 3초는 서버에 부담이 크지 않으면서 사람이 기다린다고 느끼지 않는 간격이다.
    _poller = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted) return t.cancel();
      final status = await ref.read(deviceLinkRepositoryProvider).status();
      if (!mounted) return;
      if (status.hasDevice) {
        t.cancel();
        _ticker?.cancel();
        setState(() => _linked = true);
      }
    });
  }

  Future<void> _copy() async {
    final code = _issued?.code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('복사했어요')));
  }

  void _goHome() => context.go(Routes.guardian);

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    final issued = _issued;
    final expired = issued?.isExpired ?? false;

    return ElumScaffold(
      onBack: () => context.pop(),
      bottomButton: _linked
          ? ElumButton(label: '완료', onPressed: _goHome)
          : ElumButton(
              label: '암호 다시 만들기',
              onPressed: _loading ? null : _issue,
              // 만료됐으면 이 버튼이 주 동작이 된다 (§5-1).
              backgroundColor: expired ? null : colors.buttonNeutral,
              labelColor: expired ? null : colors.buttonNeutralText,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            title: _linked ? '연결됐어요' : '이룸이 휴대폰에\n이 암호를 넣어주세요',
            description: _errorMessage,
          ),
          SizedBox(height: space.xl * 2),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (issued != null) ...[
            // 화면에서 가장 큰 글자. 3-3으로 묶고 자간을 넓힌다.
            Text(
              LinkCode.grouped(issued.code),
              textAlign: TextAlign.center,
              style: context.typo.pinTitle.copyWith(
                color: expired ? colors.textPlaceholder : colors.textPrimary,
                letterSpacing: 6,
              ),
            ),
            SizedBox(height: space.lg),
            if (!expired && !_linked)
              Center(
                child: AppPressable(
                  onTap: _copy,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: space.lg, vertical: space.sm),
                    child: Text('암호 복사',
                        style: context.typo.button
                            .copyWith(color: colors.textSecondary)),
                  ),
                ),
              ),
            SizedBox(height: space.xl),
            Text(
              _remainingLabel(issued, expired),
              textAlign: TextAlign.center,
              style: context.typo.body.copyWith(color: colors.textSecondary),
            ),
          ],
          if (widget.fromOnboarding && !_linked) ...[
            SizedBox(height: space.lg),
            Center(
              child: AppPressable(
                onTap: _goHome,
                child: Padding(
                  padding: EdgeInsets.all(space.sm),
                  child: Text('나중에 할게요',
                      style: context.typo.body.copyWith(
                        color: colors.textSecondary,
                        decoration: TextDecoration.underline,
                      )),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 남은 시간 문구. 분 단위로만 말한다 — 초를 세어 보여주면 쫓긴다.
  ///
  /// 올림으로 센다. `inMinutes + 1`로 하면 정확히 10분 남았을 때 **11분**이 나온다 —
  /// 서버가 준 것보다 길게 말하게 되므로 사용자가 믿고 기다리다 만료된다.
  String _remainingLabel(IssuedLinkCode issued, bool expired) {
    if (_linked) return '이룸이 휴대폰이 연결됐어요';
    if (expired) return '암호가 만료됐어요';
    final minutes = (issued.remaining().inSeconds / 60).ceil();
    if (minutes <= 1) return '1분 남았어요';
    return '$minutes분 동안 쓸 수 있어요';
  }
}
