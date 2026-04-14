import SwiftUI

@main
struct GlamProApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var appBootstrap = AppBootstrapStore()
    @StateObject private var previewGenerationStore = PreviewGenerationStore()
    @StateObject private var savedTemplatesStore = SavedTemplatesStore()
    @StateObject private var likedTemplatesStore = LikedTemplatesStore()

    init() {
        GlamMediaCacheBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(sessionManager)
                .environmentObject(appBootstrap)
                .environmentObject(previewGenerationStore)
                .environmentObject(savedTemplatesStore)
                .environmentObject(likedTemplatesStore)
                .preferredColorScheme(.dark)
        }
    }
}
