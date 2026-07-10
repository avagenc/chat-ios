//
//  AppConfig.swift
//  chat-ios
//
//  Deployment configuration — one place for every per-environment value.
//  Values are injected at build time from Config/{Dev,Prod}.xcconfig
//  (Debug → Dev, Release → Prod) through Info.plist.
//

import Foundation

enum AppConfig {
    /// Avagenc Chat backend base URL. No trailing slash.
    static let apiBase = infoString("APIBaseURL")

    /// Web app origin — used for legal page links (/legal).
    static let webAppURL = infoString("WebAppURL")

    // Firebase is configured from GoogleService-Info.plist in the target —
    // the API key, client ID, and Google Sign-In callback scheme come from
    // there (the REVERSED_CLIENT_ID scheme is also registered in Info.plist).

    /// This app's custom URL scheme (registered in Info.plist) — used for
    /// integration-linking callbacks once the backend supports mobile redirects.
    static let linkCallbackScheme = "avagenc-chat"

    /// A missing key means broken xcconfig wiring — fail fast at first access.
    private static func infoString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            fatalError("Info.plist is missing \(key) — check Config/*.xcconfig")
        }
        return value
    }
}
