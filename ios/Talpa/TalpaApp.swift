import SwiftUI

@main
struct TalpaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Stato", systemImage: "gauge") }
            PhotosView()
                .tabItem { Label("Foto", systemImage: "photo.on.rectangle") }
            ContactsView()
                .tabItem { Label("Contatti", systemImage: "person.2") }
            GuideView()
                .tabItem { Label("Guida", systemImage: "checklist") }
        }
        .tint(Color(red: 0.79, green: 0.23, blue: 0.42))
    }
}

func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
