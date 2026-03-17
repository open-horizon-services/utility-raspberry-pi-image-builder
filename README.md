# RPI Burner

![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)
![Python](https://img.shields.io/badge/python-3.10%2B-green.svg)

A CLI tool for creating custom Raspberry Pi SD card images with Cloud Init support. Detects removable disks, burns `.img` files, and injects cloud-config — all from the terminal. Supports macOS and Linux.

## Prerequisites

- **macOS** or **Linux**
- Python 3.10+
- An SD card reader with a card inserted

### Platform-specific tools

| Platform | Tools used |
|---|---|
| macOS | `diskutil`, `dd` |
| Linux | `lsblk`, `dd`, `umount`, `mount`, `eject`/`udisksctl` |

> These are standard system utilities — no extra installation needed on most systems.

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
rpi-burner burn image.img -d /dev/disk4 --cloud-init config.yaml   # macOS
rpi-burner burn image.img -d /dev/sdb --cloud-init config.yaml    # Linux
rpi-burner burn image.img -d /dev/sdb --cloud-init config.yaml --network-config network.yaml  # Custom network
rpi-burner burn image.img -d /dev/sdb --cloud-init config.yaml --wpa-supplicant wpa_supplicant.conf  # WiFi with WPA supplicant
```

> Disk write operations require root access. On Linux, the tool automatically elevates privileged commands via `sudo` — you may be prompted for your password. On macOS, run the tool with `sudo` directly.

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
| `--network-config PATH` | Cloud-init network config file (YAML). Defaults to eth0 DHCP if omitted. |
| `--wpa-supplicant PATH` | WPA supplicant config file for WiFi. Required for WiFi to work on Raspberry Pi OS (sets country code). |
| `--confirm` | Skip the confirmation prompt (use with caution). |
| `--no-eject` | Don't eject the disk after writing. |

## Cloud Init

Provide a YAML cloud-config file to configure the Pi on first boot. Four files are written to the FAT32 boot partition:
- `user-data` (from your config)
- `meta-data` (auto-generated with a unique instance ID)
- `network-config` (eth0 DHCP by default, or from `--network-config`)
- `wpa_supplicant.conf` (if `--wpa-supplicant` is provided)

If your config doesn't include a `keyboard` section, one is automatically added using the host machine's layout (read from `/etc/default/keyboard`), defaulting to `us`.

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

See `samples/` for more examples: [Wi-Fi](samples/wifi-example.yaml), [static IP](samples/static-ip-example.yaml), [SSH keys](samples/ssh-keys-example.yaml). For `--network-config` examples: [Wi-Fi network](samples/network-config-example.yaml), [static IP network](samples/network-static-ip-example.yaml).

## WiFi Configuration

To connect to WiFi on Raspberry Pi, you must set the WiFi country code. This is required by the kernel and without it, WiFi will be blocked by `rfkill`.

### Option 1: WPA Supplicant (Recommended)

Create a `wpa_supplicant.conf` file:

```bash
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="YourNetworkName"
    psk="YourPassword"
    key_mgmt=WPA-PSK
}
```

Then burn with:

```bash
rpi-burner burn image.img -d /dev/sdb --cloud-init config.yaml --wpa-supplicant wpa_supplicant.conf
```

### Option 2: Cloud-init Network Config

You can also use `--network-config` with a YAML file, but note that:
- Cloud-init network-config doesn't support setting the WiFi country code
- For Raspberry Pi OS Bookworm or later, you may still need WPA Supplicant

## License

Apache 2.0
