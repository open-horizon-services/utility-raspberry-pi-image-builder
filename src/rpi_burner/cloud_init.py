"""Cloud Init configuration support."""
import plistlib
import subprocess
from pathlib import Path

import yaml


class CloudInitError(Exception):
    pass


def get_boot_partition(device_path: str) -> str | None:
    """Find the boot partition on a disk."""
    try:
        result = subprocess.run(
            ["diskutil", "list", "-plist", device_path],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        return None

    import plistlib
    plist_data = plistlib.loads(result.stdout.encode())

    all_disks = plist_data.get("AllDisksAndPartitions", [])
    for disk_info in all_disks:
        partitions = disk_info.get("Partitions", [])
        for partition in partitions:
            content = partition.get("Content", "")
            if content in ("DOS", "FAT32", "msdos", "Windows_FAT_32"):
                return f"/dev/{partition.get('DeviceIdentifier')}"

    return None


def mount_partition(partition_path: str) -> Path:
    """Mount a partition and return the mount point."""
    try:
        result = subprocess.run(
            ["diskutil", "mount", partition_path],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        pass

    try:
        result = subprocess.run(
            ["diskutil", "info", "-plist", partition_path],
            capture_output=True,
            text=True,
            check=True,
        )
        plist_data = plistlib.loads(result.stdout.encode())
        mount_point = plist_data.get("MountPoint", "")
        if mount_point:
            return Path(mount_point)
    except subprocess.CalledProcessError:
        pass

    raise CloudInitError("Could not determine mount point")


def write_cloud_init_files(mount_path: Path, user_data: str, meta_data: str = "") -> None:
    """Write cloud-init files to the boot partition."""
    if not mount_path.exists():
        raise CloudInitError(f"Mount point does not exist: {mount_path}")

    user_data_path = mount_path / "user-data"
    user_data_path.write_text(user_data)

    if meta_data:
        meta_data_path = mount_path / "meta-data"
        meta_data_path.write_text(meta_data)


def load_cloud_config(config_path: Path) -> str:
    """Load and validate a cloud-config YAML file."""
    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise CloudInitError(f"Invalid YAML: {e}") from e
    except FileNotFoundError:
        raise CloudInitError(f"Config file not found: {config_path}") from None

    if not isinstance(config, dict):
        raise CloudInitError("Cloud config must be a YAML dictionary")

    return yaml.dump(config, default_flow_style=False)
