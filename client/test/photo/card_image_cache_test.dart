import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/card_image_disk_cache.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/features/guardian/presentation/widgets/card_image.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 사진으로 바꾸면 이미지 캐시가 버려진다 (#456 · 이룸이 화면에도 새 그림이 간다).
///
/// 서버 `imagePath` 는 바꿀 때마다 새 열쇠다. 캐시 열쇠가 (일과, 카드)뿐이면 옛 그림이
/// 남는다 — 보호자 화면에서도, 새로 받은 일과로 그리는 이룸이 화면에서도.
void main() {
  late _CountingAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    adapter = _CountingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      // 이 테스트는 메모리 캐시 열쇠만 본다. 실제 플랫폼 폴더 조회는 위젯 테스트에서 끝나지
      // 않으므로, 폴더를 못 찾는 캐시(= 디스크 없이 동작)로 바꿔 둔다.
      cardImageDiskCacheProvider.overrideWithValue(
        CardImageDiskCache(rootProvider: () async => throw StateError('no disk')),
      ),
    ]);
  });

  tearDown(() => container.dispose());

  test('같은 imagePath 면 다시 받지 않는다', () async {
    const key = (routineId: 'r1', stepId: 's1', imagePath: 'k/a.png');
    await container.read(cardImageProvider(key).future);
    await container.read(cardImageProvider(key).future);

    expect(adapter.gets, 1);
  });

  test('imagePath 가 바뀌면 캐시를 버리고 새로 받는다', () async {
    await container.read(
      cardImageProvider((
        routineId: 'r1',
        stepId: 's1',
        imagePath: 'k/a.png',
      )).future,
    );
    await container.read(
      cardImageProvider((
        routineId: 'r1',
        stepId: 's1',
        imagePath: 'k/b.png',
      )).future,
    );

    expect(adapter.gets, 2);
  });

  testWidgets('CardImage 가 imagePath 를 열쇠로 넘긴다 — 바뀌면 다시 받는다', (tester) async {
    Widget host(String path) => UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.light,
          home: SizedBox(
            width: 200,
            height: 150,
            child: CardImage(
              routineId: 'r1',
              stepId: 's1',
              imagePath: path,
              emptyBuilder: (_) => const SizedBox(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host('k/a.png'));
    await _settle(tester);
    expect(adapter.gets, 1);

    await tester.pumpWidget(host('k/b.png'));
    await _settle(tester);
    expect(adapter.gets, 2);
  });

  testWidgets(
    '카드 한 장(이룸이 화면도 쓰는 ActionCardView)도 새 imagePath 를 받으면 그림을 다시 받는다',
    (tester) async {
      ActionCard card(String path) => ActionCard(
        id: 's1',
        title: '옷을 입어요',
        description: '옷을 입어요',
        stepOrder: 1,
        imagePath: path,
      );
      Widget host(String path) => UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ActionCardView(card: card(path), index: 0, routineId: 'r1'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(host('k/a.png'));
      await _settle(tester);
      expect(adapter.gets, 1);

      // 서버가 새 열쇠를 준 일과로 다시 그린다(이룸이 휴대폰이 목록을 새로 받은 경우와 같다)
      await tester.pumpWidget(host('k/b.png'));
      await _settle(tester);
      expect(adapter.gets, 2);
    },
  );
}

/// dio 요청 사슬이 Timer 를 끼고 돌아 여러 번 나눠 흘려야 어댑터까지 닿는다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

class _CountingAdapter implements HttpClientAdapter {
  int gets = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') gets++;
    return ResponseBody.fromBytes(
      [1, 2, 3],
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
