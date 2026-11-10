# Talpa per iPhone: come installarla (Mac M2, Xcode)

App SwiftUI (iOS 16 o successivo). Tutto gratis con il tuo Apple ID. Con un account gratuito l'app scade dopo 7 giorni: basta ricollegare il telefono e premere Run.

## Cosa fa
- **Stato**: spazio libero reale, batteria (livello, carica, risparmio energetico), modello, RAM, temperatura, cache dell'app con pulsante per svuotarla.
- **Foto**: video più pesanti, screenshot e possibili doppioni, con miniature. Selezioni e elimini (iOS chiede conferma, le foto vanno in «Eliminati di recente»).
- **Contatti**: gruppi con lo stesso nome o numero; elimini quelli che scegli.
- **Guida**: 12 passi da fare in Impostazioni (cache di Safari, app da scaricare, allegati di Messaggi...), con spunte salvate.

Non può (nessuna app può): svuotare le cache di altre app o di Safari, disinstallare resti di app, leggere la salute della batteria in %.

## Creare il progetto in Xcode
1. Xcode › **File › New › Project › iOS › App**.
2. Product Name: `Talpa`. Interface: **SwiftUI**. Language: **Swift**. Storage: None. Crea.
3. Nel navigatore a sinistra elimina `ContentView.swift` (Move to Trash).
4. Sostituisci il contenuto di `TalpaApp.swift` con quello di questo `TalpaApp.swift`.
5. Trascina nel progetto gli altri file: `StatusView.swift`, `PhotosView.swift`, `ContactsView.swift`, `GuideView.swift` (spunta *Copy items if needed* e il target Talpa).

## Permessi (obbligatori, senza l'app si chiude)
Seleziona il progetto › target **Talpa** › scheda **Info** › *Custom iOS Target Properties* › aggiungi due righe (tasto +):
- `Privacy - Photo Library Usage Description` = `Talpa analizza le foto per trovare video pesanti, screenshot e doppioni.`
- `Privacy - Contacts Usage Description` = `Talpa legge la rubrica per trovare i contatti duplicati.`

## Firma e versione
- Scheda **General › Minimum Deployments**: iOS 16.0 (abbassa a 15 solo se il tuo iPhone è più vecchio: va sostituito `NavigationStack` con `NavigationView`).
- Scheda **Signing & Capabilities**: spunta *Automatically manage signing*, scegli il tuo **Team** (Xcode › Settings › Accounts › aggiungi il tuo Apple ID) e cambia il Bundle Identifier in qualcosa di unico, per esempio `it.salvatore.talpa`.

## Installare sul telefono
1. Collega l'iPhone con il cavo e sbloccalo, tocca «Autorizza».
2. Sull'iPhone: **Impostazioni › Privacy e sicurezza › Modalità sviluppatore** › attiva e riavvia.
3. In Xcode scegli il tuo iPhone come destinazione (in alto) e premi **Run** (▶).
4. La prima volta: **Impostazioni › Generali › VPN e gestione dispositivo** › tocca il tuo Apple ID › «Autorizza».

Se Xcode mostra errori di compilazione, copiali qui e li correggo.
