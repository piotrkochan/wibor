# WIBOR rates

Automatycznie aktualizowane stawki WIBOR 1M/3M/6M ze Stooq.

## Pliki

- `wibor-1m.json`, `wibor-3m.json`, `wibor-6m.json` — tablica `[{d, r}]`
- `meta.json` — timestamp ostatniej aktualizacji
- `fetch.sh` — skrypt pobierający

## Format

```json
[{"d":"2000-01-04","r":17.51}, ...]
```

`d` = data, `r` = stawka (Close z fixingu)

## Aktualizacja

GitHub Action: pon-pt 16:30 UTC (po fixingu WIBOR).
Ręcznie: `bash fetch.sh`
