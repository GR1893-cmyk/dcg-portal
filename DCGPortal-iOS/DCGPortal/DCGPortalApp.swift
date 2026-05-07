import SwiftUI

@main
struct DCGPortalApp: App {
    var body: some Scene {
        WindowGroup {
            PortalWebView()
                .ignoresSafeArea()
        }
    }
}
