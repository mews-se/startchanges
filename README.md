# Automated System Configuration Script

![Version](https://img.shields.io/badge/version-v2026.04.01-informational)
![License](https://img.shields.io/badge/license-Unlicense-blue.svg)
![Platform](https://img.shields.io/badge/platform-Debian%2FDietPi-lightgrey)
![Shell](https://img.shields.io/badge/shell-bash-blue)

Lightweight Bash script for automated post-install configuration on Debian/DietPi systems.

Designed for personal use, fast provisioning, and repeatable setups across servers, Raspberry Pi, and home lab environments.

---

## Features

- System update & upgrade
- SSH hardening (no root login, whitelist support)
- Passwordless sudo setup
- SSH key generation (Ed25519)
- Shell configuration (`.bashrc` + `.bash_aliases`)
- Docker install/remove
- SNMPD setup (profile-based)
- PiVPN install + client generation
- Fastfetch updater integration
- DietPi upgrade helpers
- Wake-on-LAN tools
- NAS backup script (rsync over CIFS)
- Automatic config backups
- Menu-driven interface

---

## Profiles

Selected at runtime:

- `x64`
- `x64-brk`
- `pi`
- `pi-brk`

Profiles adjust SNMP, aliases, and system-specific behavior.

---

## Usage

```bash
git clone https://github.com/mews-se/hostctl.git
cd hostctl
sudo ./hostctl.sh
```

Select a profile and choose tasks from the menu.

---

## NAS Backup (Summary)

- Generates: `~/nas-backup.sh`
- Credentials stored in: `/root/.nas-credentials`
- Uses rsync mirror with excludes (DietPi-style)
- Includes `/home` and `/mnt/dietpi_userdata`

---

## Notes

- Restart shell after bash config changes
- Re-login after Docker install
- Review script before running

---

## License

The Unlicense
- Credentials stored in: `/root/.nas-credentials`
- Uses rsync mirror with excludes (DietPi-style)
- Includes `/home` and `/mnt/dietpi_userdata`

---

## License

The Unlicense
