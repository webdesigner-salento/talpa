# Talpa 🐹

Strumenti gratuiti per liberare spazio e tenere in ordine un Mac vecchio.
Ispirato a [Mole](https://github.com/tw93/Mole) di tw93 (GPL-3.0): non ne usa il codice, è scritto da zero.

*English: free tools to clean up an older Mac (macOS Catalina 10.15, pure Bash, no dependencies) and an iPhone (native SwiftUI app). Documentation is in Italian; issues and pull requests in English are welcome.*

| Cartella | Cosa è | Stato |
|---|---|---|
| [`macos/`](macos) | Script a riga di comando per macOS Catalina 10.15.x: `clean`, `uninstall`, `optimize`, `analyze`, `status`, `purge`, `installer`. Bash 3.2, nessuna dipendenza. | Provato su un Mac con Catalina 10.15.8 (`clean --dry-run`). Gli altri comandi sono stati testati solo su Linux con una cartella finta. Usa sempre `--dry-run` per prima cosa. |
|

## Limiti che non si possono superare
- **macOS**: lo script cancella file. Controlla sempre prima con `--dry-run` e tieni un backup di Time Machine.




## Licenza
GPL-3.0, vedi `LICENSE`. Nessuna garanzia: usa il software a tuo rischio.
