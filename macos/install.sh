#!/bin/bash
# Installa Talpa copiando lo script "talpa" accanto a questo file in una cartella nel PATH.
# Uso:  ./install.sh              (prova /usr/local/bin, poi ~/.local/bin)
#       ./install.sh ~/bin        (cartella a scelta)

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SRC_DIR/talpa"

[ -f "$SRC" ] || { echo "File 'talpa' non trovato accanto a install.sh"; exit 1; }
bash -n "$SRC" || { echo "Lo script contiene errori di sintassi."; exit 1; }

if [ -n "$1" ]; then
  DEST="$1"
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  DEST=/usr/local/bin
else
  DEST="$HOME/.local/bin"
fi

mkdir -p "$DEST" || { echo "Impossibile creare $DEST"; exit 1; }
cp "$SRC" "$DEST/talpa" && chmod 755 "$DEST/talpa" || { echo "Copia non riuscita in $DEST"; exit 1; }

echo "Installato: $DEST/talpa"
case ":$PATH:" in
  *":$DEST:"*) ;;
  *)
    echo
    case "$(basename "${SHELL:-}")" in
      zsh) RC="~/.zshrc" ;;
      bash) RC="~/.bash_profile" ;;
      *) RC="il file di avvio della tua shell" ;;
    esac
    echo "Attenzione: $DEST non e' nel PATH. Aggiungi questa riga a $RC e riapri il Terminale:"
    echo "  export PATH=\"$DEST:\$PATH\""
    ;;
esac
echo
echo "Prova:  talpa --help   e poi   talpa clean --dry-run"
