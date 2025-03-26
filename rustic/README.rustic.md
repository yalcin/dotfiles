# Repository Sifresi
`$HOME/.rustic_p.txt` dosyasina yazilmali ya da `env` degiskeni olarak ```bash export RUSTIC_PASSWORD=SIFRE``` seklinde tanimlanmali.

# Rustic Ayarlari
`rustic/.config/rustic/rustic.toml` dosyasindan duzenlenebilir.

# Backup'i aktive etmek icin:

```bash
systemctl --user enable --now rustic-backup.timer
```
