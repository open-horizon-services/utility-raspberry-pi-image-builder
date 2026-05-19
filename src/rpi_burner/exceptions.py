"""Custom exceptions for rpi-burner."""


class DiskDetectorError(Exception):
    """Error detecting or listing disks."""


class DiskWriterError(Exception):
    """Error writing images or managing disk state."""


class CloudInitError(Exception):
    """Error with cloud-init configuration or injection."""
