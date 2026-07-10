//
//  Agents.swift
//  chat-ios
//
//  Agent roster + @mention routing + time/Rupiah formatting helpers.
//

import SwiftUI

nonisolated struct AgentSpec: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let initial: String
    let color: Color
    /// Backend `POST` route for messaging this agent directly (nil for the "soon" teasers).
    let endpoint: String?
    let desc: String
}

nonisolated enum Agents {
    static let ava = AgentSpec(
        id: "ava", name: "Ava", role: "orkestrator", initial: "A", color: Theme.ava,
        endpoint: "/ava",
        desc: "Orkestrator. Dengerin kamu, pahami kebutuhanmu, lalu koordinasiin agent yang tepat — kamu cukup ngobrol dari satu tempat."
    )
    static let zee = AgentSpec(
        id: "zee", name: "Zee", role: "smart home (tuya smart)", initial: "Z", color: Theme.zee,
        endpoint: "/zee",
        desc: "Tuya smart agent. Kontrol perangkat rumah — lampu, AC, colokan, dan device Tuya lainnya."
    )
    static let yori = AgentSpec(
        id: "yori", name: "Yori", role: "musik (spotify)", initial: "Y", color: Theme.yori,
        endpoint: "/yori",
        desc: "Spotify music agent. Play, pause, ganti lagu, dan setelin playlist di akun Spotify-mu."
    )
    static let rafal = AgentSpec(
        id: "rafal", name: "Rafal", role: "gmail, kontak & kalender", initial: "R", color: Theme.rafal,
        endpoint: "/rafal",
        desc: "Google Workspace agent. Urus Gmail (baca, rangkum, kirim email), kontak, sampai Google Calendar (lihat jadwal & bikin acara)."
    )

    static let all: [AgentSpec] = [ava, zee, yori, rafal]
    static let byID: [String: AgentSpec] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// "Coming soon" teasers — shown on the info page only, not @mentionable.
    static let soon: [AgentSpec] = [
        AgentSpec(
            id: "gojo", name: "Gojo", role: "transport & makanan (gojek)", initial: "G",
            color: Theme.gojo, endpoint: nil,
            desc: "Gojek agent. Pesan GoRide & GoCar, jajan lewat GoFood, sampai kirim barang via GoSend."
        ),
        AgentSpec(
            id: "sophie", name: "Sophie", role: "belanja (shopee)", initial: "S",
            color: Theme.sophie, endpoint: nil,
            desc: "Shopee agent. Cariin barang, bandingin harga, lacak paket, dan checkout keranjang."
        ),
    ]

    /// Pick the target agent from @mentions known to the roster:
    /// - no mention → Ava; exactly one agent → straight to that agent;
    /// - more than one distinct agent → Ava (she orchestrates).
    /// Repeated mentions of the same agent count once.
    static func route(_ text: String) -> AgentSpec {
        var mentioned = Set<String>()
        for match in text.matches(of: /@(\w+)/) {
            let id = String(match.1).lowercased()
            if byID[id] != nil { mentioned.insert(id) }
        }
        if mentioned.count == 1, let only = mentioned.first, let agent = byID[only] {
            return agent
        }
        return ava
    }
}

// MARK: - Time

nonisolated enum TimeFmt {
    static let idDays = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"]
    static let idMonths = [
        "Januari", "Februari", "Maret", "April", "Mei", "Juni",
        "Juli", "Agustus", "September", "Oktober", "November", "Desember",
    ]
    static let idMonthsShort = [
        "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
        "Jul", "Agu", "Sep", "Okt", "Nov", "Des",
    ]

    static func parseISO(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: iso) { return d }
        let plain = ISO8601DateFormatter()
        return plain.date(from: iso)
    }

    /// Local "HH:MM"
    static func clock(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func clock(iso: String?) -> String {
        clock(parseISO(iso) ?? .now)
    }

    /// "Senin, 5 Juli 2026 · pukul 14:30" — full timestamp for a bubble.
    static func fullStamp(time: String?, at: String?) -> String {
        let d = parseISO(at) ?? .now
        let c = Calendar.current.dateComponents([.weekday, .day, .month, .year], from: d)
        let day = idDays[(c.weekday ?? 1) - 1]
        let month = idMonths[(c.month ?? 1) - 1]
        return "\(day), \(c.day ?? 1) \(month) \(c.year ?? 2026) · pukul \(time ?? clock(d))"
    }

    /// Posterum wake-up label: "HH:MM" if today, otherwise "5 Jul · 14:30".
    static func awakenLabel(iso: String?) -> String {
        guard let d = parseISO(iso) else { return "—" }
        if Calendar.current.isDateInToday(d) { return clock(d) }
        let c = Calendar.current.dateComponents([.day, .month], from: d)
        return "\(c.day ?? 1) \(idMonthsShort[(c.month ?? 1) - 1]) · \(clock(d))"
    }
}

// MARK: - Rupiah

nonisolated enum Rupiah {
    static func label(_ amount: Int64?) -> String {
        guard let amount else { return "—" }
        return "Rp " + grouped(amount)
    }

    static func grouped(_ n: Int64) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = "."
        fmt.usesGroupingSeparator = true
        return fmt.string(from: NSNumber(value: n)) ?? String(n)
    }
}
