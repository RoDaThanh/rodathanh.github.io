import SwiftUI

/// Same colors as the web page, including its light-mode palette.
enum Palette {
    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double(v >> 16 & 0xff) / 255, green: Double(v >> 8 & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }

    /// Brand green from the web page.
    static func accent(_ scheme: ColorScheme) -> Color { hex(scheme == .dark ? 0x39d353 : 0x1f883d) }

    static func tint(_ s: Streak, _ scheme: ColorScheme) -> Color {
        switch (s.doneToday, scheme) {
        case (true, .dark): return hex(0x39d353)
        case (true, _): return hex(0x1f883d)
        case (false, .dark): return hex(0xf0b429)
        case (false, _): return hex(0xb7791f)
        }
    }

    static func level(_ level: Int, _ scheme: ColorScheme) -> Color {
        let i = min(max(level, 0), 4)
        if i == 0 { return Color.primary.opacity(0.09) }
        let dark: [UInt32] = [0x0e4429, 0x006d32, 0x26a641, 0x39d353]
        let light: [UInt32] = [0x9be9a8, 0x40c463, 0x30a14e, 0x216e39]
        return hex((scheme == .dark ? dark : light)[i - 1])
    }
}

/// Ring like the macOS Battery widget: track, filled arc, percent in the middle.
struct StreakRing: View {
    @Environment(\.colorScheme) private var scheme
    let streak: Streak
    var lineWidth: CGFloat = 7

    var body: some View {
        let tint = Palette.tint(streak, scheme)
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(streak.percent, 0.001))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Image(systemName: streak.doneToday ? "flame.fill" : "flame")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text("\(Int((streak.percent * 100).rounded()))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak.current) day streak, \(Int(streak.percent * 100)) percent of best streak \(streak.best)")
    }
}

struct StatusLine: View {
    @Environment(\.colorScheme) private var scheme
    let streak: Streak

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.tint(streak, scheme))
            .lineLimit(1)
    }

    private var text: String {
        if streak.doneToday { return "Today: \(streak.todayCount) done" }
        return streak.current > 0 ? "Streak at risk" : "Nothing yet today"
    }
}

/// Last N weeks of the contribution calendar, Sunday-first like GitHub.
struct MiniGrid: View {
    @Environment(\.colorScheme) private var scheme
    let days: [Day]
    var weeks = 12
    var spacing: CGFloat = 2

    var body: some View {
        let recent = Array(days.suffix(weeks * 7 - 7 + todayWeekday))
        let columns = stride(from: 0, to: recent.count, by: 7).map { Array(recent[$0..<min($0 + 7, recent.count)]) }
        GeometryReader { geo in
            let cell = min((geo.size.width - spacing * CGFloat(weeks - 1)) / CGFloat(weeks),
                           (geo.size.height - spacing * 6) / 7)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(columns.indices, id: \.self) { c in
                    VStack(spacing: spacing) {
                        ForEach(columns[c].indices, id: \.self) { r in
                            RoundedRectangle(cornerRadius: cell * 0.22)
                                .fill(Palette.level(columns[c][r].level, scheme))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    /// Days in the current (partial) week, so the last column ends on today.
    private var todayWeekday: Int { Calendar.current.component(.weekday, from: Date()) }
}

/// Full-year calendar laid out like GitHub's profile: month labels, Mon/Wed/Fri, Less-More legend.
struct YearGrid: View {
    @Environment(\.colorScheme) private var scheme
    let days: [Day]
    var cell: CGFloat = 7
    var gap: CGFloat = 2
    @State private var hovered: Day?

    private let left: CGFloat = 28
    private let top: CGFloat = 15
    private var step: CGFloat { cell + gap }
    /// Sunday-first rows like GitHub: blank cells before the first day.
    private var offset: Int { days.first.map { Self.weekday($0.date) } ?? 0 }
    private var weeks: Int { (days.count + offset + 6) / 7 }
    private var size: CGSize {
        CGSize(width: left + CGFloat(weeks) * step - gap, height: top + 7 * step - gap)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { ctx, size in
                let label = { (s: String) in Text(s).font(.system(size: 9)).foregroundColor(.secondary) }
                var lastMonth = -1
                for (i, d) in days.enumerated() {
                    let idx = i + offset
                    let x = left + CGFloat(idx / 7) * step, y = top + CGFloat(idx % 7) * step
                    let (month, dayOfMonth) = Self.monthDay(d.date)
                    if idx % 7 == 0, month != lastMonth, dayOfMonth <= 7, x < size.width - 20 {
                        lastMonth = month
                        ctx.draw(label(Calendar.current.shortMonthSymbols[month - 1]),
                                 at: CGPoint(x: x, y: 0), anchor: .topLeading)
                    }
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.22), with: .color(Palette.level(d.level, scheme)))
                }
                for (row, name) in [(1, "Mon"), (3, "Wed"), (5, "Fri")] {
                    ctx.draw(label(name), at: CGPoint(x: 0, y: top + CGFloat(row) * step + cell / 2), anchor: .leading)
                }
            }
            .frame(width: size.width, height: size.height)
            .onContinuousHover { phase in
                guard case .active(let p) = phase, p.x >= left, p.y >= top else { hovered = nil; return }
                let idx = Int((p.x - left) / step) * 7 + Int((p.y - top) / step) - offset
                hovered = days.indices.contains(idx) ? days[idx] : nil
            }

            HStack(spacing: 3) {
                Text(hoverText).lineLimit(1)
                Spacer(minLength: 8)
                Text("Less")
                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.level(level, scheme))
                        .frame(width: cell + 1, height: cell + 1)
                }
                Text("More")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .frame(width: size.width)
        }
    }

    private var hoverText: String {
        guard let d = hovered else { return "" }
        let (m, day) = Self.monthDay(d.date)
        let when = "\(Calendar.current.shortMonthSymbols[m - 1]) \(day)"
        return d.count == 0 ? "No contributions on \(when)" : "\(d.count) contribution\(d.count == 1 ? "" : "s") on \(when)"
    }

    static func monthDay(_ iso: String) -> (Int, Int) {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? (p[1], p[2]) : (1, 1)
    }

    /// 0 = Sunday.
    static func weekday(_ iso: String) -> Int {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, let date = Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return 0 }
        return Calendar.current.component(.weekday, from: date) - 1
    }
}
