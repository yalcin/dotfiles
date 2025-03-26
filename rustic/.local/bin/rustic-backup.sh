#!/bin/bash

start_time=$(date +%s)

# jq var mı?
has_jq=true
if ! command -v jq &>/dev/null; then
  has_jq=false
  notify-send -u critical "⚠ jq bulunamadı" \
    "Yedekleme yapılacak ama snapshot bilgisi gösterilmeyecek.\nKurmak için: sudo pacman -S jq"
fi

# Backup'ı çalıştır ve çıktıyı yakala
backup_output=$(rustic backup 2>&1)
echo "$backup_output"

# rustic forget çalıştır
forget_output=$(rustic forget 2>&1)
echo "$forget_output"

# Başarılıysa devam et
if [[ $? -eq 0 ]]; then
  end_time=$(date +%s)
  duration=$((end_time - start_time))

  # rustic backup çıktısından snapshot ID'yi al
  snapshot_id=$(echo "$backup_output" | grep -oE 'snapshot [a-f0-9]{8,} successfully saved' | awk '{print $2}')
  last_snapshot=${snapshot_id:-"N/A"}

  # Disk alanı
  disk_info=$(df -h /mnt/backup | awk 'NR==2 {print $4 " boş alan"}')

  # Bildirim
  notify-send "✅ Rustic Yedekleme Başarılı" \
    "Snapshot: $last_snapshot\nSüre: ${duration}s\nDisk: $disk_info"
else
  notify-send -u critical "❌ Rustic Yedekleme Hatası" \
    "Yedekleme veya forget işlemi başarısız oldu."
fi
