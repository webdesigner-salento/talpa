# Talpa 🐹 — manutenzione per macOS Catalina (10.15.8)

Riscrittura in **Bash 3.2 puro** dell'idea di [Mole](https://github.com/tw93/Mole), pensata per i Mac fermi a Catalina.
Nessuna dipendenza: niente Go, niente Homebrew, solo gli strumenti già presenti in macOS 10.15.

> Non è una copia del codice di Mole: è scritto da zero, con le stesse idee. Mole è GPL‑3.0, quindi Talpa usa la stessa licenza.

## Installazione

Nel Terminale, dalla cartella che contiene questi file:

```
chmod +x install.sh talpa
./install.sh
```

Se lo script dice che la cartella non è nel `PATH`, aggiungi la riga indicata a `~/.zshrc` e riapri il Terminale.
Senza installare, puoi anche lanciarlo direttamente: `./talpa --help`.

**Importante su Catalina:** per leggere Cestino, Mail e Safari, dai al Terminale il *Controllo completo del disco*
(Preferenze di Sistema → Sicurezza e privacy → Privacy → Controllo completo del disco → aggiungi Terminale).

## Uso

```
talpa                    # menu interattivo
talpa clean --dry-run    # mostra cosa verrebbe pulito, senza toccare nulla
talpa clean              # pulizia vera (chiede conferma)
talpa uninstall          # disinstalla app + resti (nel Cestino)
talpa optimize           # DNS, Quick Look, icone Dock, purge memoria, periodic
talpa analyze ~/         # esplora lo spazio su disco
talpa status --watch     # cruscotto live
talpa purge              # node_modules, target, build, dist, Pods
talpa installer          # dmg/pkg/iso/xip scaricati
talpa whitelist          # percorsi protetti
talpa history            # registro delle operazioni
```

Fai sempre prima una prova con `--dry-run`.

## Cosa fa e cosa no

| Comando | Cosa fa |
|---|---|
| `clean` | Cache utente (esclusi i componenti Apple di sistema), log, Cestino, DerivedData di Xcode, cache npm, aggiornamenti iOS scaricati, allegati Mail. Salta le cache di Safari/Chrome/Firefox se il browser è aperto. |
| `uninstall` | Elenca le app di terze parti, trova l'identificativo e sposta nel Cestino l'app e i resti in `~/Library`. Le app Apple sono escluse. |
| `optimize` | Svuota DNS, aggiorna Quick Look, ricostruisce la cache icone del Dock, `purge`, `periodic`. Con `--deep` ricostruisce Launch Services. |
| `analyze` | Esploratore a riga di comando: entri nelle cartelle, vedi i file oltre 200 MB, sposti nel Cestino. |
| `status` | CPU, memoria, disco (volume Data di Catalina), rete, batteria, processi, zombie, punteggio di salute. |
| `purge` | Cerca artefatti ricostruibili nei tuoi progetti; quelli toccati negli ultimi 7 giorni sono segnalati. |
| `installer` | Trova installer in Download, Scrivania e cache Homebrew. |

**Non implementato** rispetto a Mole: pulizia automatica dei resti di app già disinstallate, Touch ID per sudo,
aggiornamento automatico, output JSON, avvio rapido Raycast/Alfred. Sono scelte volute: erano le parti più rischiose o inutili su Catalina.

## Sicurezza

- Ogni cancellazione passa da un controllo dei percorsi: sono rifiutati `/`, la tua home, `~/Library`, Documenti, Scrivania, Download, `/System`, `/usr`, `/Applications` (la cartella stessa) e tutto ciò che non sta sotto la tua home, `/Applications`, `/Library/Caches` o `/Library/Logs`.
- App e installer vanno nel **Cestino**; solo cache, log e artefatti di progetto sono cancellati in modo definitivo.
- Lista bianca in `~/.config/talpa/whitelist` (un percorso o pattern per riga).
- Operazioni registrate in `~/Library/Logs/talpa/operations.log`.

## Disinstallare Talpa

`talpa remove`, oppure cancella `talpa` dalla cartella di installazione e `~/.config/talpa`.
