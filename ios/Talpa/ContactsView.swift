import SwiftUI
import Contacts
import UIKit

// MARK: - Modello

enum ContactScanner {
    static func scan() -> [[CNContact]] {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        var all: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        try? store.enumerateContacts(with: request) { contact, _ in all.append(contact) }

        var used = Set<String>()
        var groups: [[CNContact]] = []

        func add(_ dict: [String: [CNContact]]) {
            for (_, members) in dict.sorted(by: { $0.key < $1.key }) {
                var seen = Set<String>()
                let fresh = members.filter { !used.contains($0.identifier) && seen.insert($0.identifier).inserted }
                if fresh.count > 1 {
                    groups.append(fresh)
                    fresh.forEach { used.insert($0.identifier) }
                }
            }
        }

        var byName: [String: [CNContact]] = [:]
        for contact in all {
            let name = "\(contact.givenName) \(contact.familyName)"
                .lowercased()
                .trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { byName[name, default: []].append(contact) }
        }
        add(byName)

        var byPhone: [String: [CNContact]] = [:]
        for contact in all {
            for phone in contact.phoneNumbers {
                let digits = phone.value.stringValue.filter { $0.isNumber }
                if digits.count >= 7 { byPhone[String(digits.suffix(9)), default: []].append(contact) }
            }
        }
        add(byPhone)
        return groups
    }
}

@MainActor
final class ContactCleaner: ObservableObject {
    @Published var status = CNContactStore.authorizationStatus(for: .contacts)
    @Published var groups: [[CNContact]] = []
    @Published var selected = Set<String>()
    @Published var loading = false
    @Published var message: String?

    func refreshStatus() {
        status = CNContactStore.authorizationStatus(for: .contacts)
    }

    func request() async {
        _ = try? await CNContactStore().requestAccess(for: .contacts)
        refreshStatus()
        if status == .authorized { await load() }
    }

    func load() async {
        loading = true
        let found = await Task.detached(priority: .userInitiated) { ContactScanner.scan() }.value
        groups = found
        selected.removeAll()
        loading = false
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    func deleteSelected() async {
        let toDelete = groups.flatMap { $0 }.filter { selected.contains($0.identifier) }
        guard !toDelete.isEmpty else { return }
        let request = CNSaveRequest()
        for contact in toDelete {
            if let mutable = contact.mutableCopy() as? CNMutableContact { request.delete(mutable) }
        }
        do {
            try CNContactStore().execute(request)
            message = "Eliminati \(toDelete.count) contatti."
            await load()
        } catch {
            message = "Non sono riuscito a eliminarli."
        }
    }
}

// MARK: - Vista

struct ContactsView: View {
    @StateObject private var model = ContactCleaner()
    @State private var confirm = false

    var body: some View {
        NavigationStack {
            Group {
                if model.status == .authorized {
                    list
                } else if model.status == .notDetermined {
                    prompt
                } else {
                    denied
                }
            }
            .navigationTitle("Contatti")
        }
        .task {
            model.refreshStatus()
            if model.status == .authorized { await model.load() }
        }
    }

    private var list: some View {
        List {
            Section {
                Text("Contatti con lo stesso nome o lo stesso numero. Scegli quelli da eliminare: l'eliminazione non si può annullare. Per unire due schede senza perdere dati, usa «Trovati duplicati» nell'app Contatti di iOS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if model.loading {
                ProgressView("Analisi dei contatti…")
            } else if model.groups.isEmpty {
                Text("Nessun duplicato evidente.").foregroundStyle(.secondary)
            }
            ForEach(model.groups.indices, id: \.self) { index in
                Section("Gruppo \(index + 1)") {
                    ForEach(model.groups[index], id: \.identifier) { contact in
                        Button { model.toggle(contact.identifier) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: model.selected.contains(contact.identifier) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName(contact)).foregroundColor(.primary)
                                    let details = detailsText(contact)
                                    if !details.isEmpty {
                                        Text(details).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if let message = model.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
                Button {
                    confirm = true
                } label: {
                    Text(model.selected.isEmpty ? "Seleziona i contatti da eliminare" : "Elimina \(model.selected.count) contatti")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.selected.isEmpty)
                .confirmationDialog("Eliminare \(model.selected.count) contatti?", isPresented: $confirm, titleVisibility: .visible) {
                    Button("Elimina", role: .destructive) {
                        model.message = nil
                        Task { await model.deleteSelected() }
                    }
                } message: {
                    Text("Non potrai annullare.")
                }
            }
            .padding()
            .background(.bar)
        }
    }

    private func displayName(_ contact: CNContact) -> String {
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        return contact.organizationName.isEmpty ? "Senza nome" : contact.organizationName
    }

    private func detailsText(_ contact: CNContact) -> String {
        let phones = contact.phoneNumbers.map { $0.value.stringValue }
        let mails = contact.emailAddresses.map { String($0.value) }
        return (phones + mails).joined(separator: " · ")
    }

    private var prompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.crop.square.stack").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Talpa deve leggere la rubrica per trovare i duplicati. I dati restano sul telefono.")
                .multilineTextAlignment(.center)
            Button("Consenti l'accesso") { Task { await model.request() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }

    private var denied: some View {
        VStack(spacing: 16) {
            Text("Senza accesso ai contatti non posso analizzarli. Puoi consentirlo da Impostazioni › Talpa › Contatti.")
                .multilineTextAlignment(.center)
            Button("Apri Impostazioni") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}
