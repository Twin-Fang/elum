import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/assets/app_assets.dart';
import '../domain/open_source_license.dart';

/// 라이선스 읽기: 그림·글꼴(앱 자산), 프로그램(Flutter 라이선스 목록)
class OpenSourceLicenseRepository {
  const OpenSourceLicenseRepository({required AssetBundle assetBundle})
      : _assetBundle = assetBundle;

  final AssetBundle _assetBundle;

  /// 그림·글꼴 전문 (자산 경로 > 글)
  Future<String> loadBundledLicenseText(BundledLicenseKind kind) =>
      _assetBundle.loadString(switch (kind) {
        BundledLicenseKind.mulberrySymbols => AppAssets.licenseMulberrySymbols,
        BundledLicenseKind.twemoji => AppAssets.licenseTwemoji,
        BundledLicenseKind.pretendard => AppAssets.licensePretendard,
        BundledLicenseKind.tmoneyRoundWind => AppAssets.licenseTmoneyRoundWind,
      });

  /// 패키지별 라이선스 묶기 > 이름순 목록 (한 패키지에 여러 건이면 전문을 이어 붙임)
  Future<List<OpenSourceLicense>> loadSoftwareLicenses() async {
    final licenseTextsByPackage = <String, List<String>>{};
    await for (final licenseEntry in LicenseRegistry.licenses) {
      final licenseText = _toLicenseText(licenseEntry);
      for (final packageName in licenseEntry.packages) {
        (licenseTextsByPackage[packageName] ??= []).add(licenseText);
      }
    }
    final packageNames = licenseTextsByPackage.keys.toList()..sort();
    return [
      for (final packageName in packageNames)
        OpenSourceLicense(
          name: packageName,
          licenseTypeLabel:
              _toLicenseTypeLabel(licenseTextsByPackage[packageName]!),
          fullText: licenseTextsByPackage[packageName]!.join(_licenseSeparator),
        ),
    ];
  }

  // 같은 패키지의 라이선스 사이 구분선
  static const _licenseSeparator = '\n\n----------\n\n';

  // 줄 나눔 항목은 원문 그대로 (문단 해석은 건수가 많으면 화면을 멈춤)
  String _toLicenseText(LicenseEntry licenseEntry) =>
      licenseEntry is LicenseEntryWithLineBreaks
          ? licenseEntry.text
          : licenseEntry.paragraphs.map((paragraph) => paragraph.text).join('\n\n');

  // 원문 > 종류 표시. 전부 같은 종류일 때만 표시 (섞이거나 모르면 빈 값, 판단은 전문으로)
  String _toLicenseTypeLabel(List<String> licenseTexts) {
    final licenseTypeLabels = licenseTexts.map(_detectLicenseType).toSet();
    return licenseTypeLabels.length == 1 ? licenseTypeLabels.single : '';
  }

  String _detectLicenseType(String licenseText) {
    if (licenseText.contains('Mozilla Public License')) return 'MPL 2.0';
    if (licenseText.contains('Apache License')) return 'Apache 2.0';
    if (licenseText.contains('Permission is hereby granted')) return 'MIT';
    if (licenseText.contains('Redistribution and use')) return 'BSD';
    return '';
  }
}
