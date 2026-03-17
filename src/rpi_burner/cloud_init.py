"""Cloud Init configuration support."""

import re
import uuid
from pathlib import Path

import yaml

from rpi_burner.backends import get_backend
from rpi_burner.exceptions import CloudInitError

__all__ = [
    "CloudInitError",
    "generate_meta_data",
    "get_boot_partition",
    "load_cloud_config",
    "load_network_config",
    "load_wpa_supplicant",
    "mount_partition",
    "network_config_has_wifi",
    "write_cloud_init_files",
]

DEFAULT_NETWORK_CONFIG = """\
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      optional: true
"""


def get_boot_partition(device_path: str) -> str | None:
    return get_backend().get_boot_partition(device_path)


def mount_partition(partition_path: str) -> Path:
    return get_backend().mount_partition(partition_path)


def generate_meta_data() -> str:
    instance_id = str(uuid.uuid4())
    return f"instance-id: {instance_id}\n"


def write_cloud_init_files(
    mount_path: Path,
    user_data: str,
    network_config: str | None = None,
    wpa_supplicant: str | None = None,
) -> None:
    if not mount_path.exists():
        raise CloudInitError(f"Mount point does not exist: {mount_path}")

    backend = get_backend()
    backend.write_file(mount_path / "user-data", user_data)
    backend.write_file(mount_path / "meta-data", generate_meta_data())
    backend.write_file(mount_path / "network-config", network_config or DEFAULT_NETWORK_CONFIG)

    if wpa_supplicant:
        backend.write_file(mount_path / "wpa_supplicant.conf", wpa_supplicant)


def detect_keyboard_layout() -> str:
    try:
        text = Path("/etc/default/keyboard").read_text()
        match = re.search(r'^XKBLAYOUT="?([^"\n]+)"?', text, re.MULTILINE)
        if match:
            return match.group(1)
    except OSError:
        pass
    return "us"


def load_cloud_config(config_path: Path) -> str:
    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise CloudInitError(f"Invalid YAML: {e}") from e
    except FileNotFoundError:
        raise CloudInitError(f"Config file not found: {config_path}") from None

    if not isinstance(config, dict):
        raise CloudInitError("Cloud config must be a YAML dictionary")

    if "keyboard" not in config:
        config["keyboard"] = {"model": "pc105", "layout": detect_keyboard_layout()}

    result: str = "#cloud-config\n" + yaml.dump(config, default_flow_style=False)
    return result


def load_network_config(config_path: Path) -> str:
    try:
        return config_path.read_text()
    except FileNotFoundError:
        raise CloudInitError(f"Network config file not found: {config_path}") from None


def load_wpa_supplicant(config_path: Path) -> str:
    try:
        return config_path.read_text()
    except FileNotFoundError:
        raise CloudInitError(f"WPA supplicant config file not found: {config_path}") from None


def network_config_has_wifi(config: str) -> bool:
    """Check if network config contains WiFi configuration."""
    try:
        parsed = yaml.safe_load(config)
        if isinstance(parsed, dict) and "network" in parsed:
            network = parsed["network"]
            if isinstance(network, dict) and "wifis" in network:
                return True
    except yaml.YAMLError:
        pass
    return False
