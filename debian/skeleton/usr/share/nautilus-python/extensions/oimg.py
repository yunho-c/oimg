from __future__ import annotations

import subprocess
from typing import Iterable, List

from gi.repository import GObject, Nautilus


HELPER = "/opt/oimg/oimg-service"
SUPPORTED_MIME_TYPES = {
    "image/avif",
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/tiff",
    "image/webp",
}


class OimgMenuProvider(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, *args) -> List[Nautilus.MenuItem]:
        files = args[-1]
        paths = self._image_paths(files)
        if not paths:
            return []

        compress = Nautilus.MenuItem(
            name="OimgMenuProvider::CompressImage",
            label="Compress image",
            tip="",
            icon="oimg",
        )
        compress.connect("activate", self._activate, "compress", paths)

        lossless = Nautilus.MenuItem(
            name="OimgMenuProvider::CompressImageLossless",
            label="Compress image (lossless)",
            tip="",
            icon="oimg",
        )
        lossless.connect("activate", self._activate, "compress-lossless", paths)

        return [compress, lossless]

    def get_background_items(self, *args) -> List[Nautilus.MenuItem]:
        return []

    def _image_paths(self, files: Iterable[Nautilus.FileInfo]) -> List[str]:
        paths = []
        for file_info in files:
            if file_info.is_directory() or file_info.get_uri_scheme() != "file":
                return []
            if file_info.get_mime_type() not in SUPPORTED_MIME_TYPES:
                return []

            location = file_info.get_location()
            path = location.get_path() if location is not None else None
            if not path:
                return []
            paths.append(path)

        return paths

    def _activate(
        self,
        _menu: Nautilus.MenuItem,
        command: str,
        paths: List[str],
    ) -> None:
        subprocess.Popen(
            [HELPER, command, *paths],
            close_fds=True,
            start_new_session=True,
        )
