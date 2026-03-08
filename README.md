# RPI Burner

![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![Python](https://img.shields.io/badge/python-3.10%2B-green.svg)

A macOS CLI tool for creating custom Raspberry Pi SD card images with Cloud Init support. Detects removable disks, burns `.img` files, and injects cloud-config — all from the terminal.

## Prerequisites

- macOS (uses `diskutil` and `dd`)
- Python 3.10+
- An SD card reader with a card inserted

## Quick Start

```bash
git clone https://github.com/open-horizon-services/utility-raspberry-pi-image-builder.git
cd utility-raspberry-pi-image-builder
python -m venv venv && source venv/bin/activate
pip install -e ".[dev]"
```

List available disks, then burn:

```bash
rpi-burner list
sudo rpi-burner burn image.img -d /dev/disk4 --cloud-init config.yaml
```

> **Requires sudo** — disk write operations need root access.

## Usage

```bash
rpi-burner list                                    # List removable disks
rpi-burner burn <image> [options]                   # Burn image to disk
```

### Options

| Flag | Description |
|---|---|
| `-d, --disk PATH` | Target disk device path (e.g., `/dev/disk4`). Prompts interactively if omitted. |
| `--cloud-init PATH` | Cloud-init config file (YAML) to inject onto boot partition. |
| `--confirm` | Skip the confirmation prompt (use with caution). |
| `--no-eject` | Don't eject the disk after writing. |

## Cloud Init

Provide a YAML cloud-config file to configure the Pi on first boot. The file is written to the FAT32 boot partition as `user-data`.

```yaml
#cloud-config
hostname: rpi-hostname
users:
  - name: pi
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3... your-key
runcmd:
  - echo "Ready" > /home/pi/booted.txt
```

See `samples/` for more examples: [Wi-Fi](samples/wifi-example.yaml), [static IP](samples/static-ip-example.yaml), [SSH keys](samples/ssh-keys-example.yaml).

## License

Apache 2.0
