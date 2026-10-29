import AppKit
import ServiceManagement
import SwiftUI

/// Menu bar app: a tiny GitHub-style contribution grid next to the battery, click for details. No Dock icon, no window.
@main
struct StreakboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class StreakModel: ObservableObject {
    @Published var streak: Streak?
    @Published var failed = false
    @Published var updated: Date?
    @Published var user: String {
        didSet { UserDefaults.standard.set(user, forKey: "user") }
    }

    private var timer: Timer?

    init() {
        user = UserDefaults.standard.string(forKey: "user") ?? "rodathanh"
        timer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { await self?.refresh() } }
    }

    func refresh() async {
        do {
            streak = try await Streak.fetch(user: user)
            failed = false
            updated = Date()
        } catch {
            failed = true
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = StreakModel()
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var observer: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageOnly
        item.button?.action = #selector(toggle)
        item.button?.target = self
        // Left click opens the panel; right click shows a small menu with Quit.
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PanelView(model: model))

        observer = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.updateButton() }
        }
        updateButton()
        Task { await model.refresh() }
    }

    private func updateButton() {
        guard let button = item.button else { return }
        if let s = model.streak {
            button.image = Self.grid(s.days)
            let week = Self.weekLevels(s.days, weeks: 1)[0]
            button.toolTip = "@\(s.user): \(s.current)-day streak, best \(s.best)\nThis week: \(week.active) of \(week.days) days"
            button.setAccessibilityLabel(button.toolTip)
        } else if model.failed {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Streakboard can't load data")
            button.toolTip = "Can't load @\(model.user)"
        } else {
            button.image = Self.grid([])
        }
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit Streakboard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await model.refresh() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Active days per week (Sunday-first, like GitHub), oldest first, ending with the current partial week.
    /// Level 0-4 is the share of days with a contribution: 4 = every day. The current week
    /// only counts the days so far, so a perfect Monday already shows full green.
    static func weekLevels(_ all: [Day], weeks: Int) -> [(active: Int, days: Int, level: Int)] {
        let todayRow = Calendar.current.component(.weekday, from: Date()) - 1
        let days = Array(all.suffix((weeks - 1) * 7 + todayRow + 1))
        let padded = Array(repeating: nil as Day?, count: (weeks - 1) * 7 + todayRow + 1 - days.count) + days.map { Optional($0) }
        return stride(from: 0, to: padded.count, by: 7).map { start in
            let week = padded[start..<min(start + 7, padded.count)]
            let active = week.filter { ($0?.count ?? 0) > 0 }.count
            let share = Double(active) / Double(week.count)
            return (active, week.count, active == 0 ? 0 : max(1, Int((share * 4).rounded(.up))))
        }
    }

    /// One row of squares in the menu bar, one per week, today's week on the right.
    /// Redrawn on every display so it follows the light or dark menu bar.
    static func grid(_ all: [Day], weeks: Int = 10) -> NSImage {
        let cell: CGFloat = 6, gap: CGFloat = 1.5, step = cell + gap
        let levels = weekLevels(all, weeks: weeks).map(\.level)
        let size = NSSize(width: CGFloat(weeks) * step - gap, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let colors: [NSColor] = [NSColor.labelColor.withAlphaComponent(0.18)] + (dark
                ? [0x1b6b30, 0x2ea043, 0x56d364, 0x9cf0a8] // brighter than the web's dark palette so small cells stay visible
                : [0x9be9a8, 0x40c463, 0x30a14e, 0x216e39]).map(Self.color)
            let y = (rect.height - cell) / 2
            for (i, level) in levels.enumerated() {
                colors[min(max(level, 0), 4)].setFill()
                NSBezierPath(roundedRect: NSRect(x: CGFloat(i) * step, y: y, width: cell, height: cell), xRadius: 1.5, yRadius: 1.5).fill()
            }
            return true
        }
        return image
    }

    private static func color(_ v: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

struct PanelView: View {
    @ObservedObject var model: StreakModel
    @Environment(\.colorScheme) private var scheme
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let s = model.streak {
                (Text("@\(s.user)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Palette.accent(scheme))
                 + Text("  ·  \(s.total.formatted()) contributions in the last year")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary))
                    .lineLimit(1)
                YearGrid(days: s.days)
            } else if model.failed {
                Label("Can't load @\(model.user)", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }

            Divider()

            HStack {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Spacer()
                Button("Open Streakboard") {
                    let user = model.user.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model.user
                    NSWorkspace.shared.open(URL(string: "https://rodathanh.github.io/?u=\(user)")!)
                }
            }

            if let updated = model.updated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened)) · refreshes every 10 min")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 540)
    }
}
