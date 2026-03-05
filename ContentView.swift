import SwiftUI
import Combine
import SwiftData

// Minimal Activity model used by SearchView
struct Activity: Identifiable, Hashable {
    let id = UUID()
    let title: String
}

// MARK: - SwiftData Model
@Model
class Points {

    var total: Int
    var screenTimeBalanceMinutes: Int
    
    init(total: Int = 0, screenTimeBalanceMinutes: Int = 0) {

        self.total = total
        self.screenTimeBalanceMinutes = screenTimeBalanceMinutes
    }
}

// MARK: - Main App
@main
struct RewardsScreen: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Attach SwiftData container
        .modelContainer(for: Points.self)
    }
}

// TabView enums
enum Tabs {
    case home
    case activities
    case rewards
    case settings
    case search
    }

struct ContentView: View {
    
    
    @State private var searchText: String = ""
    @AppStorage("appThemeName") private var appThemeName: String = "Default"
    
    //MARK: TabView
    var body: some View {

        TabView {
            
            // Home Tab
            Tab("Home", systemImage: "house") {
                HomeTab()
            }

            // Activities Tab
            Tab("Activities", systemImage: "figure.run.square.stack.fill") {
                ActivitiesTab()
            }

            // Rewards Tab
            Tab("Rewards", systemImage: "medal.fill") {
                RewardsTab()
            }

            // Settings Tab
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }

        }
        .tint(appThemeName == "Cosmic Orange" ? .orange : .indigo)
    }
}


#Preview {
    ContentView()
}

