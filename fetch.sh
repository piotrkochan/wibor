#!/bin/bash
# Pobiera aktualne stawki WIBOR ze Stooq i zapisuje jako lekki JSON
# Uruchamiane przez GitHub Action (cron) lub ręcznie

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
D2=$(date +%Y%m%d)

for TENOR in 1m 3m 6m; do
  URL="https://stooq.com/q/d/l/?s=plopln${TENOR}&d1=20000101&d2=${D2}&i=d"
  CSV=$(curl -sf "$URL")

  if [ -z "$CSV" ] || echo "$CSV" | head -1 | grep -qi "brak"; then
    echo "SKIP $TENOR — brak danych ze Stooq"
    continue
  fi

  # CSV → JSON: tylko date+close, bez nagłówka, najlżejsza forma
  echo "$CSV" | tr -d '\r' | awk -F, 'NR>1 && $1~/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {printf "%s\t%s\n",$1,$5}' \
    | jq -Rsc '
      split("\n") | map(select(length>0) | split("\t") | {d:.[0], r:(.[1]|tonumber)})
    ' > "${DIR}/wibor-${TENOR}.json"

  COUNT=$(jq length "${DIR}/wibor-${TENOR}.json")
  LAST=$(jq -r '.[-1].d' "${DIR}/wibor-${TENOR}.json")
  echo "OK wibor-${TENOR}: ${COUNT} stawek, ostatnia ${LAST}"
done

# Metadane
jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{updated: $ts}' > "${DIR}/meta.json"
echo "Done — $(cat ${DIR}/meta.json)"
