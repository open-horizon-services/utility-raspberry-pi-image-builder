"""Tests for disk detector."""
import plistlib
from unittest.mock import patch, MagicMock

from rpi_burner.disk_detector import list_external_disks, get_disk_info, DiskDetectorError
from rpi_burner.models import Disk


def create_mock_diskutil_plist(disks: list[dict]) -> str:
    data = {
        "AllDisksAndPartitions": [
            {
                "Disk": {
                    "DeviceIdentifier": disk["device_id"],
                    "Size": disk["size"],
                    "Content": disk.get("content", "MS-DOS"),
                    "Removable": disk.get("removable", True),
                    "Ejectable": disk.get("ejectable", True),
                },
                "Partitions": disk.get("partitions", []),
            }
            for disk in disks
        ]
    }
    return plistlib.dumps(data).decode()


def test_list_external_disks_with_sd_card():
    mock_plist = create_mock_diskutil_plist([
        {
            "device_id": "disk4",
            "size": 32_000_000_000,
            "content": "MS-DOS",
            "removable": True,
            "ejectable": True,
            "partitions": [{"VolumeName": "NO NAME"}],
        }
    ])

    mock_result = MagicMock()
    mock_result.stdout = mock_plist
    mock_result.returncode = 0

    with patch("subprocess.run", return_value=mock_result):
        disks = list_external_disks()

    assert len(disks) == 1
    assert disks[0].device_path == "/dev/disk4"
    assert disks[0].volume_name == "NO NAME"
    assert disks[0].size_gb > 29 and disks[0].size_gb < 33


def test_list_external_disks_filters_non_removable():
    mock_plist = create_mock_diskutil_plist([
        {
            "device_id": "disk0",
            "size": 500_000_000_000,
            "content": "APFS",
            "removable": False,
            "ejectable": False,
        }
    ])

    mock_result = MagicMock()
    mock_result.stdout = mock_plist

    with patch("subprocess.run", return_value=mock_result):
        disks = list_external_disks()

    assert len(disks) == 0


def test_list_external_disks_multiple_disks():
    mock_plist = create_mock_diskutil_plist([
        {
            "device_id": "disk4",
            "size": 32_000_000_000,
            "partitions": [{"VolumeName": "SD Card"}],
        },
        {
            "device_id": "disk5",
            "size": 64_000_000_000,
            "partitions": [{"VolumeName": "USB Drive"}],
        },
    ])

    mock_result = MagicMock()
    mock_result.stdout = mock_plist

    with patch("subprocess.run", return_value=mock_result):
        disks = list_external_disks()

    assert len(disks) == 2
    assert disks[0].volume_name == "SD Card"
    assert disks[1].volume_name == "USB Drive"


def test_get_disk_info():
    plist_data = {
        "DeviceIdentifier": "disk4s1",
        "VolumeName": "NO NAME",
        "Size": 16_000_000_000,
        "Content": "MS-DOS",
        "Removable": True,
        "Ejectable": True,
    }
    mock_plist = plistlib.dumps(plist_data).decode()

    mock_result = MagicMock()
    mock_result.stdout = mock_plist

    with patch("subprocess.run", return_value=mock_result):
        disk = get_disk_info("/dev/disk4s1")

    assert disk.device_path == "/dev/disk4s1"
    assert disk.volume_name == "NO NAME"
    assert disk.size_bytes == 16_000_000_000


def test_get_disk_info_volume_name():
    plist_data = {
        "DeviceIdentifier": "disk4",
        "VolumeName": "",
        "Size": 32_000_000_000,
        "Content": "MS-DOS",
        "Removable": True,
        "Ejectable": True,
    }
    mock_plist = plistlib.dumps(plist_data).decode()

    mock_result = MagicMock()
    mock_result.stdout = mock_plist

    with patch("subprocess.run", return_value=mock_result):
        disk = get_disk_info("/dev/disk4")

    assert disk.volume_name == "Untitled"
