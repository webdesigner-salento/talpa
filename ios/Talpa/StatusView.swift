import SwiftUI
import UIKit

// MARK: - Letture di sistema

struct DiskInfo {
    let free: Int64
    let total: Int64
}

func readDisk() -> DiskInfo? {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
    guard let values = try? url.resourceValues(forKeys: keys),
          let free = values.volumeAvailableCapacityForImportantUsage,
          let total = values.volumeTotalCapacity else { return nil }
    return DiskInfo(free: free, total: Int64(total))
}

func machineIdentifier() -> String {
    var info = utsname()
    uname(&info)
    return withUnsafePointer(to: &info.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
}

func directorySize(_ url: URL) -> Int64 {
    let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey]
    guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: []) else { return 0 }
    var total: Int64 = 0
    for case let file as URL in enumerator {
        let size = (try? file.resourceValues(forKeys: Set(keys)))?.totalFileAllocatedSize ?? 0
        total += Int64(size)
    }
    return total
}

func ownCacheBytes() -> Int64 {
    let fm = FileManager.default
    let dirs: [URL?] = [fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
                        URL(fileURLWithPath: NSTemporaryDirectory())]
    return dirs.compactMap { $0 }.reduce(Int64(0)) { $0 + directorySize($1) }
}

func clearOwnCache() {
    let fm = FileManager.default
    let dirs: [URL?] = [fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
                        URL(fileURLWithPath: NSTemporaryDirectory())]
    for dir in dirs.compactMap({ $0 }) {
        let items = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for item in items { try? fm.removeItem(at: item) }
    }
    URLCache.shared.removeAllCachedResponses()
}

// MARK: - Vista

struct StatusView: View {
    @State private var free: Int64 = 0
    @State private var total: Int64 = 0
    @State private var cacheSize: Int64 = 0
    @State private var batteryLevel: Float = -1
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @State private var lowPower = false
    @State private var thermal: ProcessInfo.ThermalState = .nominal
    @State private var cleaned = false

    private var usedFraction: Double {
        total > 0 ? Double(total - free) / Double(total) : 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Spazio") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatBytes(free))
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                        Text("liberi su \(formatBytes(total))")
                            .foregroundStyle(.secondary)
                        ProgressView(value: usedFraction)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    LabeledContent("Livello", value: batteryLevel < 0 ? "non disponibile" : "\(Int(batteryLevel * 100))%")
                    LabeledContent("Stato", value: batteryStateText)
                    LabeledContent("Risparmio energetico", value: lowPower ? "Attivo" : "Disattivo")
                } header: {
                    Text("Batteria")
                } footer: {
                    Text("La salute della batteria in percentuale si legge solo in Impostazioni › Batteria › Stato batteria: iOS non la rende disponibile alle app.")
                }

                Section("Sistema") {
                    LabeledContent("Modello", value: machineIdentifier())
                    LabeledContent("iOS", value: UIDevice.current.systemVersion)
                    LabeledContent("Memoria RAM", value: formatBytes(Int64(ProcessInfo.processInfo.physicalMemory)))
                    LabeledContent("Temperatura", value: thermalText)
                    LabeledContent("Acceso da", value: uptimeText)
                }

                Section {
                    LabeledContent("Cache di Talpa", value: formatBytes(cacheSize))
                    Button(cleaned ? "Cache svuotata" : "Svuota la cache di Talpa") {
                        clearOwnCache()
                        cleaned = true
                        Task { await refresh() }
                    }
                } header: {
                    Text("Questa app")
                } footer: {
                    Text("iOS non permette di svuotare le cache delle altre app. Per quelle usa la scheda Guida.")
                }
            }
            .navigationTitle("Talpa")
            .refreshable { await refresh() }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        if let disk = readDisk() {
            free = disk.free
            total = disk.total
        }
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        batteryLevel = device.batteryLevel
        batteryState = device.batteryState
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermal = ProcessInfo.processInfo.thermalState
        cacheSize = await Task.detached { ownCacheBytes() }.value
    }

    private var batteryStateText: String {
        switch batteryState {
        case .charging: return "In carica"
        case .full: return "Carica"
        case .unplugged: return "Non in carica"
        default: return "Sconosciuto"
        }
    }

    private var thermalText: String {
        switch thermal {
        case .nominal: return "Normale"
        case .fair: return "Leggermente caldo"
        case .serious: return "Caldo"
        case .critical: return "Critico"
        @unknown default: return "Sconosciuta"
        }
    }

    private var uptimeText: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        return days > 0 ? "\(days) g \(hours) h" : "\(hours) h \((seconds % 3_600) / 60) min"
    }
}
