/// 앱에 함께 넣은 그림·글꼴 3개 (이름은 화면 문구, 전문은 앱 자산)
enum BundledLicenseKind { mulberrySymbols, pretendard, tmoneyRoundWind }

/// 라이선스 1건: 이름, 종류 표시(없으면 빈 값), 전문
class OpenSourceLicense {
  const OpenSourceLicense({
    required this.name,
    required this.licenseTypeLabel,
    required this.fullText,
  });

  final String name;
  final String licenseTypeLabel;
  final String fullText;
}
