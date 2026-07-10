//
//  TopupSheet.swift
//  chat-ios
//
//  Balance top-up. The Midtrans payment flow is a stub (backend endpoint
//  not yet active) → ends in an info alert.
//

import SwiftUI

struct TopupSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    private static let presets: [Int64] = [50000, 100_000, 200_000, 500_000]

    @State private var preset: Int64?
    @State private var custom = ""
    @State private var showMidtransInfo = false

    private var rawCustom: Int64 {
        Int64(custom.filter(\.isNumber)) ?? 0
    }

    private var amount: Int64 {
        preset ?? rawCustom
    }

    private var canPay: Bool {
        amount >= 10000
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        balanceCard
                        presetGrid
                        customField
                        if canPay {
                            summary
                        }
                        warnings
                        proceedButton
                        note
                    }
                    .padding(.horizontal, Theme.sidePadding)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Isi Ulang Saldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Isi Ulang Saldo")
                        .font(.serif(19, .medium))
                        .foregroundStyle(Theme.ink)
                }
            }
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .alert("Integrasi Midtrans", isPresented: $showMidtransInfo) {
            Button("Tutup", role: .cancel) {}
        } message: {
            Text("Tepat di sini kami berencana menggunakan Midtrans, untuk memungkinkan pengguna mengisi saldo token Avagenc.")
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 6) {
            Text("Saldo saat ini")
                .font(.sans(12))
                .foregroundStyle(Theme.inkMuted)
            Text(session.wallet.balanceLabel)
                .font(.serif(32, .medium))
                .foregroundStyle(Theme.ink)
            Text("tersedia")
                .font(.sans(10.5, .semibold))
                .foregroundStyle(Theme.success)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Theme.success.opacity(0.1))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            ForEach(Self.presets, id: \.self) { value in
                Button {
                    preset = value
                    custom = ""
                } label: {
                    Text(Rupiah.label(value))
                        .font(.sans(14, .medium))
                        .foregroundStyle(preset == value ? Theme.accentDeep : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(preset == value ? Theme.accentTint : Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    preset == value ? Theme.accent : Theme.lineStrong, lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customField: some View {
        HStack(spacing: 8) {
            Text("Rp")
                .font(.sans(14, .semibold))
                .foregroundStyle(Theme.inkMuted)
            TextField("Nominal lain…", text: $custom)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
                .tint(Theme.accent)
                .keyboardType(.numberPad)
                .onChange(of: custom) { _, value in
                    let digits = value.filter(\.isNumber)
                    let formatted = digits.isEmpty ? "" : Rupiah.grouped(Int64(digits) ?? 0)
                    if formatted != custom { custom = formatted }
                    if !digits.isEmpty { preset = nil }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.lineStrong, lineWidth: 1)
        )
    }

    private var summary: some View {
        Text("Kamu akan menambahkan \(Text(Rupiah.label(amount)).font(.sans(13, .semibold))) ke saldo Avagenc.")
            .font(.sans(13))
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.accentTint)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 9) {
            warningItem("Jangan lakukan pembayaran yang sama **dua kali**. Setiap transaksi memiliki ID unik — bayar hanya sekali.")
            warningItem("Link pembayaran Midtrans berlaku **24 jam**. Jika kedaluwarsa, buat transaksi baru.")
            warningItem("Saldo masuk otomatis **1–5 menit** setelah pembayaran dikonfirmasi Midtrans.")
            warningItem("Minimal isi ulang **Rp 10.000**.")
        }
    }

    private func warningItem(_ markdown: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(.init(markdown))
                .font(.sans(12.5))
                .foregroundStyle(Theme.inkMuted)
                .lineSpacing(3)
        }
    }

    private var proceedButton: some View {
        Button {
            showMidtransInfo = true
        } label: {
            HStack(spacing: 6) {
                Text(canPay ? "Lanjut ke Pembayaran — \(Rupiah.label(amount))" : "Pilih nominal isi ulang")
                    .font(.sans(15, .semibold))
                if canPay {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(canPay ? .white : Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canPay ? Theme.accent : Theme.bgSunk)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .disabled(!canPay)
        .animation(.avagencEase, value: canPay)
    }

    private var note: some View {
        Text(.init("Pembayaran diproses oleh **Midtrans** — platform pembayaran terpercaya di Indonesia."))
            .font(.sans(11.5))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
}
