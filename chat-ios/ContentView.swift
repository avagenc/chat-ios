//
//  ContentView.swift
//  chat-ios
//
//  Root — auth gate (Login vs Main) + global toast.
//

import SwiftUI

struct ContentView: View {
    @State private var session = SessionStore()

    var body: some View {
        ZStack {
            #if DEBUG
            // Test automation: `-previewThinking` renders the thinking
            // indicator standalone (no session), so its animation can be
            // screenshot-verified without signing in.
            if ProcessInfo.processInfo.arguments.contains("-previewThinking") {
                Theme.bg.ignoresSafeArea()
                ThinkingRow()
                    .padding(.horizontal, Theme.sidePadding)
            } else {
                authGate
            }
            #else
            authGate
            #endif

            // toast lives outside the auth gate so login errors show too
            if let toast = session.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast)
                        .padding(.bottom, 90)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
            }
        }
        .animation(.avagencEase, value: session.toast)
        .animation(.avagencEase, value: session.auth.authed)
        .onChange(of: session.auth.authed) { _, authed in
            // login (interactive or async session restore) → load initial data
            if authed { session.bootstrap() }
        }
        .environment(session)
        .preferredColorScheme(.light) // single warm-cream theme — no dark mode
    }

    @ViewBuilder
    private var authGate: some View {
        if !session.auth.ready {
            // session still being restored: hold rendering so Login never flashes
            Theme.bg.ignoresSafeArea()
        } else if !session.auth.authed {
            LoginView()
        } else {
            MainView()
        }
    }
}

#Preview {
    ContentView()
}
