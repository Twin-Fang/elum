import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('bottomButton과 bottomBanner를 함께 쓰면 assert로 막는다', () {
    expect(
      () => ElumScaffold(
        bottomButton: const SizedBox(),
        bottomBanner: const SizedBox(),
        child: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });

}
