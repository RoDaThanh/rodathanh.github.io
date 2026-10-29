import Foundation

/// Same data source and streak rules as the web page (index.html).
struct Day: Decodable {
    let date: String
    let count: Int
    let level: Int
}

struct Streak {
    let user: String
    let days: [Day]
    let todayCount: Int
    let current: Int
    let best: Int
    let total: Int

    /// Battery-style charge: how close the current streak is to the best one.
    var percent: Double {
        guard best > 0 else { return 0 }
        return min(Double(current) / Double(best), 1)
    }

    var doneToday: Bool { todayCount > 0 }

    init(user: String, days all: [Day], now: Date = Date()) {
        let todayIso = Streak.iso(now)
        let days = all.filter { $0.date <= todayIso }
        let map = Dictionary(days.map { ($0.date, $0.count) }, uniquingKeysWith: { a, _ in a })
        let todayCount = map[todayIso] ?? 0

        // Today counts if done; if not yet, the streak from yesterday is still alive.
        let cal = Calendar.current
        var cursor = todayCount > 0 ? now : cal.date(byAdding: .day, value: -1, to: now)!
        var current = 0
        while (map[Streak.iso(cursor)] ?? 0) > 0 {
            current += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }

        var best = 0, run = 0
        for d in days {
            run = d.count > 0 ? run + 1 : 0
            best = max(best, run)
        }

        self.user = user
        self.days = days
        self.todayCount = todayCount
        self.current = current
        self.best = best
        self.total = days.reduce(0) { $0 + $1.count }
    }

    static func iso(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func fetch(user: String) async throws -> Streak {
        struct Response: Decodable { let contributions: [Day] }
        let name = user.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        let escaped = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = URL(string: "https://github-contributions-api.jogruber.de/v4/\(escaped)?y=last")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return Streak(user: name, days: decoded.contributions)
    }

    /// Sample used for the widget gallery preview.
    static var sample: Streak {
        let cal = Calendar.current
        let now = Date()
        let days = (0..<120).reversed().map { offset -> Day in
            let date = cal.date(byAdding: .day, value: -offset, to: now)!
            let count = offset < 18 ? (offset % 3) + 1 : (offset % 5 == 0 ? 0 : (offset % 4))
            return Day(date: iso(date), count: count, level: min(count, 4))
        }
        return Streak(user: "rodathanh", days: days, now: now)
    }
}
