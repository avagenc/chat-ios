//
//  chat_iosApp.swift
//  chat-ios
//
//  Entry point: Firebase configuration, Google Sign-In callback,
//  and bundled font registration.
//

import CoreText
import FirebaseCore
import GoogleSignIn
import SwiftUI

// Initialize Firebase at app launch (Firebase's official SwiftUI pattern).
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct chat_iosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        Self.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Google Sign-In callback (REVERSED_CLIENT_ID scheme)
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    /// Register the Newsreader + Inter Tight fonts from the bundle
    /// programmatically — deterministic regardless of where the files land
    /// in the bundle (root or the Fonts/ subfolder).
    private static func registerBundledFonts() {
        var urls: [URL] = []
        for subdir in [nil, "Fonts"] as [String?] {
            urls += Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: subdir) ?? []
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
