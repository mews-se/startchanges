# Automated System Configuration Script

![Version](https://img.shields.io/github/v/tag/mews-se/startchanges?sort=semver)
![License](https://img.shields.io/badge/license-Unlicense-blue.svg)

This Bash script automates post-install system configuration on  
Debian-based systems and DietPi installations. It provides secure  
defaults, shell customization, Docker, SNMPD & PiVPN setup, NAS backup,  
and repeatable provisioning --- all through an interactive menu.

The script supports multiple machine profiles (x64 servers and Raspberry  
Pi systems) using **one unified script**, making maintenance and updates  
significantly easier.

Designed for quick deployment or repeatable provisioning of servers,  
work machines, and home lab environments.

------------------------------------------------------------------------

## Disclaimer

This script is provided as-is for personal and educational use and is  
based on real-world requirements. While it includes safeguards such as  
backups and confirmation prompts, you should always review the code  
before running it --- especially on production systems.

Use at your own risk. The author assumes no liability for system damage,  
data loss, or misconfiguration.

------------------------------------------------------------------------

## Features

- 🔧 System Update & Upgrade  
- 🔐 Secure SSH configuration  
  - Disables root login  
  - Whitelist-based SSH access  
- ⚙️ Passwordless sudo configuration for the `sudo` group  
- 🔑 Automatic Ed25519 SSH key generation  
- 🧠 Smart shell configuration  
  - Recreates `.bashrc`  
  - Interactive `.bash_aliases` merge  
- 🐳 Docker CE installation (official repository + plugins)  
- 🧹 Docker removal task (full cleanup option)  
- 📡 SNMPD installation with profile-based configuration  
- 🔐 PiVPN installation with optional client generation  
- 🚀 Fastfetch repository cloning  
- 🔄 DietPi upgrade helpers  
- 📡 Wake-on-LAN support  
- 💾 NAS backup script generator (DietPi-style folders)  
- 🗂️ Automatic backups before modifying system files  
- 🧾 Timestamped logging  
- 🖥️ Interactive menu-driven interface  

------------------------------------------------------------------------

## NAS Backup (DietPi-style)

The script generates a standalone:

```
nas-backup.sh
```

### Behavior

- Uses **SMB/CIFS**
- Uses **rsync with progress**
- Stops DietPi services during backup
- Uses **incremental rotation**

### Rotation

```
current → previous_1 → previous_2
```

### Structure

```
/backup/dietpibackup/<hostname>/
    ├── current/
    ├── previous_1/
    └── previous_2/
```

### Scope

This backup intentionally excludes runtime/system paths such as:

- `/proc`
- `/sys`
- `/run`
- `/dev`
- `/tmp`

This mirrors DietPi’s native backup behavior and avoids rsync errors.

------------------------------------------------------------------------

## Credentials Handling (Security)

Credentials are NOT stored in the script.

Instead:

```
/root/.nas-credentials
```

Permissions:

```
chmod 600
```

- Created automatically if missing  
- Pre-configured internally  
- Never exposed in source code  

------------------------------------------------------------------------

## Wake-on-LAN

The script includes:

- Installation of `wakeonlan`
- Predefined aliases for devices

Example:

```bash
wakeonlan <MAC>
```

------------------------------------------------------------------------

## Supported Profiles

| Profile   | Description |
|----------|------------|
| x64      | Standard x64 server/home lab systems |
| x64-brk  | x64 systems used in work environment |
| pi       | Raspberry Pi systems |
| pi-brk   | Raspberry Pi systems used in work environment |

------------------------------------------------------------------------

## Usage

```bash
git clone https://github.com/mews-se/startchanges.git
cd startchanges
sudo ./startchanges.sh
```

------------------------------------------------------------------------

## Important Notes

### Docker

```bash
logout
```

---

### Shell

```bash
source ~/.bashrc && source ~/.bash_aliases
```

---

### PiVPN

Clients created:

```
<hostname>-tb7
<hostname>-mbp
<hostname>-iph
<hostname>-len
```

QR prompt included.

⚠️ Not part of "Run all tasks".

------------------------------------------------------------------------

## Security Recommendations

```
.nas-credentials
*.log
nas-backup.sh
dietpibackup/
```

------------------------------------------------------------------------

## Support

https://github.com/mews-se/startup-script/issues

------------------------------------------------------------------------

## License

Licensed under **The Unlicense**
