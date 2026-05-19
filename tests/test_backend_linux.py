"""Tests for Linux disk detection backend."""

import json
import subprocess
from unittest.mock import MagicMock, patch

import pytest

from rpi_burner.backends.linux import LinuxBackend
from rpi_burner.exceptions import CloudInitError, DiskDetectorError, DiskWriterError


@pytest.fixture(autouse=True)
def _mock_as_root():
    with patch("os.geteuid", return_value=0):
        yield


def create_mock_lsblk_output(devices: list[dict]) -> str:
    return json.dumps({"blockdevices": devices})


def test_list_external_disks_sd_card():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sdb",
                "size": 32_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": True,
                "tran": "usb",
                "fstype": None,
                "label": None,
                "children": [
                    {
                        "name": "sdb1",
                        "size": 268_435_456,
                        "type": "part",
                        "mountpoint": "/media/user/boot",
                        "rm": True,
                        "tran": None,
                        "fstype": "vfat",
                        "label": "boot",
                    },
                    {
                        "name": "sdb2",
                        "size": 31_000_000_000,
                        "type": "part",
                        "mountpoint": "/media/user/rootfs",
                        "rm": True,
                        "tran": None,
                        "fstype": "ext4",
                        "label": "rootfs",
                    },
                ],
            }
        ]
    )

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        disks = backend.list_external_disks()

    assert len(disks) == 1
    assert disks[0].device_path == "/dev/sdb"
    assert disks[0].volume_name == "rootfs"
    assert disks[0].size_bytes == 32_000_000_000
    assert disks[0].is_removable is True


def test_list_external_disks_filters_internal():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sda",
                "size": 500_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": False,
                "tran": "sata",
                "fstype": None,
                "label": None,
            },
            {
                "name": "nvme0n1",
                "size": 1_000_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": False,
                "tran": "nvme",
                "fstype": None,
                "label": None,
            },
        ]
    )

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        disks = backend.list_external_disks()

    assert len(disks) == 0


def test_list_external_disks_mmc_transport():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "mmcblk0",
                "size": 16_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": False,
                "tran": "mmc",
                "fstype": None,
                "label": None,
                "children": [
                    {
                        "name": "mmcblk0p1",
                        "size": 268_435_456,
                        "type": "part",
                        "mountpoint": None,
                        "rm": False,
                        "tran": None,
                        "fstype": "vfat",
                        "label": "boot",
                    },
                ],
            }
        ]
    )

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        disks = backend.list_external_disks()

    assert len(disks) == 1
    assert disks[0].device_path == "/dev/mmcblk0"


def test_list_external_disks_multiple():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sdb",
                "size": 32_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": True,
                "tran": "usb",
                "fstype": None,
                "label": None,
                "children": [{"name": "sdb1", "fstype": "vfat", "label": "SD Card"}],
            },
            {
                "name": "sdc",
                "size": 64_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": True,
                "tran": "usb",
                "fstype": None,
                "label": None,
                "children": [{"name": "sdc1", "fstype": "ext4", "label": "USB Drive"}],
            },
        ]
    )

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        disks = backend.list_external_disks()

    assert len(disks) == 2
    assert disks[0].volume_name == "SD Card"
    assert disks[1].volume_name == "USB Drive"


def test_list_external_disks_no_children():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sdb",
                "size": 32_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": True,
                "tran": "usb",
                "fstype": None,
                "label": None,
            }
        ]
    )

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        disks = backend.list_external_disks()

    assert len(disks) == 1
    assert disks[0].volume_name == ""
    assert disks[0].file_system == "Unknown"


def test_get_disk_info():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sdb",
                "size": 32_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": True,
                "tran": "usb",
                "fstype": None,
                "label": None,
                "children": [
                    {"name": "sdb1", "fstype": "vfat", "label": "boot"},
                    {"name": "sdb2", "fstype": "ext4", "label": "rootfs"},
                ],
            }
        ]
    )

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        disk = backend.get_disk_info("/dev/sdb")

    assert disk.device_path == "/dev/sdb"
    assert disk.volume_name == "rootfs"
    assert disk.size_bytes == 32_000_000_000
    assert disk.is_removable is True


def test_get_disk_info_no_label():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sdb",
                "size": 32_000_000_000,
                "type": "disk",
                "mountpoint": None,
                "rm": True,
                "tran": "usb",
                "fstype": None,
                "label": None,
            }
        ]
    )

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        disk = backend.get_disk_info("/dev/sdb")

    assert disk.volume_name == "Untitled"


def test_get_disk_info_not_found():
    mock_json = create_mock_lsblk_output([])

    mock_result = MagicMock()
    mock_result.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", return_value=mock_result):
        with pytest.raises(DiskDetectorError, match="No device found"):
            backend.get_disk_info("/dev/sdz")


def test_unmount_disk():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sdb",
                "mountpoint": None,
                "children": [
                    {"name": "sdb1", "mountpoint": "/media/user/boot"},
                    {"name": "sdb2", "mountpoint": "/media/user/rootfs"},
                    {"name": "sdb3", "mountpoint": None},
                ],
            }
        ]
    )

    mock_lsblk = MagicMock()
    mock_lsblk.stdout = mock_json

    mock_umount = MagicMock()

    backend = LinuxBackend()
    with patch("subprocess.run", side_effect=[mock_lsblk, mock_umount, mock_umount]) as mock_run:
        backend.unmount_disk("/dev/sdb")

    umount_calls = [c for c in mock_run.call_args_list if c[0][0][0] == "umount"]
    assert len(umount_calls) == 2
    assert umount_calls[0][0][0] == ["umount", "/dev/sdb1"]
    assert umount_calls[1][0][0] == ["umount", "/dev/sdb2"]


def test_burn_image(tmp_path):
    image_file = tmp_path / "test.img"
    image_file.write_bytes(b"\x00" * 1024)

    backend = LinuxBackend()
    with patch("subprocess.run") as mock_run:
        backend.burn_image(str(image_file), "/dev/sdb")

    dd_call = mock_run.call_args_list[0]
    cmd = dd_call[0][0]
    assert cmd[0] == "dd"
    assert f"if={image_file}" in cmd
    assert "of=/dev/sdb" in cmd
    assert "bs=1M" in cmd
    assert "status=progress" in cmd


def test_burn_image_file_not_found():
    backend = LinuxBackend()
    with pytest.raises(DiskWriterError, match="Image file not found"):
        backend.burn_image("/nonexistent/image.img", "/dev/sdb")


def test_get_boot_partition():
    mock_json = json.dumps(
        {
            "blockdevices": [
                {
                    "name": "sdb",
                    "fstype": None,
                    "children": [
                        {"name": "sdb1", "fstype": "vfat"},
                        {"name": "sdb2", "fstype": "ext4"},
                    ],
                }
            ]
        }
    )

    mock_sync = MagicMock()
    mock_partprobe = MagicMock()
    mock_udevadm = MagicMock()
    mock_lsblk = MagicMock()
    mock_lsblk.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", side_effect=[mock_sync, mock_partprobe, mock_udevadm, mock_lsblk]):
        result = backend.get_boot_partition("/dev/sdb")

    assert result == "/dev/sdb1"


def test_get_boot_partition_no_vfat():
    mock_json = json.dumps(
        {
            "blockdevices": [
                {
                    "name": "sdb",
                    "fstype": None,
                    "children": [
                        {"name": "sdb1", "fstype": "ext4"},
                    ],
                }
            ]
        }
    )

    mock_sync = MagicMock()
    mock_partprobe = MagicMock()
    mock_udevadm = MagicMock()
    mock_lsblk = MagicMock()
    mock_lsblk.stdout = mock_json

    backend = LinuxBackend()
    with patch("subprocess.run", side_effect=[mock_sync, mock_partprobe, mock_udevadm, mock_lsblk]):
        result = backend.get_boot_partition("/dev/sdb")

    assert result is None


def test_mount_partition(tmp_path):
    partition_path = "/dev/sdb1"

    backend = LinuxBackend()
    with (
        patch("subprocess.run") as mock_run,
        patch("pathlib.Path.mkdir") as mock_mkdir,
    ):
        result = backend.mount_partition(partition_path)

    assert str(result) == "/tmp/rpi-burner-boot-sdb1"
    mock_mkdir.assert_called_once_with(exist_ok=True)
    mock_run.assert_called_once_with(
        ["mount", "/dev/sdb1", "/tmp/rpi-burner-boot-sdb1"],
        check=True,
        capture_output=True,
        text=True,
    )


def test_mount_partition_failure():
    backend = LinuxBackend()
    with (
        patch(
            "subprocess.run", side_effect=subprocess.CalledProcessError(1, "mount", stderr="busy")
        ),
        patch("pathlib.Path.mkdir"),
    ):
        with pytest.raises(CloudInitError, match="Failed to mount"):
            backend.mount_partition("/dev/sdb1")


def test_eject_disk_with_eject():
    mock_lsblk = MagicMock()
    mock_lsblk.stdout = create_mock_lsblk_output(
        [
            {"name": "sdb", "mountpoint": None, "children": []},
        ]
    )
    mock_eject = MagicMock()

    backend = LinuxBackend()
    with patch("subprocess.run", side_effect=[mock_lsblk, mock_eject]):
        backend.eject_disk("/dev/sdb")


def test_eject_disk_fallback_to_udisksctl():
    mock_lsblk = MagicMock()
    mock_lsblk.stdout = create_mock_lsblk_output(
        [
            {"name": "sdb", "mountpoint": None, "children": []},
        ]
    )

    def side_effect_fn(cmd, **kwargs):
        if cmd[0] == "lsblk":
            return mock_lsblk
        if cmd[0] == "eject":
            raise FileNotFoundError("eject not found")
        return MagicMock()

    backend = LinuxBackend()
    with patch("subprocess.run", side_effect=side_effect_fn):
        backend.eject_disk("/dev/sdb")


def test_eject_disk_all_fail():
    mock_lsblk = MagicMock()
    mock_lsblk.stdout = create_mock_lsblk_output(
        [
            {"name": "sdb", "mountpoint": None, "children": []},
        ]
    )

    def side_effect_fn(cmd, **kwargs):
        if cmd[0] == "lsblk":
            return mock_lsblk
        raise FileNotFoundError(f"{cmd[0]} not found")

    backend = LinuxBackend()
    with patch("subprocess.run", side_effect=side_effect_fn):
        with pytest.raises(DiskWriterError, match="Failed to eject"):
            backend.eject_disk("/dev/sdb")


def test_is_sysfs_removable():
    backend = LinuxBackend()
    with patch("pathlib.Path.read_text", return_value="1\n"):
        assert backend._is_sysfs_removable("sdb") is True

    with patch("pathlib.Path.read_text", return_value="0\n"):
        assert backend._is_sysfs_removable("sdb") is False

    with patch("pathlib.Path.read_text", side_effect=OSError):
        assert backend._is_sysfs_removable("sdb") is False


def test_elevate_as_root():
    with patch("os.geteuid", return_value=0):
        assert LinuxBackend._elevate(["dd", "if=x", "of=y"]) == ["dd", "if=x", "of=y"]


def test_elevate_as_non_root():
    with patch("os.geteuid", return_value=1000):
        assert LinuxBackend._elevate(["dd", "if=x", "of=y"]) == [
            "sudo",
            "dd",
            "if=x",
            "of=y",
        ]


def test_burn_image_uses_sudo_when_not_root(tmp_path):
    image_file = tmp_path / "test.img"
    image_file.write_bytes(b"\x00" * 1024)

    backend = LinuxBackend()
    with patch("os.geteuid", return_value=1000), patch("subprocess.run") as mock_run:
        backend.burn_image(str(image_file), "/dev/sdb")

    dd_call = mock_run.call_args_list[0]
    cmd = dd_call[0][0]
    assert cmd[:2] == ["sudo", "dd"]
    assert "dd" in cmd


def test_unmount_uses_sudo_when_not_root():
    mock_json = create_mock_lsblk_output(
        [
            {
                "name": "sdb",
                "mountpoint": None,
                "children": [
                    {"name": "sdb1", "mountpoint": "/media/user/boot"},
                ],
            }
        ]
    )

    mock_lsblk = MagicMock()
    mock_lsblk.stdout = mock_json
    mock_umount = MagicMock()

    backend = LinuxBackend()
    with (
        patch("os.geteuid", return_value=1000),
        patch("subprocess.run", side_effect=[mock_lsblk, mock_umount]) as mock_run,
    ):
        backend.unmount_disk("/dev/sdb")

    umount_call = mock_run.call_args_list[1]
    assert umount_call[0][0] == ["sudo", "umount", "/dev/sdb1"]


def test_mount_partition_uses_sudo_when_not_root():
    backend = LinuxBackend()
    with (
        patch("os.geteuid", return_value=1000),
        patch("subprocess.run") as mock_run,
        patch("pathlib.Path.mkdir"),
    ):
        backend.mount_partition("/dev/sdb1")

    mock_run.assert_called_once_with(
        ["sudo", "mount", "/dev/sdb1", "/tmp/rpi-burner-boot-sdb1"],
        check=True,
        capture_output=True,
        text=True,
    )


def test_write_file_uses_sudo_tee_when_not_root(tmp_path):
    backend = LinuxBackend()
    target = tmp_path / "user-data"

    with (
        patch("os.geteuid", return_value=1000),
        patch("subprocess.run") as mock_run,
    ):
        backend.write_file(target, "#cloud-config\nhostname: rpi\n")

    mock_run.assert_called_once_with(
        ["sudo", "tee", str(target)],
        input="#cloud-config\nhostname: rpi\n",
        check=True,
        capture_output=True,
        text=True,
    )


def test_write_file_no_sudo_when_root(tmp_path):
    backend = LinuxBackend()
    target = tmp_path / "user-data"

    with (
        patch("os.geteuid", return_value=0),
        patch("subprocess.run") as mock_run,
    ):
        backend.write_file(target, "content")

    mock_run.assert_called_once_with(
        ["tee", str(target)],
        input="content",
        check=True,
        capture_output=True,
        text=True,
    )


def test_write_file_raises_cloud_init_error_on_failure(tmp_path):
    backend = LinuxBackend()
    target = tmp_path / "user-data"

    with (
        patch("os.geteuid", return_value=1000),
        patch(
            "subprocess.run",
            side_effect=subprocess.CalledProcessError(1, "tee", stderr="Permission denied"),
        ),
        pytest.raises(CloudInitError, match="Failed to write"),
    ):
        backend.write_file(target, "content")
