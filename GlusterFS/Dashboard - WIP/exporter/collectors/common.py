# Shared collector helpers

from pathlib import Path

IN_CONTAINER = Path("/.dockerenv").exists()


def host_command(command: list[str], *, network: bool = False) -> list[str]:
    """Run host tools through PID 1 namespaces when inside Docker."""
    if not IN_CONTAINER:
        return command
    namespaces = ["-m"]
    if network:
        namespaces.append("-n")
    return ["nsenter", "-t", "1", *namespaces, "--", *command]