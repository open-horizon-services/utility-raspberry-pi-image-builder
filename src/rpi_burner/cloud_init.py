"""Cloud Init configuration support."""

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
    "mount_partition",
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
) -> None:
    if not mount_path.exists():
        raise CloudInitError(f"Mount point does not exist: {mount_path}")

    backend = get_backend()
    backend.write_file(mount_path / "user-data", user_data)
    backend.write_file(mount_path / "meta-data", generate_meta_data())
    backend.write_file(mount_path / "network-config", network_config or DEFAULT_NETWORK_CONFIG)


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

    result: str = "#cloud-config\n" + yaml.dump(config, default_flow_style=False)
    return result


def load_network_config(config_path: Path) -> str:
    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise CloudInitError(f"Invalid network config YAML: {e}") from e
    except FileNotFoundError:
        raise CloudInitError(f"Network config file not found: {config_path}") from None

    if not isinstance(config, dict):
        raise CloudInitError("Network config must be a YAML dictionary")

    return yaml.dump(config, default_flow_style=False)
