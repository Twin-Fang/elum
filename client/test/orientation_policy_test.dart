import 'package:elum/core/layout/device_kind.dart';
import 'package:elum/core/layout/orientation_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 기기 종류별 방향 허용.
/// 깨지면: 폰이 가로로 돌아가 시안 없는 화면이 뜨거나, 태블릿이 세로에 갇힌다.
void main() {
  group('DeviceKind', () {
    test('짧은 변 599 는 phone, 600 은 tablet', () {
      expect(DeviceKind.fromLogicalSize(const Size(599, 1000)), DeviceKind.phone);
      expect(DeviceKind.fromLogicalSize(const Size(600, 960)), DeviceKind.tablet);
    });

    test('가로로 든 폰(852x393)도 짧은 변으로 폰', () {
      expect(DeviceKind.fromLogicalSize(const Size(852, 393)), DeviceKind.phone);
    });

    test('아이패드 가로(1194x834)는 tablet', () {
      expect(DeviceKind.fromLogicalSize(const Size(1194, 834)), DeviceKind.tablet);
    });

    test('크기를 모르면(0x0) phone 으로 둔다', () {
      expect(DeviceKind.fromLogicalSize(Size.zero), DeviceKind.phone);
    });
  });

  group('OrientationPolicy.allowedOrientationsFor', () {
    test('폰은 세로 한 방향', () {
      expect(
        OrientationPolicy.allowedOrientationsFor(DeviceKind.phone),
        [DeviceOrientation.portraitUp],
      );
    });

    test('태블릿은 네 방향 모두', () {
      expect(
        OrientationPolicy.allowedOrientationsFor(DeviceKind.tablet),
        containsAll([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    });
  });

  testWidgets('apply 가 기기 크기에 맞는 방향을 플랫폼에 전달한다', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1194, 834);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await OrientationPolicy.apply(view: tester.view);

    final call = calls.singleWhere(
      (c) => c.method == 'SystemChrome.setPreferredOrientations',
    );
    expect((call.arguments as List).length, 4);
  });

  testWidgets('화면 크기를 아직 모르면(0x0) 방향을 잠그지 않는다', (tester) async {
    // 안드로이드는 첫 프레임 전 뷰 크기가 0 일 수 있다. 이때 폰으로 오판해 세로를 잠그면
    // 태블릿이 레터박스 세로 창으로 뜬다.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size.zero;
    tester.view.display.size = Size.zero;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.display.reset);

    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await OrientationPolicy.apply(view: tester.view);

    expect(
      calls.where((c) => c.method == 'SystemChrome.setPreferredOrientations'),
      isEmpty,
    );
  });
}
