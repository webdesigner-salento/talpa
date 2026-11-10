import SwiftUI

struct GuideStep: Identifiable {
    let id: String
    let title: String
    let path: String
    let detail: String
    let high: Bool
}

struct GuideView: View {
    @AppStorage("talpa.doneSteps") private var doneRaw = ""

    private let steps: [GuideStep] = [
        GuideStep(id: "spazio", title: "Guarda cosa occupa spazio",
                  path: "Impostazioni › Generali › Spazio iPhone",
                  detail: "Aspetta qualche secondo: iOS ordina le app dalla più pesante e propone consigli.", high: true),
        GuideStep(id: "eliminati", title: "Svuota «Eliminati di recente» in Foto",
                  path: "Foto › Album › Eliminati di recente › Seleziona › Elimina tutto",
                  detail: "Quello che elimini con Talpa finisce qui e occupa spazio finché non lo svuoti.", high: true),
        GuideStep(id: "scarica", title: "Scarica le app che non usi",
                  path: "Spazio iPhone › (app) › Scarica app",
                  detail: "Toglie l'app e conserva i dati: reinstallandola è come l'avevi lasciata.", high: true),
        GuideStep(id: "ottimizza", title: "Ottimizza le foto con iCloud",
                  path: "Impostazioni › Foto › Ottimizza spazio su iPhone",
                  detail: "Sul telefono restano le versioni leggere, gli originali stanno in iCloud.", high: true),
        GuideStep(id: "update", title: "Cancella un aggiornamento iOS già scaricato",
                  path: "Spazio iPhone › Aggiornamento iOS › Elimina aggiornamento",
                  detail: "Compare solo se iOS ha scaricato un aggiornamento che non hai installato.", high: false),
        GuideStep(id: "messaggi", title: "Rivedi gli allegati grandi di Messaggi",
                  path: "Spazio iPhone › Messaggi › Rivedi allegati grandi",
                  detail: "Elimina foto e video ricevuti in chat senza cancellare le conversazioni.", high: false),
        GuideStep(id: "musica", title: "Togli musica e podcast scaricati",
                  path: "Spazio iPhone › Musica › Modifica",
                  detail: "Tieni solo quello che ascolti offline.", high: false),
        GuideStep(id: "safari", title: "Cancella cronologia e dati dei siti di Safari",
                  path: "Impostazioni › Safari › Cancella dati siti web e cronologia",
                  detail: "Con iOS 18 il percorso è Impostazioni › App › Safari. Ti disconnette dai siti.", high: false),
        GuideStep(id: "docdati", title: "Controlla «Documenti e dati» delle app",
                  path: "Spazio iPhone › (app) › Documenti e dati",
                  detail: "Se superano molto la dimensione dell'app, eliminala e reinstallala (salva prima ciò che serve).", high: false),
        GuideStep(id: "file", title: "Svuota «Eliminati di recente» in File",
                  path: "File › Sfoglia › Eliminati di recente",
                  detail: "Come per le foto, resta 30 giorni.", high: false),
        GuideStep(id: "batteria", title: "Controlla la salute della batteria",
                  path: "Impostazioni › Batteria › Stato batteria",
                  detail: "Sotto l'80% di capacità massima conviene valutare la sostituzione.", high: false),
        GuideStep(id: "riavvio", title: "Riavvia l'iPhone",
                  path: "Tasto laterale + volume › Spegni",
                  detail: "Non libera spazio su disco, ma svuota la memoria e le cache temporanee.", high: false)
    ]

    private var done: Set<String> {
        Set(doneRaw.split(separator: ",").map(String.init))
    }

    private func toggle(_ id: String) {
        var current = done
        if current.contains(id) { current.remove(id) } else { current.insert(id) }
        doneRaw = current.sorted().joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProgressView(value: Double(done.count), total: Double(steps.count))
                    Text("\(done.count) di \(steps.count) passi completati")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Su iPhone nessuna app può svuotare le cache delle altre app: queste operazioni si fanno a mano dalle Impostazioni.")
                }
                Section {
                    ForEach(steps) { step in
                        Button { toggle(step.id) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: done.contains(step.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.tint)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(step.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(done.contains(step.id) ? .secondary : .primary)
                                            .strikethrough(done.contains(step.id))
                                        if step.high {
                                            Text("ALTO IMPATTO")
                                                .font(.caption2.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(step.path)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Text(step.detail)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Guida")
        }
    }
}
