"""Write disk images to removable storage."""
import subprocess
from pathlib import Path


class DiskWriterError(Exception):
    pass


def unmount_disk(device_path: str) -> None:
    """Unmount a disk before writing."""
    try:
        subprocess.run(
            ["diskutil", "unmountDisk", device_path],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        raise DiskWriterError(f"Failed to unmount disk: {e.stderr}") from e


def get_raw_device(device_path: str) -> str:
    """Convert /dev/diskN to /dev/rdiskN for raw writes."""
    if device_path.startswith("/dev/r"):
        return device_path
    return device_path.replace("/dev/disk", "/dev/rdisk")


def burn_image(image_path: str, device_path: str, progress: bool = True) -> None:
    """Burn an image to a disk using dd."""
    image_file = Path(image_path)
    if not image_file.exists():
        raise DiskWriterError(f"Image file not found: {image_path}")

    raw_device = get_raw_device(device_path)

    bs = "1m"
    cmd = ["dd", f"if={image_path}", f"of={raw_device}", f"bs={bs}"]
    if progress:
        cmd.append("status=progress")

    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        raise DiskWriterError(f"Failed to write image: {e}") from e


def eject_disk(device_path: str) -> None:
    """Eject a disk after writing."""
    try:
        subprocess.run(
            ["diskutil", "eject", device_path],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        raise DiskWriterError(f"Failed to eject disk: {e.stderr}") from e
