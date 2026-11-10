import SwiftUI
import Photos
import UIKit

// MARK: - Modello

struct PhotoItem: Identifiable, @unchecked Sendable {
    let id: String
    let asset: PHAsset
    let size: Int64
}

struct PhotoScanResult: @unchecked Sendable {
    var videos: [PhotoItem] = []
    var screenshots: [PhotoItem] = []
    var duplicateGroups: [[PhotoItem]] = []
}

enum PhotoScanner {
    /// Somma le dimensioni dei file della risorsa. "fileSize" non e' un'API documentata
    /// ma e' l'unico modo di conoscere il peso di un asset; se manca, il peso risulta 0.
    static func fileSize(_ asset: PHAsset) -> Int64 {
        PHAssetResource.assetResources(for: asset).reduce(Int64(0)) { sum, res in
            let n = (res.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
            return sum + n
        }
    }

    static func scan() -> PhotoScanResult {
        var result = PhotoScanResult()

        // Video piu' pesanti
        var videos: [PhotoItem] = []
        PHAsset.fetchAssets(with: .video, options: nil).enumerateObjects { asset, _, _ in
            videos.append(PhotoItem(id: asset.localIdentifier, asset: asset, size: fileSize(asset)))
        }
        videos.sort { $0.size > $1.size }
        result.videos = Array(videos.prefix(60))

        // Screenshot
        let shotOptions = PHFetchOptions()
        shotOptions.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        var shots: [PhotoItem] = []
        PHAsset.fetchAssets(with: .image, options: shotOptions).enumerateObjects { asset, _, _ in
            shots.append(PhotoItem(id: asset.localIdentifier, asset: asset, size: fileSize(asset)))
        }
        shots.sort { $0.size > $1.size }
        result.screenshots = Array(shots.prefix(240))

        // Possibili doppioni: stesso secondo di scatto e stesse dimensioni in pixel
        var buckets: [String: [PHAsset]] = [:]
        PHAsset.fetchAssets(with: .image, options: nil).enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let key = "\(Int(date.timeIntervalSince1970))-\(asset.pixelWidth)x\(asset.pixelHeight)"
            buckets[key, default: []].append(asset)
        }
        var groups: [[PhotoItem]] = []
        for (_, assets) in buckets where assets.count > 1 {
            let items = assets
                .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
                .map { PhotoItem(id: $0.localIdentifier, asset: $0, size: fileSize($0)) }
            groups.append(items)
        }
        groups.sort { $0.reduce(0) { $0 + $1.size } > $1.reduce(0) { $0 + $1.size } }
        result.duplicateGroups = Array(groups.prefix(120))
        return result
    }
}

@MainActor
final class PhotoCleaner: ObservableObject {
    @Published var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var videos: [PhotoItem] = []
    @Published var screenshots: [PhotoItem] = []
    @Published var duplicateGroups: [[PhotoItem]] = []
    @Published var loading = false
    @Published var selected = Set<String>()
    @Published var message: String?

    var allowed: Bool { status == .authorized || status == .limited }

    func refreshStatus() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func request() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if allowed { await scan() }
    }

    func scan() async {
        loading = true
        let result = await Task.detached(priority: .userInitiated) { PhotoScanner.scan() }.value
        videos = result.videos
        screenshots = result.screenshots
        duplicateGroups = result.duplicateGroups
        selected.removeAll()
        loading = false
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// In ogni gruppo di doppioni seleziona tutto tranne la prima foto (la piu' vecchia).
    func selectAllButFirst() {
        selected.removeAll()
        for group in duplicateGroups {
            for item in group.dropFirst() { selected.insert(item.id) }
        }
    }

    func delete(_ items: [PhotoItem]) async {
        let assets = items.map { $0.asset }
        guard !assets.isEmpty else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            message = "Eliminati \(assets.count) elementi. Li trovi in «Eliminati di recente»."
            await scan()
        } catch {
            message = "Eliminazione annullata."
        }
    }
}

// MARK: - Vista

struct PhotosView: View {
    @StateObject private var model = PhotoCleaner()
    @State private var tab = 0
    @State private var confirm = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    private var currentItems: [PhotoItem] {
        switch tab {
        case 0: return model.videos
        case 1: return model.screenshots
        default: return model.duplicateGroups.flatMap { $0 }
        }
    }

    private var selectedItems: [PhotoItem] {
        currentItems.filter { model.selected.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.allowed {
                    content
                } else if model.status == .notDetermined {
                    prompt
                } else {
                    denied
                }
            }
            .navigationTitle("Foto")
            .toolbar {
                if model.allowed {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { Task { await model.scan() } } label: { Image(systemName: "arrow.clockwise") }
                            .disabled(model.loading)
                    }
                }
            }
        }
        .task {
            model.refreshStatus()
            if model.allowed { await model.scan() }
        }
    }

    // Contenuto principale

    private var content: some View {
        VStack(spacing: 0) {
            Picker("Categoria", selection: $tab) {
                Text("Video").tag(0)
                Text("Screenshot").tag(1)
                Text("Doppioni").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: tab) { _ in model.selected.removeAll() }

            if model.status == .limited {
                Text("Accesso limitato: vedo solo le foto che hai scelto. Cambialo in Impostazioni › Talpa › Foto.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if model.loading {
                Spacer()
                ProgressView("Analisi della libreria…")
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let note = tabNote { Text(note).font(.footnote).foregroundStyle(.secondary).padding(.horizontal) }
                        if currentItems.isEmpty {
                            Text("Niente da mostrare in questa categoria.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if tab == 2 {
                            duplicates
                        } else {
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(tab == 0 ? model.videos : model.screenshots) { item in
                                    cell(item)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }

            bottomBar
        }
    }

    private var tabNote: String? {
        switch tab {
        case 0: return "I video più pesanti, dal più grande. Tocca per selezionare."
        case 1: return "Gli screenshot, dal più pesante."
        default: return "Foto scattate nello stesso secondo e con le stesse dimensioni. Possono essere raffiche o copie: controlla prima di eliminare."
        }
    }

    private var duplicates: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Seleziona i doppioni (tieni la prima di ogni gruppo)") { model.selectAllButFirst() }
                .padding(.horizontal)
            ForEach(model.duplicateGroups.indices, id: \.self) { index in
                let group = model.duplicateGroups[index]
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gruppo \(index + 1) · \(group.count) foto")
                        .font(.footnote.bold())
                        .padding(.horizontal)
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(group) { item in cell(item) }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func cell(_ item: PhotoItem) -> some View {
        PhotoCell(item: item, selected: model.selected.contains(item.id))
            .onTapGesture { model.toggle(item.id) }
    }

    private var bottomBar: some View {
        let chosen = selectedItems
        let bytes = chosen.reduce(Int64(0)) { $0 + $1.size }
        return VStack(spacing: 6) {
            if let message = model.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            Button {
                confirm = true
            } label: {
                Text(chosen.isEmpty ? "Seleziona cosa eliminare" : "Elimina \(chosen.count) · \(formatBytes(bytes))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(chosen.isEmpty)
            .confirmationDialog("Eliminare \(chosen.count) elementi?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) {
                    model.message = nil
                    Task { await model.delete(chosen) }
                }
            } message: {
                Text("Andranno in «Eliminati di recente» per 30 giorni. Lo spazio si libera quando svuoti quell'album.")
            }
        }
        .padding()
        .background(.bar)
    }

    // Permessi

    private var prompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Talpa deve vedere la libreria per trovare video pesanti, screenshot e doppioni. Le foto restano sul telefono: non vengono inviate da nessuna parte.")
                .multilineTextAlignment(.center)
            Button("Consenti l'accesso") { Task { await model.request() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }

    private var denied: some View {
        VStack(spacing: 16) {
            Text("Senza accesso alle foto non posso analizzarle. Puoi consentirlo da Impostazioni › Talpa › Foto.")
                .multilineTextAlignment(.center)
            Button("Apri Impostazioni") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

// MARK: - Celle e miniature

struct PhotoCell: View {
    let item: PhotoItem
    let selected: Bool

    var body: some View {
        ZStack {
            Thumb(asset: item.asset)
            if selected { Color.accentColor.opacity(0.35) }
            VStack {
                HStack {
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.title3)
                            .padding(4)
                    }
                }
                Spacer()
                HStack {
                    Text(formatBytes(item.size))
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                    Spacer()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
    }
}

struct Thumb: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.gray.opacity(0.2)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear(perform: load)
    }

    private func load() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 240, height: 240),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result { image = result }
        }
    }
}
