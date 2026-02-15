"""Data models for rpi-burner."""
from dataclasses import dataclass


@dataclass
class Disk:
    device_path: str
    volume_name: str
    size_bytes: int
    file_system: str
    is_removable: bool
    is_ejectable: bool

    @property
    def size_gb(self) -> float:
        return self.size_bytes / (1024**3)

    @property
    def display_name(self) -> str:
        if self.volume_name and self.volume_name != "Untitled":
            return f"{self.volume_name} ({self.device_path})"
        return self.device_path
