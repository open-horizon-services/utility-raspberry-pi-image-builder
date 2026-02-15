"""CLI interface for rpi-burner."""
import sys
from pathlib import Path

import click
from rich.console import Console
from rich.prompt import Prompt
from rich.table import Table

from rpi_burner.cloud_init import (
    CloudInitError,
    get_boot_partition,
    load_cloud_config,
    mount_partition,
    write_cloud_init_files,
)
from rpi_burner.disk_detector import DiskDetectorError, get_disk_info, list_external_disks
from rpi_burner.disk_writer import DiskWriterError, burn_image, eject_disk, unmount_disk
from rpi_burner.models import Disk

console = Console()


def select_disk(interactive: bool, disk_path: str | None) -> Disk:
    """Select a disk interactively or from CLI argument."""
    if disk_path:
        return get_disk_info(disk_path)

    disks = list_external_disks()
    if not disks:
        console.print("[yellow]No removable disks found.[/yellow]")
        sys.exit(1)

    if len(disks) == 1:
        console.print(f"Using single disk: {disks[0].display_name}")
        return disks[0]

    console.print("\n[bold]Available disks:[/bold]\n")
    table = Table(show_header=False, box=None)
    table.add_column("Number", justify="right", style="cyan")
    table.add_column("Device")
    table.add_column("Name")
    table.add_column("Size", justify="right")

    for i, disk in enumerate(disks):
        size_str = f"{disk.size_gb:.2f} GB"
        table.add_row(f"[{i + 1}]", disk.device_path, disk.volume_name or "Untitled", size_str)

    console.print(table)

    while True:
        choice = Prompt.ask(
            "\nSelect disk number",
            choices=[str(i + 1) for i in range(len(disks))],
            default=str(len(disks)),
        )
        idx = int(choice) - 1
        if 0 <= idx < len(disks):
            return disks[idx]
        console.print("[red]Invalid selection[/red]")


@click.group()
@click.version_option(version="0.1.0")
def main():
    """Raspberry Pi image burner with Cloud Init support."""
    pass


@main.command("list")
def list_disks():
    """List all removable disks."""
    try:
        disks = list_external_disks()
    except DiskDetectorError as e:
        console.print(f"[red]Error:[/red] {e}", file=sys.stderr)
        sys.exit(1)

    if not disks:
        console.print("[yellow]No removable disks found.[/yellow]")
        return

    table = Table(title="Removable Disks")
    table.add_column("Device", style="cyan")
    table.add_column("Name", style="green")
    table.add_column("Size", justify="right")
    table.add_column("Filesystem")

    for disk in disks:
        table.add_row(
            disk.device_path,
            disk.volume_name or "Untitled",
            f"{disk.size_gb:.2f} GB",
            disk.file_system,
        )

    console.print(table)


@main.command("burn")
@click.argument("image", type=click.Path(exists=True, path_type=Path))
@click.option("--disk", "-d", "disk_path", help="Target disk device path (e.g., /dev/disk4)")
@click.option("--confirm", is_flag=True, help="Skip confirmation prompt (DANGEROUS)")
@click.option("--no-eject", is_flag=True, help="Don't eject disk after writing")
@click.option(
    "--cloud-init",
    "cloud_init_file",
    type=click.Path(exists=True, path_type=Path),
    help="Cloud-init config file (YAML)",
)
def burn(
    image: Path,
    disk_path: str | None,
    confirm: bool,
    no_eject: bool,
    cloud_init_file: Path | None,
):
    """Burn an image to a removable disk."""
    try:
        disk = select_disk(interactive=False, disk_path=disk_path)
    except DiskDetectorError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)

    console.print("\n[bold]Ready to burn:[/bold]")
    console.print(f"  Image: {image}")
    console.print(f"  Target: {disk.display_name} ({disk.size_gb:.2f} GB)")
    if cloud_init_file:
        console.print(f"  Cloud-Init: {cloud_init_file}")
    console.print()

    if not confirm:
        confirm_text = input('Type "yes" to confirm: ')
        if confirm_text.lower() != "yes":
            console.print("[yellow]Cancelled.[/yellow]")
            sys.exit(0)

    console.print("[yellow]Unmounting disk...[/yellow]")
    try:
        unmount_disk(disk.device_path)
    except DiskWriterError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)

    console.print("[bold green]Burning image... (this may take a while)[/bold green]")
    try:
        burn_image(str(image), disk.device_path)
    except DiskWriterError as e:
        console.print(f"[red]Error:[/red] {e}")
        sys.exit(1)

    console.print("[bold green]Write complete![/bold green]")

    if cloud_init_file:
        console.print("[yellow]Adding Cloud Init...[/yellow]")
        try:
            boot_part = get_boot_partition(disk.device_path)
            if not boot_part:
                console.print("[red]Could not find boot partition[/red]")
            else:
                mount_point = mount_partition(boot_part)
                user_data = load_cloud_config(cloud_init_file)
                write_cloud_init_files(mount_point, user_data)
                console.print(f"[bold green]Cloud Init files written to {mount_point}[/bold green]")
        except CloudInitError as e:
            console.print(f"[red]Cloud Init error:[/red] {e}")

    if not no_eject:
        console.print("Ejecting disk...")
        eject_disk(disk.device_path)
        console.print("[bold]Done! SD card is ready.[/bold]")


if __name__ == "__main__":
    main()
