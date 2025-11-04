import os
from pathlib import Path


def get_optimal_block_size(path: Path | str) -> int | None:
    """
    Retrieves the optimal transfer block size for the filesystem
    containing the given path.

    Args:
        path (Path | str): A path within the target filesystem (e.g., '/', '/tmp').

    Returns:
        int: The optimal transfer block size in bytes, or None if an error occurs.
    """
    try:
        stat_info = os.statvfs(path)
        # f_bsize: file system block size
        # f_frsize: fundamental file system block size (optimal transfer block size)
        return stat_info.f_frsize
    except OSError as e:
        print(f"Error getting filesystem info for {path}: {e}")
        return None


def safe_get_optimal_block_size(path: Path | str) -> int:
    try:
        return get_optimal_block_size(path) or 4096
    except:
        return 4096  # 4 KB
