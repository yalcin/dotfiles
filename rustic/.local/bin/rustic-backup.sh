#!/bin/bash

start_time=$(date +%s)

# jq var mı?
has_jq=true
if ! command -v jq &>/dev/null; then
  has_jq=false
  notify-send -u critical "⚠️ jq bulunamadı" "Yedekleme yapılacak ama snapshot bilgisi gösterilmeyecek.\nKurmak için: sudo pacman -S jq"
fi

# TODO prune icin daha sonra bakacagim
# Yedekleme.
if rustic backup && rustic forget; then
  end_time=$(date +%s)
  duration=$((end_time - start_time))

  # Bildirim içeriği jq varsa detaylı, yoksa sade
  if $has_jq; then
    last_snapshot=$(rustic snapshots --json | jq -r '.[-1].id // "N/A"')
    disk_info=$(df -h /mnt/backup | awk 'NR==2 {print $4 " boş alan"}')

    notify-send "✅ Rustic Yedekleme Başarılı" \
      "Snapshot: $last_snapshot\nSüre: ${duration}s\nDisk: $disk_info"
  else
    notify-send "✅ Rustic Yedekleme Başarılı" \
      "jq yüklü olmadığı için detay gösterilmiyor.\nSüre: ${duration}s"
  fi
else
  notify-send -u critical "❌ Rustic Yedekleme Hatası" \
    "Yedekleme veya prune işlemi başarısız oldu."
fi
