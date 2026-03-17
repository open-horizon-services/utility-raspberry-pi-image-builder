"""Tests for cloud-init configuration support."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from rpi_burner.cloud_init import (
    DEFAULT_NETWORK_CONFIG,
    generate_meta_data,
    load_cloud_config,
    load_network_config,
    write_cloud_init_files,
)
from rpi_burner.exceptions import CloudInitError


@pytest.fixture(autouse=True)
def _mock_backend():
    mock = MagicMock()
    mock.write_file.side_effect = lambda path, content: path.write_text(content)
    with patch("rpi_burner.cloud_init.get_backend", return_value=mock):
        yield mock


def test_load_cloud_config_preserves_header(tmp_path: Path):
    config_file = tmp_path / "config.yaml"
    config_file.write_text("#cloud-config\nhostname: rpi-test\n")

    result = load_cloud_config(config_file)

    assert result.startswith("#cloud-config\n")


def test_load_cloud_config_adds_header_when_missing(tmp_path: Path):
    config_file = tmp_path / "config.yaml"
    config_file.write_text("hostname: rpi-test\n")

    result = load_cloud_config(config_file)

    assert result.startswith("#cloud-config\n")


def test_load_cloud_config_contains_values(tmp_path: Path):
    config_file = tmp_path / "config.yaml"
    config_file.write_text("#cloud-config\nhostname: rpi-test\n")

    result = load_cloud_config(config_file)

    assert "hostname: rpi-test" in result


def test_load_cloud_config_invalid_yaml(tmp_path: Path):
    config_file = tmp_path / "bad.yaml"
    config_file.write_text(":\n  - :\n  ]")

    with pytest.raises(CloudInitError, match="Invalid YAML"):
        load_cloud_config(config_file)


def test_load_cloud_config_not_a_dict(tmp_path: Path):
    config_file = tmp_path / "list.yaml"
    config_file.write_text("- item1\n- item2\n")

    with pytest.raises(CloudInitError, match="must be a YAML dictionary"):
        load_cloud_config(config_file)


def test_load_cloud_config_file_not_found():
    with pytest.raises(CloudInitError, match="Config file not found"):
        load_cloud_config(Path("/nonexistent/config.yaml"))


def test_write_cloud_init_files_creates_user_data(tmp_path: Path):
    write_cloud_init_files(tmp_path, "#cloud-config\nhostname: rpi\n")

    user_data = (tmp_path / "user-data").read_text()
    assert user_data == "#cloud-config\nhostname: rpi\n"


def test_write_cloud_init_files_generates_meta_data_with_instance_id(tmp_path: Path):
    write_cloud_init_files(tmp_path, "#cloud-config\nhostname: rpi\n")

    meta_data = (tmp_path / "meta-data").read_text()
    assert meta_data.startswith("instance-id: ")
    assert len(meta_data.strip().split(": ")[1]) == 36  # UUID length


def test_write_cloud_init_files_generates_unique_instance_ids(tmp_path: Path):
    id1 = generate_meta_data()
    id2 = generate_meta_data()
    assert id1 != id2


def test_write_cloud_init_files_writes_default_network_config(tmp_path: Path):
    write_cloud_init_files(tmp_path, "#cloud-config\nhostname: rpi\n")

    network_config = (tmp_path / "network-config").read_text()
    assert network_config == DEFAULT_NETWORK_CONFIG
    assert "dhcp4: true" in network_config
    assert "eth0:" in network_config


def test_write_cloud_init_files_writes_custom_network_config(tmp_path: Path):
    custom_net = "network:\n  version: 2\n  wifis:\n    wlan0:\n      dhcp4: true\n"
    write_cloud_init_files(tmp_path, "#cloud-config\nhostname: rpi\n", network_config=custom_net)

    network_config = (tmp_path / "network-config").read_text()
    assert network_config == custom_net


def test_write_cloud_init_files_bad_mount_point():
    with pytest.raises(CloudInitError, match="Mount point does not exist"):
        write_cloud_init_files(Path("/nonexistent/mount"), "data")


def test_load_network_config(tmp_path: Path):
    config_file = tmp_path / "network.yaml"
    config_file.write_text("network:\n  version: 2\n  ethernets:\n    eth0:\n      dhcp4: true\n")

    result = load_network_config(config_file)

    assert "eth0" in result
    assert "dhcp4: true" in result


def test_load_network_config_invalid_yaml(tmp_path: Path):
    config_file = tmp_path / "bad.yaml"
    config_file.write_text(":\n  - :\n  ]")

    with pytest.raises(CloudInitError, match="Invalid network config YAML"):
        load_network_config(config_file)


def test_load_network_config_not_a_dict(tmp_path: Path):
    config_file = tmp_path / "list.yaml"
    config_file.write_text("- item1\n- item2\n")

    with pytest.raises(CloudInitError, match="Network config must be a YAML dictionary"):
        load_network_config(config_file)


def test_load_network_config_file_not_found():
    with pytest.raises(CloudInitError, match="Network config file not found"):
        load_network_config(Path("/nonexistent/network.yaml"))
