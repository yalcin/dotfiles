#!/usr/bin/env bash
set -u
set -o pipefail

# --------- Ayarlar ---------
BACKUP_MOUNT="/mnt/backup"
RUN_PRUNE=true          # false yaparsan prune çalışmaz
DELETED_SAMPLE_N=3      # bildirime kaç silinen snapshot örneği yazılsın

start_time=$(date +%s)

# --------- jq kontrolü ---------
has_jq=false
if command -v jq >/dev/null 2>&1; then
  has_jq=true
else
  notify-send -u critical "⚠ jq bulunamadı" \
    "Yedekleme yapılacak ama snapshot bilgisi (JSON) okunamayacak.\nKurmak için: sudo pacman -S jq"
fi

# --------- Yardımcılar ---------
df_avail_bytes() {
  # 2. satır (header sonrası) "avail" bayt değerini döndürür
  df -B1 --output=avail "$1" 2>/dev/null | awk 'NR==2 {print $1}'
}

human_bytes() {
  local n="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$n" 2>/dev/null || printf '%sB' "$n"
  else
    printf '%sB' "$n"
  fi
}

short8() {
  # ilk 8 karakter; boşsa N/A
  local s="${1:-}"
  if [[ -z "$s" || "$s" == "N/A" ]]; then
    printf 'N/A'
  else
    printf '%s' "${s:0:8}"
  fi
}

snapshot_ids_json() {
  # rustic snapshots --json çıktısından (format değişken olsa da) tüm .id alanlarını topla
  # stdout: id listesi (tam), stderr: rustic log/progress ekrana
  rustic snapshots --json 2> >(tee /dev/stderr) \
    | jq -r '..|objects|.id? // empty' 2>/dev/null \
    | grep -E '^[a-f0-9]{8,64}$' \
    | sort -u
}

free_before="$(df_avail_bytes "$BACKUP_MOUNT")"
free_before="${free_before:-0}"

before_ids=""
if $has_jq; then
  before_ids="$(snapshot_ids_json || true)"
fi

# --------- BACKUP ---------
snapshot_id="N/A"

if $has_jq; then
  # stdout: JSON (capture), stderr: ekrana (progress/log)
  backup_json="$(rustic backup --json 2> >(tee /dev/stderr))"
  backup_rc=$?

  if [[ $backup_rc -eq 0 ]]; then
    # JSON stream içinde id/snapshot_id alanlarını arayıp son görüleni al
    snapshot_id="$(
      printf '%s\n' "$backup_json" \
        | jq -r '..|objects|(.snapshot_id? // .id? // empty)' 2>/dev/null \
        | grep -E '^[a-f0-9]{8,64}$' \
        | tail -n1
    )"
    snapshot_id="${snapshot_id:-N/A}"
  fi
else
  backup_output="$(rustic backup 2>&1)"
  backup_rc=$?
  printf '%s\n' "$backup_output"

  # Metin fallback: "snapshot <id> saved"
  snapshot_id="$(
    printf '%s\n' "$backup_output" \
      | grep -oEi 'snapshot [a-f0-9]{8,} saved' \
      | awk '{print $2}' \
      | tail -n1
  )"
  snapshot_id="${snapshot_id:-N/A}"
fi

if [[ $backup_rc -ne 0 ]]; then
  notify-send -u critical "❌ Rustic Yedekleme Hatası" \
    "rustic backup başarısız oldu (çıkış kodu: $backup_rc)."
  exit "$backup_rc"
fi

# --------- FORGET ---------
if $has_jq; then
  forget_json="$(rustic forget --json 2> >(tee /dev/stderr))"
  forget_rc=$?
else
  forget_output="$(rustic forget 2>&1)"
  forget_rc=$?
  printf '%s\n' "$forget_output"
fi

if [[ $forget_rc -ne 0 ]]; then
  notify-send -u critical "❌ Rustic Forget Hatası" \
    "rustic forget başarısız oldu (çıkış kodu: $forget_rc)."
  exit "$forget_rc"
fi

# --------- PRUNE (opsiyonel) ---------
if $RUN_PRUNE; then
  prune_output="$(rustic prune 2>&1)"
  prune_rc=$?
  printf '%s\n' "$prune_output"

  if [[ $prune_rc -ne 0 ]]; then
    notify-send -u critical "❌ Rustic Prune Hatası" \
      "rustic prune başarısız oldu (çıkış kodu: $prune_rc)."
    exit "$prune_rc"
  fi
fi

# --------- Silinen snapshot hesapla (best-effort) ---------
deleted_count="N/A"
deleted_sample=""

if $has_jq; then
  after_ids="$(snapshot_ids_json || true)"

  deleted_ids="$(
    comm -23 \
      <(printf '%s\n' "$before_ids" | sed '/^$/d') \
      <(printf '%s\n' "$after_ids"  | sed '/^$/d') 2>/dev/null || true
  )"

  if [[ -n "$deleted_ids" ]]; then
    deleted_count="$(printf '%s\n' "$deleted_ids" | sed '/^$/d' | wc -l | awk '{print $1}')"
    deleted_sample="$(
      printf '%s\n' "$deleted_ids" \
        | sed '/^$/d' \
        | head -n "$DELETED_SAMPLE_N" \
        | awk '{print substr($0,1,8)}' \
        | paste -sd',' -
    )"
  else
    deleted_count="0"
  fi
else
  # jq yoksa forget metninden kaba sayım (format değişebilir)
  deleted_count="$(
    printf '%s\n' "${forget_output:-}" \
      | grep -Eic 'remove(d)? snapshot|forget(ting)? snapshot|snapshot .* removed' || true
  )"
fi

# --------- Süre & Disk delta ---------
end_time=$(date +%s)
duration=$((end_time - start_time))

free_after="$(df_avail_bytes "$BACKUP_MOUNT")"
free_after="${free_after:-0}"

delta=$((free_after - free_before))
delta_abs="${delta#-}"
delta_human="$(human_bytes "$delta_abs")"
delta_prefix="+"
if [[ $delta -lt 0 ]]; then
  delta_prefix="-"
fi

disk_info="$(df -h "$BACKUP_MOUNT" | awk 'NR==2 {print $4 " boş alan"}')"

# --------- Bildirim ---------
snapshot_short="$(short8 "$snapshot_id")"

extra_deleted=""
if [[ "$deleted_count" != "N/A" ]]; then
  extra_deleted="Silinen snapshot: ${deleted_count}"
  if [[ -n "$deleted_sample" ]]; then
    extra_deleted="${extra_deleted}\nSample: ${deleted_sample}"
  fi
fi

notify-send "✅ Rustic Yedekleme Başarılı" \
  "Snapshot(8): ${snapshot_short}\nSüre: ${duration}s\n${extra_deleted}\nDisk: ${disk_info}\nΔ Boş alan: ${delta_prefix}${delta_human}"
