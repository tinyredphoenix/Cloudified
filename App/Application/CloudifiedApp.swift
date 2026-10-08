import SwiftUI
import UIKit

@main
struct CloudifiedApp: App {
    @StateObject private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootTabView(environment: environment)
                .onAppear { environment.onMemoryPressure = { RowThumbnailLoader.clearCache() } }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in environment.memoryWarning() }
                .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in environment.resourcePressureChanged() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: environment.applicationActive()
            case .background: environment.applicationBackgrounded()
            case .inactive: break
            @unknown default: break
            }
        }
    }
}
