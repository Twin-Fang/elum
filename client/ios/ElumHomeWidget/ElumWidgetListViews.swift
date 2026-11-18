import SwiftUI
import WidgetKit

// 위젯 2종 화면 (#1465): 「오늘 일과 목록」(중·대) · 「빠른 만들기」(소)
// 규칙: docs/superpowers/specs/2026-11-18-lumi-widgets-design.md 「위젯 2종 추가」

/// 「오늘 일과 목록」: 머리(루미 · 오늘 일과 · 전체 n/m) + 일과 줄 (중 3 · 대 4) · 줄을 누르면 그 일과(이룸이 기기)
struct ElumRoutineListView: View {
  let entry: ElumWidgetEntry
  let family: WidgetFamily
  @Environment(\.colorScheme) private var scheme

  // 크기별 줄 수 (요약은 최대 4줄)
  private var maximumRows: Int { family == .systemLarge ? 4 : 3 }

  var body: some View {
    let rows = Array((entry.snapshot?.routines ?? []).prefix(maximumRows))
    VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 8) {
      header
      if rows.isEmpty || entry.mood == .stale {
        emptyState
      } else {
        ForEach(rows) { row in
          Link(destination: rowURL(row)) { rowView(row) }
        }
        Spacer(minLength: 0)
        // 대 크기: 아래에 루미 한마디 (줄이 적어도 빈칸이 남지 않게)
        if family == .systemLarge { lumiFooter }
      }
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      LumiImage(name: entry.mood.imageName(isElumiDevice: entry.isElumiDevice), size: 34)
      Text(ElumWidgetText.text("list.header"))
        .font(.system(size: 15, weight: .heavy))
        .foregroundColor(ElumWidgetColor.primaryText(scheme))
      Spacer(minLength: 0)
      if let snapshot = entry.snapshot, entry.mood != .stale, snapshot.totalCount > 0 {
        Text("\(snapshot.doneCount)/\(snapshot.totalCount)")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 9).padding(.vertical, 3)
          .background(Capsule().fill(ElumWidgetColor.mint))
      }
    }
  }

  private var lumiFooter: some View {
    HStack(spacing: 10) {
      LumiImage(name: entry.mood.imageName(isElumiDevice: entry.isElumiDevice), size: 72)
      Text(ElumWidgetText.message(for: entry))
        .font(.system(size: 16, weight: .heavy))
        .foregroundColor(ElumWidgetColor.primaryText(scheme))
        .lineLimit(2)
      Spacer(minLength: 0)
    }
  }

  // 일과 없음 · 오래된 요약: 루미 + 한마디 (오늘 루미와 같은 문구)
  private var emptyState: some View {
    HStack(spacing: 12) {
      LumiImage(name: entry.mood.imageName(isElumiDevice: entry.isElumiDevice), size: 64)
      Text(ElumWidgetText.message(for: entry))
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(ElumWidgetColor.primaryText(scheme))
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .frame(maxHeight: .infinity)
  }

  private func rowView(_ row: ElumWidgetRoutineRow) -> some View {
    HStack(spacing: 10) {
      Text(row.title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(ElumWidgetColor.primaryText(scheme))
        .lineLimit(1)
      Spacer(minLength: 4)
      if row.isDone {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(ElumWidgetColor.mint)
      } else {
        ElumProgressBar(done: row.doneCards, total: row.totalCards).frame(width: 56)
        Text("\(row.doneCards)/\(row.totalCards)")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(ElumWidgetColor.secondaryText)
          .frame(minWidth: 28, alignment: .trailing)
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 7)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(scheme == .dark ? Color.white.opacity(0.06) : Color(red: 0xF7 / 255, green: 0xF2 / 255, blue: 0xEF / 255))
    )
  }

  // 이룸이 기기 > 그 일과 카드 · 보호자 기기 > 홈
  private func rowURL(_ row: ElumWidgetRoutineRow) -> URL {
    entry.isElumiDevice ? ElumWidgetRoute.url(routineId: row.id) : ElumWidgetRoute.url()
  }
}

/// 「빠른 만들기」: 새 일과를 들고 오는 루미 + 민트 알약 (누르면 일과 만들기 시작)
struct ElumQuickCreateView: View {
  var body: some View {
    VStack(spacing: 8) {
      Spacer(minLength: 0)
      LumiImage(name: "lumi_new_routine", size: 80)
      Text(ElumWidgetText.text("create.action"))
        .font(.system(size: 14, weight: .heavy))
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(ElumWidgetColor.mint))
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
  }
}
