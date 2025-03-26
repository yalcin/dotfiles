# Repository Sifresi
`$HOME/.rustic_p.txt` dosyasina yazilmali ya da `env` degiskeni olarak ```bash export RUSTIC_PASSWORD=SIFRE``` seklinde tanimlanmali.

# Backup'i aktive etmek icin:

```bash
systemctl --user enable --now rustic-backup.timer
```
