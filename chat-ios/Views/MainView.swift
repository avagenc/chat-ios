//
//  MainView.swift
//  chat-ios
//
//  Main shell after login: wordmark (leading) → push ChatInfoScreen;
//  hourglass + badge (trailing) → Postera sheet; profile avatar (trailing)
//  → Profile sheet.
//

import SwiftUI

struct MainView: View {
    @Environment(SessionStore.self) private var session

    @State private var showProfile = false
    @State private var showPostera = false
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            ChatScreen()
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Theme.bg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    // wordmark: [ink logo] Avagenc CHAT → info page
                    ToolbarItem(placement: .topBarLeading) {
                        if !session.searchActive {
                            Button {
                                navPath.append(Destination.info)
                            } label: {
                                HStack(spacing: 6) {
                                    LogoView(size: 17, variant: .ink)
                                    Text("Avagenc")
                                        .font(.serif(16, .medium))
                                        .foregroundStyle(Theme.ink)
                                    Text("CHAT")
                                        .font(.sans(9.5, .semibold))
                                        .kerning(0.6)
                                        .foregroundStyle(Theme.accentDeep)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.accentTint)
                                        .clipShape(Capsule())
                                }
                                .fixedSize()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if !session.searchActive {
                            Button {
                                showPostera = true
                            } label: {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.inkSoft)
                                    .frame(width: 34, height: 34)
                                    .overlay(alignment: .topTrailing) {
                                        if !session.postera.list.isEmpty {
                                            Text("\(session.postera.list.count)")
                                                .font(.sans(9.5, .semibold))
                                                .foregroundStyle(.white)
                                                .frame(minWidth: 16, minHeight: 16)
                                                .background(Circle().fill(Theme.ava))
                                                .offset(x: 2, y: -1)
                                        }
                                    }
                            }
                            .accessibilityLabel("Postera Ava")

                            Button {
                                showProfile = true
                            } label: {
                                ProfileAvatar(initial: session.profile.initial, size: 30)
                            }
                            .accessibilityLabel("Profil")
                        }
                    }
                }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .info:
                        ChatInfoScreen(
                            onSearch: {
                                navPath.removeLast(navPath.count)
                                withAnimation(.avagencEase) { session.openSearch() }
                            }
                        )
                    }
                }
        }
        .tint(Theme.accentDeep)
        .sheet(isPresented: $showProfile) {
            ProfileSheet()
        }
        .sheet(isPresented: $showPostera) {
            PosteraSheet()
        }
        #if DEBUG
        // Test automation: `-openScreen profile|postera|info|search`
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-openScreen"), args.indices.contains(i + 1) else {
                return
            }
            switch args[i + 1] {
            case "profile": showProfile = true
            case "postera": showPostera = true
            case "info": navPath.append(Destination.info)
            case "search": session.openSearch()
            default: break
            }
        }
        #endif
    }

    enum Destination: Hashable {
        case info
    }
}
