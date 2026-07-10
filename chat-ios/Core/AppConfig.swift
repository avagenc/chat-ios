//
//  AppConfig.swift
//  chat-ios
//
//  Deployment configuration — one place for every per-environment value.
//

import Foundation

enum AppConfig {
    /// Avagenc Chat backend base URL. No trailing slash.
    static let apiBase = "https://chat-http-409829581223.asia-southeast1.run.app"

    // Firebase is configured from GoogleService-Info.plist in the target —
    // the API key, client ID, and Google Sign-In callback scheme come from
    // there (the REVERSED_CLIENT_ID scheme is also registered in Info.plist).

    /// Web app origin — used for legal page links (/legal).
    static let webAppURL = "https://chat.dev.avagenc.com"

    /// This app's custom URL scheme (registered in Info.plist) — used for
    /// integration-linking callbacks once the backend supports mobile redirects.
    static let linkCallbackScheme = "avagenc-chat"
}
