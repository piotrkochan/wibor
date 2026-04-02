#!/bin/bash
# Pobiera nowe stawki WIBOR ze Stooq i dopisuje do istniejących JSON-ów
# Uruchamiane przez GitHub Action (cron) lub ręcznie

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
D2=$(date +%Y%m%d)

for TENOR in 1m 3m 6m; do
  FILE="${DIR}/wibor-${TENOR}.json"

  # Ustal datę startu: dzień po ostatnim rekordzie lub 2000-01-01 jeśli brak pliku
  if [ -f "$FILE" ] && [ -s "$FILE" ]; then
    LAST_DATE=$(jq -r '.[-1].d' "$FILE")
    # Dzień po ostatnim rekordzie
    D1=$(date -d "${LAST_DATE} + 1 day" +%Y%m%d)
  else
    D1="20000101"
  fi

  # Jeśli d1 > d2, nie ma czego pobierać
  if [ "$D1" -gt "$D2" ]; then
    echo "SKIP $TENOR — dane aktualne do ${LAST_DATE}"
    continue
  fi

  URL="https://stooq.com/q/d/l/?s=plopln${TENOR}&d1=${D1}&d2=${D2}&i=d"
  CSV=$(curl -sf -A "Mozilla/5.0 (compatible; wibor-bot/1.0)" "$URL")

  if [ -z "$CSV" ] || echo "$CSV" | head -1 | grep -qi "brak"; then
    echo "SKIP $TENOR — brak nowych danych ze Stooq"
    continue
  fi

  # CSV → JSON tablica nowych rekordów
  NEW=$(echo "$CSV" | tr -d '\r' | awk -F, 'NR>1 && $1~/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {printf "%s\t%s\n",$1,$5}' \
    | jq -Rsc '
      split("\n") | map(select(length>0) | split("\t") | {d:.[0], r:(.[1]|tonumber)})
    ')

  NEW_COUNT=$(echo "$NEW" | jq length)
  if [ "$NEW_COUNT" -eq 0 ]; then
    echo "SKIP $TENOR — brak nowych rekordów"
    continue
  fi

  # Dopisz nowe rekordy do istniejącego pliku
  jq -s '.[0] + .[1]' "$FILE" <(echo "$NEW") > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

  COUNT=$(jq length "$FILE")
  LAST=$(jq -r '.[-1].d' "$FILE")
  echo "OK wibor-${TENOR}: +${NEW_COUNT} nowych, razem ${COUNT}, ostatnia ${LAST}"
done

# Metadane
jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{updated: $ts}' > "${DIR}/meta.json"
echo "Done — $(cat ${DIR}/meta.json)"
