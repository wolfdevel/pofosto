# pofosto – Mail-Archiv-Server (Dovecot, nur IMAP)

Reines IMAP-Archiv in Docker: kein SMTP, kein Spam-/Virenscan. Zugriff im LAN
bzw. per VPN über Port 993 (IMAPS), z. B. als Ablage für Thunderbird-Archive.
Basis: offizielles Image `dovecot/dovecot:2.4.5` mit eingebauter Konfiguration.

## Aufbau

```
docker-compose.yml   # Stack (für Portainer oder docker compose)
Dockerfile           # dovecot/dovecot:2.4.5 + conf.d
conf.d/
  archiv.conf        # nur IMAP, nur IPv4, kein Klartext-Login ohne TLS
  auth.conf          # Benutzer aus /etc/dovecot/local/users
  mail.conf          # INBOX-Namespace + Standardordner
  ssl.conf           # TLS aus /etc/dovecot/local/tls.{crt,key}
  fts.conf           # serverseitige Volltextsuche (Deutsch/Englisch)
users.example        # Vorlage für die Benutzerdatei
.env.example         # Variablen für Portainer
```

Zugangsdaten und TLS-Schlüssel liegen **nicht** im Repo (es ist öffentlich),
sondern in einem Verzeichnis auf dem Docker-Host (`ARCHIV_DIR`, Standard
`/opt/mail-archiv`), das schreibgeschützt in den Container gemountet wird.

## 1. Verzeichnis auf dem Docker-Host vorbereiten

```bash
sudo mkdir -p /opt/mail-archiv && cd /opt/mail-archiv

# Passwort-Hash erzeugen (fragt das Passwort ab)
docker run --rm -it dovecot/dovecot:2.4.5 doveadm pw -s SHA512-CRYPT

# Benutzerdatei: eine Zeile pro Postfach
echo 'archiv:{SHA512-CRYPT}$6$...hier-den-Hash...:::::' | sudo tee users

# TLS-Zertifikat (selbstsigniert zum Start)
sudo openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout tls.key -out tls.crt -days 3650 -subj "/CN=mail.internal.local"

# Der Container läuft als UID 1000 und muss die Dateien lesen können
sudo chown root:1000 users tls.key tls.crt
sudo chmod 640 users tls.key
sudo chmod 644 tls.crt
```

Das Verzeichnis muss `users`, `tls.crt` und `tls.key` enthalten, bevor der
Stack startet. Neue Benutzer: Zeile in `users` ergänzen, fertig (die Datei
wird bei jedem Login gelesen).

## 2. Stack in Portainer anlegen

1. *Stacks → Add stack → Repository*
2. Repository URL: `https://github.com/wolfdevel/pofosto`
3. Repository reference: `refs/heads/main`
4. Compose path: `docker-compose.yml`
5. *Environment variables* (optional, sonst gelten die Standardwerte):
   - `ARCHIV_DIR` = `/opt/mail-archiv`
   - `IMAPS_PORT` = `993`
   - `TZ` = `Europe/Vienna`
6. *Deploy the stack*

Portainer baut dabei das Image aus dem `Dockerfile` und startet den
Container. Im Log sollte stehen:
`Dovecot v2.4.5 ... starting up for imap`.

Ohne Portainer geht dasselbe mit `docker compose up -d --build`.

## 3. In Thunderbird einbinden

- Neues Konto: IMAP, Server = IP/Hostname des Docker-Hosts
- Port 993, SSL/TLS, normales Passwort
- Benutzer/Passwort wie in `users`

Danach die lokalen Ordner per Drag & Drop ins IMAP-Konto ziehen. Tipp: erst
einen kleinen Ordner testen, große Archive ordnerweise verschieben.

## Backup

Die Mails liegen im Docker-Volume `<stackname>_vmail-data` (Maildir):

```bash
docker run --rm -v <stackname>_vmail-data:/data -v "$PWD":/backup debian:13-slim \
  tar czf /backup/vmail-$(date +%F).tar.gz -C /data .
```

## Hinweise

- Port 993 nicht ins Internet weiterleiten; von außen nur über VPN.
- Die Image-Version ist bewusst gepinnt (Dovecot 2.4 hat eine eigene
  Konfig-Syntax). Vor einem Update Release Notes lesen und mit
  `docker compose run --rm dovecot doveconf -n` auf Fehler prüfen.
- Nach Änderungen an `conf.d/` im Repo genügt in Portainer
  *Pull and redeploy*; das Image wird bei jedem Deploy neu gebaut.
