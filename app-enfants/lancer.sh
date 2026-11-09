#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  Lance « Le Jardin du Tawhid » en local.
#  Usage : ./lancer.sh      (Linux / macOS)
# ═══════════════════════════════════════════════════════════
set -e
PORT="${1:-8000}"
cd "$(dirname "$0")"

PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
  echo "⚠️  Python est introuvable."
  echo "    Installe-le depuis https://www.python.org"
  echo "    ou lance :  npx serve ."
  exit 1
fi

echo ""
echo "  ❦  Le Jardin du Tawhid"
echo "  ────────────────────────────────────────────────"
echo "  Sur cet ordinateur :"
echo "     http://localhost:$PORT"
echo ""

# Adresses IP locales, pour tester sur un téléphone branché au même Wi-Fi
IPS="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)"
[ -z "$IPS" ] && IPS="$(ifconfig 2>/dev/null \
  | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]+' \
  | grep -Eo '([0-9]*\.){3}[0-9]+' | grep -v '^127\.' || true)"

if [ -n "$IPS" ]; then
  echo "  Sur un téléphone (même Wi-Fi) :"
  for ip in $IPS; do echo "     http://$ip:$PORT"; done
  echo ""
  echo "  Astuce : ouvre le lien puis « Installer l'application »"
  echo "           (Chrome ⋮) ou « Sur l'écran d'accueil » (Safari)."
else
  echo "  (Aucune adresse réseau détectée : teste sur cet ordinateur.)"
fi

echo ""
echo "  Ctrl+C pour arrêter."
echo "  ────────────────────────────────────────────────"
echo ""

exec "$PY" -m http.server "$PORT" --bind 0.0.0.0
