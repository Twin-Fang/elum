import SwiftUI
import UIKit
import WidgetKit

// 루미 위젯 화면 조각: 색 · 진행 막대 · 루미 그림 · 카드 그림 · 위젯별 본문 (#1465)
// 광고·판매 문구 없음 (이룸이 기기에도 같은 위젯이 보임)

/// 위젯 색 (앱 토큰과 같은 값: surface · textPrimary · textSecondary · 민트 · 트랙 · 노랑)
enum ElumWidgetColor {
  static func panel(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0x23 / 255, green: 0x25 / 255, blue: 0x2F / 255) : .white
  }
  static func primaryText(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? .white : Color(red: 0x24 / 255, green: 0x26 / 255, blue: 0x34 / 255)
  }
  static let secondaryText = Color(red: 0x89 / 255, green: 0x8B / 255, blue: 0x98 / 255)
  static let mint = Color(red: 0x55 / 255, green: 0xCF / 255, blue: 0xBA / 255)
  static func track(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.white.opacity(0.15) : Color(red: 0xEE / 255, green: 0xE9 / 255, blue: 0xE6 / 255)
  }
  static let yellow = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0x29 / 255)
}

/// 둥근 진행 막대 (끝낸 수 / 전체 수)
struct ElumProgressBar: View {
  let done: Int
  let total: Int
  @Environment(\.colorScheme) private var scheme

  // 막대 두께
  private let barHeight: CGFloat = 8

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(ElumWidgetColor.track(scheme))
        Capsule().fill(ElumWidgetColor.mint)
          .frame(width: geometry.size.width * CGFloat(min(done, total)) / CGFloat(max(total, 1)))
      }
    }
    .frame(height: barHeight)
  }
}

/// 루미 그림 (Assets.xcassets lumi_*)
struct LumiImage: View {
  let name: String
  let size: CGFloat

  var body: some View {
    Image(name).resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
  }
}

/// 카드 그림: App Group 사본 파일을 작게 줄여 읽음 (위젯 메모리 한도), 없으면 nil
enum ElumCardImageLoader {
  // 줄일 긴 변 (픽셀)
  private static let maximumPixelSide: CGFloat = 600

  static func load(_ path: String?) -> UIImage? {
    guard let path = path, let image = UIImage(contentsOfFile: path) else { return nil }
    let longSide = max(image.size.width, image.size.height)
    guard longSide > maximumPixelSide else { return image }
    let scale = maximumPixelSide / longSide
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }
}

/// 위젯 머리: "{이름} · 오늘" 또는 "오늘" (작은 회색)
struct ElumWidgetHeader: View {
  let entry: ElumWidgetEntry

  var body: some View {
    let name = entry.snapshot?.elumiName
    Text(name.map { "\($0) · \(ElumWidgetText.text("today.name"))" } ?? ElumWidgetText.text("today.name"))
      .font(.system(size: 12, weight: .semibold))
      .foregroundColor(ElumWidgetColor.secondaryText)
      .lineLimit(1)
  }
}

/// 「오늘 루미」 본문: 소 = 루미 위 · 글 아래 / 중 = 루미 왼쪽 크게 · 글 오른쪽
struct ElumTodayView: View {
  let entry: ElumWidgetEntry
  let isMedium: Bool
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let snapshot = entry.snapshot
    let lumi = LumiImage(name: entry.mood.imageName(isElumiDevice: entry.isElumiDevice), size: isMedium ? 112 : 76)
    let message = Text(ElumWidgetText.message(for: entry))
      .font(.system(size: isMedium ? 17 : 14, weight: .bold))
      .foregroundColor(ElumWidgetColor.primaryText(scheme))
      .lineLimit(2)
      .minimumScaleFactor(0.85)
    let progress = Group {
      if let snapshot = snapshot, entry.mood != .stale, snapshot.totalCount > 0 {
        ElumProgressBar(done: snapshot.doneCount, total: snapshot.totalCount)
      }
    }
    let next = Group {
      if let title = snapshot?.nextRoutineTitle, entry.mood == .progress || entry.mood == .ready || entry.mood == .morning {
        Text(String(format: ElumWidgetText.text("next"), title))
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(ElumWidgetColor.secondaryText)
          .lineLimit(1)
      }
    }
    if isMedium {
      HStack(spacing: 14) {
        lumi
        VStack(alignment: .leading, spacing: 7) {
          ElumWidgetHeader(entry: entry)
          message
          progress
          next
        }
        Spacer(minLength: 0)
      }
    } else {
      VStack(alignment: .leading, spacing: 6) {
        lumi
        Spacer(minLength: 0)
        message
        progress
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// 「오늘 루미」 큰 화면 (지금 할 카드 대 · 카드 없을 때): 루미 가운데 크게 > 이름 · 한마디 · 진행 · 다음 할 일
struct ElumTodayLargeView: View {
  let entry: ElumWidgetEntry
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let snapshot = entry.snapshot
    VStack(spacing: 8) {
      Spacer(minLength: 0)
      LumiImage(name: entry.mood.imageName(isElumiDevice: entry.isElumiDevice), size: 150)
      ElumWidgetHeader(entry: entry)
      Text(ElumWidgetText.message(for: entry))
        .font(.system(size: 22, weight: .heavy))
        .foregroundColor(ElumWidgetColor.primaryText(scheme))
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
      if let snapshot = snapshot, entry.mood != .stale, snapshot.totalCount > 0 {
        ElumProgressBar(done: snapshot.doneCount, total: snapshot.totalCount)
      }
      if let title = snapshot?.nextRoutineTitle, entry.mood == .progress || entry.mood == .ready || entry.mood == .morning {
        Text(String(format: ElumWidgetText.text("next"), title))
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(ElumWidgetColor.secondaryText)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
  }
}

/// 「지금 할 카드」 본문: 카드가 있으면 그림 + 카드 글, 없으면 「오늘 루미」 와 같은 화면
struct ElumNowCardView: View {
  let entry: ElumWidgetEntry
  let family: WidgetFamily
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    // 이룸이 기기: 위젯에서 체크한 카드는 건너뛰고 다음 카드 (#1465 2단계)
    switch entry.checkMode {
    case .queue(let shown), .openAppToCheck(let shown):
      if let card = entry.snapshot?.elumiCard { content(card: card, shown: shown) }
    case .continueInApp:
      continueInAppView
    case .none:
      if let card = entry.snapshot?.elumiCard, entry.mood != .stale, entry.mood != .done {
        content(card: card, shown: ElumWidgetShownCard(cardId: card.cardId, cardText: card.cardText ?? "", imageFilePath: card.imageFilePath))
      } else if family == .systemLarge {
        // 대 크기에 중 배치를 쓰면 아래가 텅 빔 > 루미 가운데 크게
        ElumTodayLargeView(entry: entry)
      } else {
        ElumTodayView(entry: entry, isMedium: family != .systemSmall)
      }
    }
  }

  // 받아 둔 다음 카드를 다 넘김 > 앱에서 이어서 (누르면 그 일과)
  private var continueInAppView: some View {
    VStack(spacing: 8) {
      Spacer(minLength: 0)
      LumiImage(name: "lumi_cheer", size: family == .systemSmall ? 70 : 96)
      Text(ElumWidgetText.text("check.praise"))
        .font(.system(size: 15, weight: .heavy))
        .foregroundColor(ElumWidgetColor.primaryText(scheme))
      Text(ElumWidgetText.text("check.continue"))
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(ElumWidgetColor.secondaryText)
        .lineLimit(2)
        .multilineTextAlignment(.center)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func content(card: ElumWidgetCard, shown: ElumWidgetShownCard) -> some View {
    let picture = cardPicture(imageFilePath: shown.imageFilePath)
    let cardText = Text(shown.cardText)
      .font(.system(size: family == .systemLarge ? 24 : (family == .systemMedium ? 19 : 15), weight: .heavy))
      .foregroundColor(ElumWidgetColor.primaryText(scheme))
      .lineLimit(2)
      .minimumScaleFactor(0.8)
    // 방금 체크했으면 일과 제목 자리에 칭찬 한마디
    let isPraising = ElumWidgetCheckStore.isRecentlyChecked(at: entry.date)
    let subline = Text(isPraising ? ElumWidgetText.text("check.praise") : (card.routineTitle ?? ""))
      .font(.system(size: 12, weight: isPraising ? .heavy : .medium))
      .foregroundColor(isPraising ? ElumWidgetColor.mint : ElumWidgetColor.secondaryText)
      .lineLimit(1)
    switch family {
    case .systemSmall:
      VStack(alignment: .leading, spacing: 6) {
        picture.frame(maxWidth: .infinity, maxHeight: .infinity)
        HStack(spacing: 6) {
          cardText
          Spacer(minLength: 0)
          checkButton(card: card, shown: shown, isCompact: true)
        }
      }
    case .systemMedium:
      HStack(spacing: 14) {
        picture.frame(width: 118, height: 118)
        VStack(alignment: .leading, spacing: 6) {
          progressChip
          cardText
          subline
          checkButton(card: card, shown: shown, isCompact: false)
        }
        Spacer(minLength: 0)
      }
    default:
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(ElumWidgetText.text("nowCard"))
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(ElumWidgetColor.secondaryText)
          Spacer()
          progressChip
        }
        picture.frame(maxWidth: .infinity, maxHeight: .infinity)
        cardText
        HStack {
          subline
          Spacer(minLength: 0)
          checkButton(card: card, shown: shown, isCompact: false)
        }
      }
    }
  }

  /// 「다 했어요」: 남은 카드 2장 이상 > 위젯 안에서 체크(iOS 17+) · 마지막 카드 > 앱 열어 체크 (작은 크기는 위젯 전체가 앱 열기)
  @ViewBuilder
  private func checkButton(card: ElumWidgetCard, shown: ElumWidgetShownCard, isCompact: Bool) -> some View {
    let label = checkButtonLabel(isCompact: isCompact)
    switch entry.checkMode {
    case .queue:
      if #available(iOSApplicationExtension 17.0, *) {
        Button(intent: ElumCheckCardIntent(routineId: card.routineId, cardId: shown.cardId, dateKey: entry.snapshot?.dateKey ?? "")) {
          label
        }
        .buttonStyle(.plain)
      }
    case .openAppToCheck:
      if family != .systemSmall {
        Link(destination: ElumWidgetRoute.checkURL(routineId: card.routineId, cardId: shown.cardId)) { label }
      }
    default:
      EmptyView()
    }
  }

  // 민트 둥근 버튼 (작은 크기는 체크 표시만)
  private func checkButtonLabel(isCompact: Bool) -> some View {
    Group {
      if isCompact {
        Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy))
          .frame(width: 32, height: 32)
      } else {
        Text(ElumWidgetText.text("check.done")).font(.system(size: 14, weight: .heavy))
          .padding(.horizontal, 14).padding(.vertical, 7)
      }
    }
    .foregroundColor(.white)
    .background(Capsule().fill(ElumWidgetColor.mint))
    .accessibilityLabel(ElumWidgetText.text("check.done"))
  }

  // 그림: 카드 그림 사본 > 없으면 카드를 든 루미 (흰 판 위 둥근 칸)
  private func cardPicture(imageFilePath: String?) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(scheme == .dark ? Color.white.opacity(0.08) : Color(red: 0xF7 / 255, green: 0xF2 / 255, blue: 0xEF / 255))
      if let image = ElumCardImageLoader.load(imageFilePath) {
        Image(uiImage: image).resizable().scaledToFit().padding(6)
      } else {
        Image("lumi_holding_card").resizable().scaledToFit().padding(8)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .accessibilityHidden(true)
  }

  // "2/4" 민트 알약 (진행 표시)
  private var progressChip: some View {
    let done = entry.snapshot?.doneCount ?? 0
    let total = entry.snapshot?.totalCount ?? 0
    return Text("\(done)/\(total)")
      .font(.system(size: 12, weight: .bold))
      .foregroundColor(.white)
      .padding(.horizontal, 9)
      .padding(.vertical, 3)
      .background(Capsule().fill(ElumWidgetColor.mint))
  }
}

/// 「별과 연속」 본문: 연속 2일 이상이면 불꽃 루미 + "n일 연속", 아니면 기본 루미 · 아래 별 수
struct ElumStreakView: View {
  let entry: ElumWidgetEntry
  @Environment(\.colorScheme) private var scheme

  // 연속으로 부르는 최소 일수 (앱 ElumiStreak.minimumVisibleDays 와 같음)
  private let minimumVisibleDays = 2

  var body: some View {
    let streak = entry.snapshot?.streakDays ?? 0
    let stars = entry.snapshot?.starCount ?? 0
    let hasStreak = streak >= minimumVisibleDays
    VStack(spacing: 4) {
      LumiImage(name: hasStreak ? "lumi_streak_flame" : "lumi_idle", size: 74)
      if hasStreak {
        Text(String(format: ElumWidgetText.text("streakDays"), streak))
          .font(.system(size: 16, weight: .heavy))
          .foregroundColor(ElumWidgetColor.primaryText(scheme))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      HStack(spacing: 4) {
        Image("widget_star").resizable().scaledToFit().frame(width: 16, height: 16).accessibilityHidden(true)
        Text(String(format: ElumWidgetText.text("stars"), stars))
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(ElumWidgetColor.secondaryText)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// 잠금화면 위젯 본문 (iOS 16+): 원형 진행 링 · 직사각형 한마디 · 한 줄
struct ElumLockScreenView: View {
  let entry: ElumWidgetEntry
  let family: WidgetFamily

  var body: some View {
    let done = entry.snapshot?.doneCount ?? 0
    let total = entry.snapshot?.totalCount ?? 0
    let isKnown = entry.mood != .stale && total > 0
    switch family {
    case .accessoryCircular:
      Gauge(value: Double(isKnown ? min(done, total) : 0), in: 0...Double(max(total, 1))) {
        Image(systemName: "star.fill")
      } currentValueLabel: {
        Text(isKnown ? "\(done)/\(total)" : "-").font(.system(size: 12, weight: .bold))
      }
      .gaugeStyle(.accessoryCircular)
    case .accessoryInline:
      Text(ElumWidgetText.message(for: entry))
    default:
      VStack(alignment: .leading, spacing: 3) {
        Text(ElumWidgetText.message(for: entry)).font(.system(size: 14, weight: .bold)).lineLimit(2)
        if isKnown {
          Gauge(value: Double(min(done, total)), in: 0...Double(total)) { EmptyView() }
            .gaugeStyle(.accessoryLinearCapacity)
        }
      }
    }
  }
}

extension View {
  /// 위젯 판 배경 (iOS 17+ containerBackground, 그 아래는 여백 + 배경)
  @ViewBuilder
  func elumWidgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      padding().background(color)
    }
  }
}
