import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/device_link_repository.dart';
import '../domain/link_status.dart';

/// 연결 암호 만들기 — **보호자 휴대폰** (이슈 #205 · 디자인 #232).
///
/// 진입은 두 곳이고 **시안이 서로 다르다.**
///
/// | | 온보딩 (`732:5334`) | 설정 (`1027:4617`) |
/// | --- | --- | --- |
/// | 네비게이션 제목 | 없음 | `이룸이 휴대폰 연결` |
/// | 뒤로가기 y | 79 | **67** |
/// | 제목 y | 131 | **147** |
/// | 시작하기 | 있음 | **없음** |
/// | 나중에 할게요 | 있음 | 없음 |
///
/// 설정에서는 이미 앱 안이라 `시작하기`가 갈 곳이 없다 — 연결하면 팝업으로
/// 알리고 뒤로가기로 돌아간다. 시안도 그렇게 그려져 있다 (#349).
///
/// 이 화면의 주인공은 **여섯 글자**다. QR이 빠지면서 화면이 비었으므로 암호를 크게 키운다.
///
/// ## 상태 셋 (Figma 732:5334 · 732:5702 · 732:5850)
///
/// | | 암호 | 타이머 | 다시 만들기 | CTA |
/// | --- | --- | --- | --- | --- |
/// | 대기 | 보임 | `09:59` 빨강 | 있음 | 비활성 |
/// | 연결 성공 | 보임 | — | — | 팝업이 덮는다 |
/// | 연결됨 | 보임 | **없음** | **없음** | **활성** |
///
/// 연결되면 타이머와 다시 만들기가 사라진다 — **더 기다릴 이유가 없어서다.**
/// `나중에 할게요`는 세 상태 모두에 남는다 (시안 `732:5850`).
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

  /// 남은 시간을 1초마다 다시 그린다. 시안이 `09:59`를 초까지 보여준다 (#232).
  Timer? _ticker;

  /// 연결됐는지 주기적으로 확인한다. 보호자가 이 화면을 보고 있는 동안
  /// 이룸이 휴대폰이 암호를 넣으면 **여기서 바로 알아야** 한다.
  Timer? _poller;

  bool _linked = false;

  /// 성공 팝업을 두 번 띄우지 않는다. 폴링이 한 박자 늦게 또 돌 수 있다.
  bool _celebrated = false;

  /// 암호 여섯 글자 사이 간격. 시안은 3-3으로 묶고 가운데를 더 벌린다
  /// (글자 좌표 0·47·100 | 164·211·258).
  static const _codeLetterGap = 20.0;
  static const _codeGroupGap = 40.0;

  /// 암호 묶음(y=299) ↔ 타이머(y=363) ↔ 다시 만들기 칩(y=395)
  /// 설명 하단(227) → 코드 상단(299). 시안 `732:5656` 실측.
  /// `space.xl * 2`(64)를 쓰고 있었는데 그러면 코드 블록이 통째로 8 뜬다 (#297).
  static const _descriptionToCode = 72.0;

  static const _codeToTimer = 24.0;
  static const _timerToRetry = 16.0;

  /// 설정 진입 시안(`1027:4617`)의 뒤로가기 y와 제목 y.
  /// 설정 묶음은 전부 67/147 이다 — 온보딩 계열(79/131)과 12·16씩 다르다.
  static const _settingsBackTop = 67.0;
  static const _settingsTitleY = 147.0;

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
    final attempt = await ref.read(deviceLinkRepositoryProvider).issue();
    if (!mounted) return;

    if (!attempt.isOk) {
      setState(() {
        _loading = false;
        // **서버가 이유를 알려줬으면 그 문구를 그대로 쓴다** (#352).
        _errorMessage = attempt.failure!
            .describe('암호를 만들지 못했어요. 다시 해주세요', 'E-LINK-NEW');
      });
      return;
    }

    setState(() {
      _issued = attempt.value;
      _loading = false;
    });
    _startTimers();
  }

  void _startTimers() {
    _ticker?.cancel();
    _poller?.cancel();
    // 남은 시간을 초까지 보여주므로 1초마다 다시 그린다. 만료되면 멈춘다.
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
        _celebrate();
      }
    });
  }

  /// 연결 성공 팝업. 화면 밖으로 넘어가지 않고 **이 자리에서** 알린다 (#232).
  ///
  /// 팝업을 닫아도 화면에 머문다 — 연결됨 상태를 눈으로 확인하고 `시작하기`를
  /// 누르는 것이 시안의 흐름이다.
  Future<void> _celebrate() async {
    if (_celebrated) return;
    _celebrated = true;
    await showElumDialog<void>(
      context: context,
      icon: ElumDialogIcon.success,
      title: '휴대폰 연결에 성공했어요!',
    );
  }

  void _goHome() => context.go(Routes.guardian);

  /// 이룸이 이름. 비어 있으면 `이룸이`로 대신한다 — 온보딩을 건너뛰고 설정에서
  /// 바로 들어오면 이름이 없을 수 있다. `의`는 받침과 무관해 그냥 붙는다.
  String get _elumiName {
    final name = ref.watch(onboardingProvider).childNickname.trim();
    return name.isEmpty ? '이룸이' : name;
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    final issued = _issued;
    final expired = issued?.isExpired ?? false;
    // 설정에서 들어온 화면은 머리와 하단이 통째로 다르다 (클래스 주석의 표).
    final fromSettings = !widget.fromOnboarding;

    return ElumScaffold(
      onBack: () => context.pop(),
      title: fromSettings ? '이룸이 휴대폰 연결' : null,
      backTop: fromSettings ? _settingsBackTop : null,
      // 온보딩 시안은 연결되기 전에도 버튼을 **보여주되 누를 수 없게** 둔다
      // (732:5334) — 다음 할 일을 알려주는 이정표라 자리를 비우지 않는다.
      // 설정 시안(`1027:4617`)에는 버튼 자체가 없다.
      bottomButton: fromSettings
          ? null
          : ElumButton(
              label: '시작하기',
              onPressed: _linked ? _goHome : null,
            ),
      // `나중에 할게요`는 CTA 아래에 붙는다 (시안 y=765).
      //
      // **연결된 뒤에도 남는다** — 시안 `732:5850`이 그렇게 그려져 있다.
      // 전에는 연결되면 숨겼는데, 누르면 `시작하기`와 같은 곳으로 가므로
      // 숨겨서 얻는 것이 없고 화면만 시안과 달라졌다 (#297).
      //
      // **높이를 못 박지 않는다** (#393 S6 · 보상 화면 #380 실기기 A 와 같은 원인).
      // 전에는 자리를 글자 높이 16 으로 고정하고 OverflowBox 로 누름 영역만 넓혔다.
      // 글꼴을 키우면 글자가 16 상자에 갇혀 아래가 잘렸고, 넘친 것이 아니라 잘린
      // 것이라 경고도 안 났다. 이제 글자 높이가 곧 자리다 — 글꼴 1.0 에서는 16 그대로라
      // 시안 자리(765)와 같다(#297 에서 맞춘 CTA 자리도 그대로). 누름 영역은 옆으로만
      // 넓힌다 — 위아래로 넓히면 자리가 늘어 CTA 를 밀어 올린다.
      belowButton: widget.fromOnboarding
          ? Center(
              child: AppPressable(
                onTap: _goHome,
                child: Padding(
                  // 옆 여백은 전과 같은 8 — 바꾸면 글자가 반 픽셀 옮겨 골든이 흔들린다.
                  padding: EdgeInsets.symmetric(horizontal: space.xs.h),
                  child: Text(
                    '나중에 할게요',
                    style: context.typo.linkLater.copyWith(
                      color: colors.linkLaterLabel,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            )
          : null,
      // 글꼴을 키우면(2.0) 제목 두 줄·설명·암호·타이머·칩이 한 화면을 넘는다.
      // 고정 높이 칸에 두면 아래가 넘쳐 잘리므로 스크롤로 끝까지 볼 수 있게 한다
      // (#393 S6 에서 함께 드러남). 글꼴 1.0 에서는 다 들어와 움직이지 않는다.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              hasBackButton: true,
              // 설정 시안은 제목이 147에서 시작한다 — 뒤로가기 줄에 제목이 함께
              // 서면서 머리가 107에서 끝나기 때문이다.
              titleY: fromSettings ? _settingsTitleY : null,
              title: '$_elumiName의 휴대폰을\n연결할까요?',
              description:
                  _errorMessage ?? '$_elumiName의 휴대폰에서 아래 코드를 입력하세요',
            ),
            SizedBox(height: _descriptionToCode.h),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (issued != null) ...[
              _CodeText(
                code: issued.code,
                dimmed: expired,
                letterGap: _codeLetterGap,
                groupGap: _codeGroupGap,
              ),
              // 연결되면 타이머도 `다시 만들기`도 사라진다 — 더 기다릴 이유가 없다.
              if (!_linked) ...[
                SizedBox(height: _codeToTimer.h),
                Text(
                  _remainingLabel(issued, expired),
                  textAlign: TextAlign.center,
                  style: context.typo.linkTimer.copyWith(color: colors.linkTimer),
                ),
                SizedBox(height: _timerToRetry.h),
                Center(
                  child: _RetryChip(
                    onTap: _loading ? null : _issue,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 남은 시간 `MM:SS`. 시안이 초까지 보여준다 (#232 — 전에는 분만 말했다).
  ///
  /// 올림이 아니라 **내림**이다. 남은 시간을 실제보다 길게 말하면 믿고 기다리다
  /// 만료된다.
  String _remainingLabel(IssuedLinkCode issued, bool expired) {
    if (expired) return '암호가 만료됐어요';
    final total = issued.remaining().inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// 암호 여섯 글자. 3-3으로 묶고 가운데를 더 벌린다 (Figma 732:5710).
///
/// `Text` 하나에 `letterSpacing`을 주지 않는 이유 — 마지막 글자 뒤에도 자간이
/// 붙어 묶음이 왼쪽으로 치우친다. 글자를 낱개로 놓아야 가운데가 맞는다.
class _CodeText extends StatelessWidget {
  const _CodeText({
    required this.code,
    required this.dimmed,
    required this.letterGap,
    required this.groupGap,
  });

  final String code;
  final bool dimmed;
  final double letterGap;
  final double groupGap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.linkCode.copyWith(
      color: dimmed ? colors.textPlaceholder : colors.textPrimary,
    );
    final letters = code.split('');
    final half = letters.length ~/ 2;

    // 글꼴 2.0 이면 여섯 글자가 화면 폭을 100 넘는다. 폭에 맞춰 줄이기만 한다 —
    // 들어갈 때(글꼴 1.0)는 그대로라 시안 크기가 바뀌지 않는다 (#393 S6).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, ch) in letters.indexed) ...[
            if (i > 0) SizedBox(width: (i == half ? groupGap : letterGap).w),
            Text(ch, style: style),
          ],
        ],
      ),
    );
  }
}

/// `코드 다시 만들기` 칩 (Figma 732:5718 — padding 10/20, r20).
class _RetryChip extends StatelessWidget {
  const _RetryChip({required this.onTap});

  final VoidCallback? onTap;

  static const _padV = 10.0;
  static const _padH = 20.0;
  static const _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: _padV.h, horizontal: _padH.w),
        decoration: BoxDecoration(
          color: colors.linkRetryChipBg,
          borderRadius: BorderRadius.circular(_radius.r),
        ),
        child: Text(
          '코드 다시 만들기',
          style: context.typo.linkRetryChip.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}
