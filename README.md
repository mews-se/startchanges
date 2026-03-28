# Automated System Configuration Script

This Bash script automates post-install system configuration on Debian-based systems and DietPi installations. It provides secure defaults, shell customization, Docker, SNMPD & PiVPN setup, NAS backup, and repeatable provisioning through an interactive menu.

The script supports multiple machine profiles (x64 servers and Raspberry Pi systems) using one unified script, making maintenance and updates significantly easier.

Designed for quick deployment or repeatable provisioning of servers, work machines, and home lab environments.

------------------------------------------------------------------------

## Disclaimer

This script is provided as-is for personal and educational use and is based on real-world requirements. While it includes safeguards such as backups and confirmation prompts, you should always review the code before running it, especially on production systems.

Use at your own risk. The author assumes no liability for system damage, data loss, or misconfiguration.

------------------------------------------------------------------------

## Features

- System Update & Upgrade  
- Secure SSH configuration  
- Passwordless sudo configuration  
- Automatic Ed25519 SSH key generation  
- Smart shell configuration  
- Docker CE installation  
- Docker removal  
- SNMPD installation  
- PiVPN installation  
- Fastfetch cloning  
- DietPi upgrade helpers  
- Wake-on-LAN support  
- NAS backup script generator (DietPi-style folders)  
- Automatic backups  
- Logging  
- Interactive menu  

------------------------------------------------------------------------

## NAS Backup (DietPi-style)

The script generates a standalone backup script:

nas-backup.sh

Backup rotation:

current → previous_1 → previous_2

Structure:

/backup/dietpibackup/<hostname>/
    ├── current/
    ├── previous_1/
    └── previous_2/

Notes:
- Uses SMB/CIFS
- Uses rsync with progress
- Stops DietPi services during backup
- Matches DietPi backup behavior (not full root clone)

------------------------------------------------------------------------

## Credentials Handling

Credentials are NOT stored in the script.

They are stored in:
/root/.nas-credentials

Permissions:
chmod 600

The file is created automatically if missing and is never exposed in source code.

------------------------------------------------------------------------

## Usage

git clone https://github.com/mews-se/startchanges.git  
cd startchanges  
sudo ./startchanges_dietpi_style_folders_with_wol_prompt_creds.sh  

------------------------------------------------------------------------

## Supported Profiles

- x64  
- x64-brk  
- pi  
- pi-brk  

Each profile applies correct SNMP and environment configuration.

------------------------------------------------------------------------

## Important Notes

Docker:  
Run logout after installation to activate group membership.

Shell:  
source ~/.bashrc && source ~/.bash_aliases

------------------------------------------------------------------------

## PiVPN

Optional install via menu.

Auto client naming:
<hostname>-tb7  
<hostname>-mbp  
<hostname>-iph  
<hostname>-len  

QR prompt included.

Not part of "Run all tasks".

------------------------------------------------------------------------

## Security Recommendations

Add to .gitignore:

.nas-credentials  
*.log  
nas-backup.sh  
dietpibackup/  

------------------------------------------------------------------------

## License

Unlicense
