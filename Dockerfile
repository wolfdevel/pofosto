# Dovecot-Image mit eingebauter Archiv-Konfiguration.
# Die Konfiguration steckt im Image, damit Portainer den Stack direkt aus
# Git bauen kann, ohne relative Bind-Mounts. Zugangsdaten und TLS-Schlüssel
# kommen NICHT ins Image, sondern vom Docker-Host (siehe docker-compose.yml).
FROM dovecot/dovecot:2.4.5

# Überschreibt auth.conf, ssl.conf, mail.conf und fts.conf des Images
COPY conf.d/ /etc/dovecot/conf.d/
