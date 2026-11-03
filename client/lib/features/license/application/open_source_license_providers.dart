import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/open_source_license_repository.dart';
import '../domain/open_source_license.dart';

final openSourceLicenseRepositoryProvider =
    Provider<OpenSourceLicenseRepository>(
  (ref) => OpenSourceLicenseRepository(assetBundle: rootBundle),
);

/// 프로그램 라이선스 목록 (화면을 나가면 메모리에서 내림: 전문이 큼)
final softwareLicensesProvider =
    FutureProvider.autoDispose<List<OpenSourceLicense>>(
  (ref) => ref.read(openSourceLicenseRepositoryProvider).loadSoftwareLicenses(),
);

/// 그림·글꼴 전문 1건
final bundledLicenseTextProvider =
    FutureProvider.autoDispose.family<String, BundledLicenseKind>(
  (ref, kind) =>
      ref.read(openSourceLicenseRepositoryProvider).loadBundledLicenseText(kind),
);
