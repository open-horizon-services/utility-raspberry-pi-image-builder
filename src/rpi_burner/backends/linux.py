"""Linux backend using lsblk, umount, dd, and mount."""

import json
import os
import subprocess
from pathlib import Path

from rpi_burner.exceptions import CloudInitError, DiskDetectorError, DiskWriterError
from rpi_burner.models import Disk

# Transport types that indicate internal drives
_INTERNAL_TRANSPORTS = {"sata", "ata", "nvme", "pcie"}


class LinuxBackend:
    def list_external_disks(self) -> list[Disk]:
        try:
            result = subprocess.run(
                [
                    "lsblk",
                    "--json",
                    "-b",
                    "-o",
                    "NAME,SIZE,TYPE,MOUNTPOINT,RM,TRAN,FSTYPE,LABEL",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            raise DiskDetectorError(f"Failed to list disks: {e.stderr}") from e

        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            raise DiskDetectorError(f"Failed to parse lsblk output: {e}") from e

        disks: list[Disk] = []
        for device in data.get("blockdevices", []):
            if device.get("type") != "disk":
                continue

            removable = bool(device.get("rm"))
            transport = (device.get("tran") or "").lower()
            name = device.get("name", "")

            if transport in _INTERNAL_TRANSPORTS:
                continue

            is_external = removable or transport in ("usb", "mmc")
            if not is_external and not self._is_sysfs_removable(name):
                continue

            volume_name = ""
            file_system = "Unknown"
            children = device.get("children", [])
            for child in children:
                label = child.get("label") or ""
                if label:
                    volume_name = label
                fstype = child.get("fstype") or ""
                if fstype:
                    file_system = fstype

            disks.append(
                Disk(
                    device_path=f"/dev/{name}",
                    volume_name=volume_name,
                    size_bytes=device.get("size") or 0,
                    file_system=file_system,
                    is_removable=True,
                )
            )

        return disks

    def get_disk_info(self, device_path: str) -> Disk:
        try:
            result = subprocess.run(
                [
                    "lsblk",
                    "--json",
                    "-b",
                    "-o",
                    "NAME,SIZE,TYPE,MOUNTPOINT,RM,TRAN,FSTYPE,LABEL",
                    device_path,
                ],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            raise DiskDetectorError(f"Failed to get disk info: {e.stderr}") from e

        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            raise DiskDetectorError(f"Failed to parse lsblk output: {e}") from e

        devices = data.get("blockdevices", [])
        if not devices:
            raise DiskDetectorError(f"No device found at {device_path}")

        device = devices[0]
        volume_name = ""
        file_system = "Unknown"
        for child in device.get("children", []):
            label = child.get("label") or ""
            if label:
                volume_name = label
            fstype = child.get("fstype") or ""
            if fstype:
                file_system = fstype

        if not volume_name:
            volume_name = "Untitled"

        return Disk(
            device_path=device_path,
            volume_name=volume_name,
            size_bytes=device.get("size") or 0,
            file_system=file_system,
            is_removable=bool(device.get("rm")),
        )

    def unmount_disk(self, device_path: str) -> None:
        try:
            result = subprocess.run(
                ["lsblk", "--json", "-o", "NAME,MOUNTPOINT", device_path],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            raise DiskWriterError(f"Failed to query partitions: {e.stderr}") from e

        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            raise DiskWriterError(f"Failed to parse lsblk output: {e}") from e

        for device in data.get("blockdevices", []):
            for child in device.get("children", []):
                mountpoint = child.get("mountpoint")
                if mountpoint:
                    name = child.get("name", "")
                    try:
                        subprocess.run(
                            self._elevate(["umount", f"/dev/{name}"]),
                            check=True,
                            capture_output=True,
                            text=True,
                        )
                    except subprocess.CalledProcessError as e:
                        raise DiskWriterError(f"Failed to unmount /dev/{name}: {e.stderr}") from e

    def burn_image(self, image_path: str, device_path: str, progress: bool = True) -> None:
        image_file = Path(image_path)
        if not image_file.exists():
            raise DiskWriterError(f"Image file not found: {image_path}")

        cmd = self._elevate(["dd", f"if={image_path}", f"of={device_path}", "bs=1M"])
        if progress:
            cmd.append("status=progress")

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            raise DiskWriterError(f"Failed to write image: {e}") from e

        self._reread_partition_table(device_path)

    def eject_disk(self, device_path: str) -> None:
        self.unmount_disk(device_path)

        for cmd in [
            self._elevate(["eject", device_path]),
            self._elevate(["udisksctl", "power-off", "-b", device_path]),
        ]:
            try:
                subprocess.run(cmd, check=True, capture_output=True, text=True)
                return
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue

        raise DiskWriterError(
            f"Failed to eject {device_path}. Neither 'eject' nor 'udisksctl' succeeded."
        )

    def get_boot_partition(self, device_path: str) -> str | None:
        self._reread_partition_table(device_path)

        try:
            result = subprocess.run(
                ["lsblk", "--json", "-o", "NAME,FSTYPE", device_path],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError:
            return None

        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError:
            return None

        for device in data.get("blockdevices", []):
            for child in device.get("children", []):
                if child.get("fstype") == "vfat":
                    return f"/dev/{child['name']}"

        return None

    def mount_partition(self, partition_path: str) -> Path:
        partition_name = Path(partition_path).name
        mount_point = Path(f"/tmp/rpi-burner-boot-{partition_name}")
        mount_point.mkdir(exist_ok=True)

        try:
            subprocess.run(
                self._elevate(["mount", partition_path, str(mount_point)]),
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            raise CloudInitError(f"Failed to mount {partition_path}: {e.stderr}") from e

        return mount_point

    def write_file(self, path: Path, content: str) -> None:
        try:
            subprocess.run(
                self._elevate(["tee", str(path)]),
                input=content,
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            raise CloudInitError(f"Failed to write {path}: {e.stderr}") from e

    @staticmethod
    def _elevate(cmd: list[str]) -> list[str]:
        """Prepend sudo if not running as root."""
        if os.geteuid() == 0:
            return cmd
        return ["sudo", *cmd]

    @staticmethod
    def _is_sysfs_removable(device_name: str) -> bool:
        sysfs_path = Path(f"/sys/block/{device_name}/removable")
        try:
            return sysfs_path.read_text().strip() == "1"
        except OSError:
            return False

    @staticmethod
    def _reread_partition_table(device_path: str) -> None:
        subprocess.run(["sync"], check=False)
        for cmd in [
            LinuxBackend._elevate(["partprobe", device_path]),
            LinuxBackend._elevate(["blockdev", "--rereadpt", device_path]),
        ]:
            try:
                subprocess.run(cmd, check=True, capture_output=True, text=True)
                return
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
