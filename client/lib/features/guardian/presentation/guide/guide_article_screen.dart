import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../shared/utils/open_notice_link.dart';
import '../../application/guide_tip_controller.dart';
import '../../domain/guide_tip.dart';
import '../widgets/guide_tip_card.dart';

/// 가이드 글 앱 안 읽기: 사이트 안내 글을 앱 화면 안 웹뷰로 > 뒤로가기는 앱 이전 화면 (#1455)
/// 사이트 밖 링크는 외부 브라우저. 불러오기 실패 > 다시 시도 + 코드 [guideTipOpenFailedCode]
class GuideArticleScreen extends StatefulWidget {
  const GuideArticleScreen({super.key, required this.tip});

  final GuideTip tip;

  @override
  State<GuideArticleScreen> createState() => _GuideArticleScreenState();
}

class _GuideArticleScreenState extends State<GuideArticleScreen> {
  WebViewController? _controller;
  Uri? _articleUrl;
  bool _isLoading = true;
  bool _hasFailed = false;

  /// 사이트 주소 (같은 사이트 안 이동만 웹뷰 안에서)
  static final _siteHost = Uri.parse(AppConfig.siteBaseUrl).host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 앱 언어가 정해진 뒤 한 번만 (언어별 글 주소)
    if (_controller != null) return;
    final articleUrl = toGuideArticleUrl(widget.tip, context.appLocale.languageCode);
    _articleUrl = articleUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(context.colors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _markLoaded(),
          onWebResourceError: _onLoadError,
          onNavigationRequest: _decideNavigation,
        ),
      )
      ..loadRequest(articleUrl);
  }

  /// 앱 안에서는 사이트 머리 줄·경로·바닥글을 숨김 (site/site_frame.py `header.top`·`footer.bottom`, site_guides.py `nav.crumb`)
  static const _hideSiteChromeScript =
      "var s=document.createElement('style');"
      "s.textContent='header.top,nav.crumb,footer.bottom{display:none!important}';"
      'document.head.appendChild(s);';

  // 사이트 겉틀을 숨긴 뒤 보여 줌 (숨기기 실패해도 글은 보임)
  Future<void> _markLoaded() async {
    if (!mounted || _hasFailed) return;
    try {
      await _controller?.runJavaScript(_hideSiteChromeScript);
    } catch (error, stack) {
      AppLogger.error('guide', error, stack, {'step': 'hideSiteChrome'});
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // 본문(메인 프레임) 실패만 실패 화면. 그림·글꼴 하나 실패는 무시
  void _onLoadError(WebResourceError error) {
    if (error.isForMainFrame == false) return;
    AppLogger.error('guide', error.description, null, {'step': 'load', 'slug': widget.tip.slug, 'code': error.errorCode});
    if (!mounted) return;
    setState(() {
      _hasFailed = true;
      _isLoading = false;
    });
  }

  // 같은 사이트 > 웹뷰 안, 그 밖 > 외부 브라우저
  NavigationDecision _decideNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri != null && uri.host == _siteHost) return NavigationDecision.navigate;
    if (uri != null) openNoticeLink(uri);
    return NavigationDecision.prevent;
  }

  void _retry() {
    final articleUrl = _articleUrl;
    if (articleUrl == null) return;
    setState(() {
      _hasFailed = false;
      _isLoading = true;
    });
    _controller?.loadRequest(articleUrl);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    return ElumScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      title: GuideTipSlot.titleOf(widget.tip, l10n),
      backTop: ElumScaffold.settingsBackTop,
      horizontalPadding: 0,
      child: Stack(
        children: [
          if (controller != null && !_hasFailed) WebViewWidget(controller: controller),
          if (_isLoading) const Center(child: ElumSpinner()),
          if (_hasFailed)
            Center(
              child: ElumErrorView(
                message: l10n.guideTipOpenFailed,
                errorCode: guideTipOpenFailedCode,
                onRetry: _retry,
              ),
            ),
        ],
      ),
    );
  }
}
