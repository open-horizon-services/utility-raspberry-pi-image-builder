# RPI Burner

macOS CLI tool to burn Raspberry Pi images to SD cards with Cloud Init support.

## Features

- Detect removable disks (SD cards, USB drives)
- Interactive or command-line disk selection
- Burn `.img` or `.iso` files to SD cards
- Inject Cloud Init configuration
- Progress display during burn
- Safety confirmation before writing

## Installation

```bash
git clone https://github.com/yourusername/rpi-burner.git
cd rpi-burner
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"
```

## Usage

**Requires sudo** - Disk operations need root access:

```bash
sudo rpi-burner burn image.img -d /dev/disk4
```

### List available disks

```bash
rpi-burner list
```

### Burn an image (interactive)

```bash
rpi-burner burn image.img
```

### Burn an image (specify disk)

```bash
rpi-burner burn image.img -d /dev/disk4
```

### Burn with Cloud Init

```bash
rpi-burner burn image.img --cloud-init config.yaml
```

### Skip confirmation (scripting)

```bash
rpi-burner burn image.img -d /dev/disk4 --confirm
```

### Options

- `-d, --disk TEXT` - Target disk device path
- `--confirm` - Skip confirmation prompt
- `--no-eject` - Don't eject disk after writing
- `--cloud-init PATH` - Cloud-init config file (YAML)

## Cloud Init Examples

### Basic

```yaml
#cloud-config
hostname: rpi-hostname
users:
  - name: pi
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    passwd: "$6$rounds=4096$...hashed..."
runcmd:
  - echo "Raspberry Pi booted" > /home/pi/booted.txt
```

### Wi-Fi

```yaml
#cloud-config
hostname: rpi-wifi
wifi:
  wlan0:
    ssid: "YourNetworkName"
    password: "YourPassword"
```

See `samples/` directory for more examples:
- `samples/wifi-example.yaml` - Wi-Fi configuration
- `samples/static-ip-example.yaml` - Static IP configuration  
- `samples/ssh-keys-example.yaml` - SSH key authentication

## Safety

- Always confirm before writing
- Double-check the target device
- Wrong device = data loss

## License

MIT
