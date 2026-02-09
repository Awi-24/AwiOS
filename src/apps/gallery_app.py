"""
Gallery App – saved media from Messages.
Shows only photos and media that were unlocked or appeared in the Messages app.
"""

import json
from pathlib import Path
from typing import List, Dict, Any, Optional

import flet as ft

from src.core.app_base import App


# Extensions we treat as video; everything else is image/gif
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mov", ".avi", ".mkv"}
GIF_EXTENSIONS = {".gif"}


def _media_type(path: str) -> str:
    """Return 'video', 'gif', or 'image' from path."""
    p = Path(path)
    ext = p.suffix.lower()
    if ext in VIDEO_EXTENSIONS:
        return "video"
    if ext in GIF_EXTENSIONS:
        return "gif"
    return "image"


def _resolve_path(path: str, base_path: Optional[Path] = None) -> str:
    """Return path that Flet can load: try absolute resolve, else return as-is."""
    p = Path(path)
    if p.is_absolute() and p.exists():
        return path
    resolved = p.resolve()
    if resolved.exists():
        return str(resolved)
    if base_path is not None:
        alt = (base_path / path).resolve()
        if alt.exists():
            return str(alt)
    return path


class GalleryApp(App):
    """Gallery of media saved from Messages (unlocked or appeared in chats)."""

    def __init__(self):
        super().__init__()
        self.app_id = "gallery"
        self.name = "Gallery"
        self.icon = ft.icons.Icons.PHOTO_LIBRARY

        # List of stored paths (e.g. "assets/images/foo.png")
        self._media_paths: List[str] = []
        # Viewer state
        self._viewing_index: Optional[int] = None  # index into current list
        self._viewing_list: List[Dict[str, Any]] = []

    # ------------------------------------------------------------------
    # Storage (used by messages_app via unlock_media)
    # ------------------------------------------------------------------

    def _saves_dir(self) -> Path:
        base = getattr(self.engine, "saves_path", None) if self.engine else None
        return Path(base or "saves")

    def _storage_file(self) -> Path:
        return self._saves_dir() / "unlocked_media.json"

    def _load_media(self) -> None:
        path = self._storage_file()
        if not path.exists():
            self._media_paths = []
            return
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self._media_paths = data if isinstance(data, list) else []
        except Exception:
            self._media_paths = []

    def _save_media(self) -> None:
        path = self._storage_file()
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(self._media_paths, f, indent=2, ensure_ascii=False)
        except Exception:
            pass

    def unlock_media(self, media_path: str) -> None:
        """Add a media path to the gallery (called by messages_app when media is shown)."""
        if not media_path or media_path in self._media_paths:
            return
        self._media_paths.append(media_path)
        self._save_media()

    def remove_media(self, media_path: str) -> None:
        """Remove a path from the gallery."""
        if media_path in self._media_paths:
            self._media_paths.remove(media_path)
            self._save_media()
        if self.engine:
            self.engine.update_ui()

    def on_open(self) -> None:
        self._load_media()

    # ------------------------------------------------------------------
    # Data for UI: list of items with path, title, type; only existing files
    # ------------------------------------------------------------------

    def _base_path(self) -> Optional[Path]:
        if not self.engine:
            return None
        assets = getattr(self.engine, "assets_path", None)
        if assets:
            return Path(assets).resolve().parent
        return Path.cwd()

    def get_media_items(self) -> List[Dict[str, Any]]:
        """List of dicts: path, title, type (image|gif|video). Assets/images first, then unlocked from Messages."""
        base = self._base_path()
        items = []
        seen_paths: set = set()

        # 1) Add images from assets/images (same as background_manager) so gallery always shows something
        if self.engine and hasattr(self.engine, "background_manager"):
            for bg in self.engine.background_manager.get_available_backgrounds():
                p = bg.get("path", "")
                if not p or p in seen_paths:
                    continue
                resolved = _resolve_path(p, base)
                if not Path(resolved).exists():
                    continue
                seen_paths.add(p)
                items.append({
                    "path": resolved,
                    "title": bg.get("name", Path(p).stem.replace("_", " ").title()),
                    "type": _media_type(p),
                })

        # 2) Add unlocked media from Messages
        for p in self._media_paths:
            if p in seen_paths:
                continue
            resolved = _resolve_path(p, base)
            if not Path(resolved).exists():
                continue
            seen_paths.add(p)
            items.append({
                "path": resolved,
                "title": Path(p).stem.replace("_", " ").title(),
                "type": _media_type(p),
            })
        return items

    # ------------------------------------------------------------------
    # Render
    # ------------------------------------------------------------------

    def render(self, page: ft.Page):
        try:
            if self._viewing_index is not None and 0 <= self._viewing_index < len(self._viewing_list):
                root = self._build_viewer()
            else:
                root = self._build_grid()
            if root is None:
                return self._fallback_ui()
            return root
        except Exception as e:
            print(f"[Gallery] render error: {e}")
            return self._fallback_ui()

    def _fallback_ui(self) -> ft.Control:
        """Minimal UI that always renders (no gradients, no icons)."""
        return ft.Container(
            content=ft.Column(
                [
                    ft.Container(
                        content=ft.Row(
                            [
                                ft.TextButton("< Back", on_click=lambda _: self.close()),
                                ft.Text("Gallery", size=20, color=ft.Colors.WHITE),
                                ft.Container(expand=True),
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        ),
                        bgcolor="#5C6BC0",
                        padding=12,
                    ),
                    ft.Container(
                        content=ft.Text("Gallery loaded.", size=16, color=ft.Colors.BLACK),
                        padding=20,
                        expand=True,
                        bgcolor="#CFD8DC",
                    ),
                ],
                spacing=0,
                expand=True,
            ),
            expand=True,
        )

    def _build_grid(self) -> ft.Control:
        # Header: solid color only (no gradient) so it always renders
        header = ft.Container(
            content=ft.Row(
                [
                    ft.TextButton("< Back", on_click=lambda _: self.close()),
                    ft.Text("Gallery", size=22, weight=ft.FontWeight.W_600, color=ft.Colors.WHITE),
                    ft.Container(expand=True),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            ),
            padding=ft.padding.symmetric(horizontal=16, vertical=16),
            bgcolor="#5C6BC0",
        )

        items = self.get_media_items()

        if not items:
            content = ft.Container(
                content=ft.Column(
                    [
                        ft.Text("No media yet", size=20, weight=ft.FontWeight.W_600, color="#37474F"),
                        ft.Text(
                            "Photos from assets/images and Messages will appear here.",
                            size=15,
                            color="#78909C",
                            text_align=ft.TextAlign.CENTER,
                        ),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=16,
                    alignment=ft.MainAxisAlignment.CENTER,
                ),
                expand=True,
                bgcolor="#ECEFF1",
            )
        else:
            cell_size = 110
            rows = []
            for i in range(0, len(items), 3):
                row_items = items[i : i + 3]
                row_cells = []
                for j, item in enumerate(row_items):
                    row_cells.append(
                        ft.Container(
                            content=self._thumbnail(item, i + j, items),
                            width=cell_size,
                            height=cell_size,
                        )
                    )
                while len(row_cells) < 3:
                    row_cells.append(ft.Container(width=cell_size, height=cell_size))
                rows.append(ft.Row(row_cells, spacing=10))
            content = ft.Container(
                content=ft.Column(rows, spacing=10, scroll=ft.ScrollMode.AUTO),
                padding=ft.padding.symmetric(horizontal=16, vertical=16),
                expand=True,
                bgcolor="#ECEFF1",
            )

        return ft.Column([header, content], spacing=0, expand=True)

    def _thumbnail(self, item: Dict[str, Any], index: int, full_list: List[Dict[str, Any]]) -> ft.Control:
        path = item["path"]
        media_type = item["type"]

        if media_type == "video":
            content = ft.Stack(
                [
                    ft.Container(
                        bgcolor=ft.Colors.with_opacity(0.25, "#37474F"),
                        border_radius=12,
                        expand=True,
                    ),
                    ft.Container(
                        content=ft.Icon(ft.icons.Icons.PLAY_CIRCLE_FILLED, size=44, color=ft.Colors.WHITE70),
                        alignment=ft.Alignment.CENTER,
                        expand=True,
                    ),
                ],
                expand=True,
            )
        else:
            content = ft.Container(
                content=ft.Image(src=path, fit="cover"),
                border_radius=12,
                clip_behavior=ft.ClipBehavior.ANTI_ALIAS,
                expand=True,
            )

        return ft.GestureDetector(
            content=ft.Container(
                content=content,
                border_radius=8,
                clip_behavior=ft.ClipBehavior.ANTI_ALIAS,
            ),
            on_tap=lambda _: self._open_viewer(index, full_list),
        )

    def _open_viewer(self, index: int, items: List[Dict[str, Any]]) -> None:
        self._viewing_list = items
        self._viewing_index = index
        if self.engine:
            self.engine.update_ui()

    def _build_viewer(self) -> ft.Control:
        item = self._viewing_list[self._viewing_index]
        path = item["path"]
        title = item["title"]
        media_type = item["type"]
        total = len(self._viewing_list)
        idx = self._viewing_index
        can_prev = idx > 0
        can_next = idx < total - 1

        top_bar = ft.Container(
            content=ft.Row([
                ft.IconButton(
                    icon=ft.icons.Icons.ARROW_BACK,
                    icon_color=ft.Colors.WHITE,
                    icon_size=26,
                    on_click=lambda _: self._close_viewer(),
                    style=ft.ButtonStyle(shape=ft.CircleBorder(), overlay_color=ft.Colors.with_opacity(0.2, ft.Colors.WHITE)),
                ),
                ft.Container(expand=True),
                ft.Container(
                    content=ft.Text(f"{idx + 1} / {total}", size=15, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE70),
                    padding=ft.padding.symmetric(horizontal=14, vertical=10),
                    border_radius=20,
                    bgcolor=ft.Colors.with_opacity(0.25, ft.Colors.WHITE),
                ),
            ]),
            padding=ft.padding.symmetric(horizontal=12, vertical=12),
            gradient=ft.LinearGradient(
                colors=[ft.Colors.with_opacity(0.85, "#212121"), ft.Colors.with_opacity(0.7, "#37474F")],
                begin=ft.Alignment.TOP_LEFT,
                end=ft.Alignment.BOTTOM_RIGHT,
            ),
        )

        if media_type == "video":
            center_content = ft.Container(
                content=ft.Column(
                    [
                        ft.Icon(ft.icons.Icons.PLAY_CIRCLE_FILLED, size=80, color=ft.Colors.WHITE54),
                        ft.Text("Video playback not implemented", size=15, color=ft.Colors.WHITE70),
                        ft.Container(height=8),
                        ft.Text(path, size=12, color=ft.Colors.WHITE38, no_wrap=False, max_lines=3),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=16,
                ),
                alignment=ft.Alignment.CENTER,
                expand=True,
            )
        else:
            center_content = ft.Container(
                content=ft.Image(src=path, fit="contain"),
                alignment=ft.Alignment.CENTER,
                expand=True,
            )

        nav_row = ft.Row(
            [
                ft.IconButton(
                    icon=ft.icons.Icons.CHEVRON_LEFT,
                    icon_color=ft.Colors.WHITE if can_prev else ft.Colors.WHITE24,
                    icon_size=32,
                    on_click=lambda _: self._viewer_prev() if can_prev else None,
                    disabled=not can_prev,
                    style=ft.ButtonStyle(shape=ft.CircleBorder(), overlay_color=ft.Colors.with_opacity(0.15, ft.Colors.WHITE)),
                ),
                ft.Container(content=center_content, expand=True),
                ft.IconButton(
                    icon=ft.icons.Icons.CHEVRON_RIGHT,
                    icon_color=ft.Colors.WHITE if can_next else ft.Colors.WHITE24,
                    icon_size=32,
                    on_click=lambda _: self._viewer_next() if can_next else None,
                    disabled=not can_next,
                    style=ft.ButtonStyle(shape=ft.CircleBorder(), overlay_color=ft.Colors.with_opacity(0.15, ft.Colors.WHITE)),
                ),
            ],
            expand=True,
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        )

        bottom_bar = ft.Container(
            content=ft.Text(title, size=17, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE, text_align=ft.TextAlign.CENTER),
            padding=ft.padding.symmetric(horizontal=24, vertical=16),
            gradient=ft.LinearGradient(
                colors=[ft.Colors.with_opacity(0.6, "#37474F"), ft.Colors.with_opacity(0.8, "#212121")],
                begin=ft.Alignment.TOP_CENTER,
                end=ft.Alignment.BOTTOM_CENTER,
            ),
        )

        return ft.Column(
            [
                top_bar,
                ft.Container(content=nav_row, expand=True, bgcolor="#121212"),
                bottom_bar,
            ],
            spacing=0,
            expand=True,
        )

    def _close_viewer(self) -> None:
        self._viewing_index = None
        self._viewing_list = []
        if self.engine:
            self.engine.update_ui()

    def _viewer_prev(self) -> None:
        if self._viewing_index is None or self._viewing_index <= 0:
            return
        self._viewing_index -= 1
        if self.engine:
            self.engine.update_ui()

    def _viewer_next(self) -> None:
        if self._viewing_index is None or self._viewing_list is None:
            return
        if self._viewing_index >= len(self._viewing_list) - 1:
            return
        self._viewing_index += 1
        if self.engine:
            self.engine.update_ui()
