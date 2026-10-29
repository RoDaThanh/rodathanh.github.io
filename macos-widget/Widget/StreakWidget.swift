import AppIntents
import SwiftUI
import WidgetKit

struct ConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "GitHub user"
    static var description = IntentDescription("Whose contribution streak to show.")

    @Parameter(title: "Username", default: "rodathanh")
    var username: String
}

struct Entry: TimelineEntry {
    let date: Date
    let streak: Streak?
    let user: String
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), streak: .sample, user: "rodathanh")
    }

    func snapshot(for config: ConfigIntent, in context: Context) async -> Entry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: config)
    }

    func timeline(for config: ConfigIntent, in context: Context) async -> Timeline<Entry> {
        let now = Date()
        let entry = await entry(for: config)
        // Refresh every 15 min, and right after midnight when "today" resets.
        let soon = now.addingTimeInterval(15 * 60)
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400)).addingTimeInterval(60)
        return Timeline(entries: [entry], policy: .after(min(soon, midnight)))
    }

    private func entry(for config: ConfigIntent) async -> Entry {
        let user = config.username
        let streak = try? await Streak.fetch(user: user)
        return Entry(date: Date(), streak: streak, user: user)
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        Group {
            if let s = entry.streak {
                switch family {
                case .systemMedium: medium(s)
                default: small(s)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
                    Text("Can't load @\(entry.user)").font(.caption).multilineTextAlignment(.center)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "https://rodathanh.github.io/?u=\(entry.user)"))
    }

    private func small(_ s: Streak) -> some View {
        VStack(spacing: 8) {
            StreakRing(streak: s, lineWidth: 8)
                .frame(width: 76, height: 76)
            VStack(spacing: 1) {
                Text("\(s.current) day streak")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                StatusLine(streak: s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func medium(_ s: Streak) -> some View {
        HStack(spacing: 14) {
            StreakRing(streak: s, lineWidth: 8)
                .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("@\(s.user) · best \(s.best)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(s.current)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("day streak")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    StatusLine(streak: s)
                }
                MiniGrid(days: s.days, weeks: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@main
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StreakWidget", intent: ConfigIntent.self, provider: Provider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("GitHub Streak")
        .description("Current streak as a percent of your best, like a battery.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
