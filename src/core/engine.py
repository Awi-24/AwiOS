"""
MobileEngine – core engine managing global state, apps, and UI.
"""

import json
import os
from pathlib import Path
from typing import Dict, Optional, Any, List
from dataclasses import dataclass, asdict
from enum import Enum
import importlib
from datetime import datetime
import flet as ft
from src.core.app_base import App
from src.utils.i18n import I18n
from src.utils.asset_manager import AssetManager
from src.core.background_manager import BackgroundManager
from src.core.chat_manager import ChatManager


class GameState(Enum):
    LOCK_SCREEN = "lock_screen"
    HOME_SCREEN = "home_screen"
    IN_APP = "in_app"
    MENU = "menu"


@dataclass
class GlobalState:
    current_chapter: str = "chapter_01"
    current_node: str = "start"
    variables: Dict[str, Any] = None
    dialogue_history: List[Dict[str, Any]] = None
    unlocked_content: Dict[str, bool] = None
    settings: Dict[str, Any] = None

    def __post_init__(self):
        if self.variables is None:
            self.variables = {}
        if self.dialogue_history is None:
            self.dialogue_history = []
        if self.unlocked_content is None:
            self.unlocked_content = {}
        if self.settings is None:
            self.settings = {
                "language": "en_US",
                "text_speed": 1.0,
                "auto_read": False,
                "skip_read": True,
                "volume_music": 0.7,
                "volume_sfx": 0.8,
                "volume_voice": 1.0,
            }


class MobileEngine:
    """Core engine: global state, app registry, UI lifecycle."""

    def __init__(self, assets_path: str = "assets", saves_path: str = "saves",
                 locales_path: str = "locales"):
        self.assets_path = Path(assets_path)
        self.saves_path = Path(saves_path)
        self.saves_path.mkdir(exist_ok=True)

        self.state = GlobalState()
        self._load_settings()

        self.apps: Dict[str, App] = {}
        self.current_app: Optional[App] = None
        self.current_state = GameState.LOCK_SCREEN
        self.page: Optional[ft.Page] = None
        self.notifications: List[Dict[str, Any]] = []

        self.plugin_path = Path(__file__).resolve().parent.parent / "apps"
        self._apps_loaded = False

        self.i18n = I18n(locales_path=locales_path,
                         default_language=self.state.settings.get("language", "en_US"))
        self.asset_manager = AssetManager(assets_path=str(self.assets_path))
        self.background_manager = BackgroundManager(self)
        self.chat_manager = ChatManager(self)

    # ------------------------------------------------------------------
    # Persistent settings
    # ------------------------------------------------------------------

    def _settings_file(self) -> Path:
        return self.saves_path / "settings.json"

    def _load_settings(self):
        try:
            path = self._settings_file()
            if path.exists():
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if isinstance(data, dict):
                    self.state.settings.update(data)
        except Exception as e:
            print(f"Error loading settings: {e}")

    def save_settings(self):
        try:
            path = self._settings_file()
            path.parent.mkdir(exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                json.dump(self.state.settings, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving settings: {e}")

    def get_setting(self, name: str, default: Any = None) -> Any:
        return (self.state.settings or {}).get(name, default)

    def set_setting(self, name: str, value: Any):
        if self.state.settings is None:
            self.state.settings = {}
        self.state.settings[name] = value
        self.save_settings()

    # ------------------------------------------------------------------
    # State / history
    # ------------------------------------------------------------------

    def _get_state_snapshot(self) -> Dict[str, Any]:
        data = asdict(self.state)
        data["dialogue_history"] = []
        return data

    def get_variable(self, name: str, default: Any = None) -> Any:
        return self.state.variables.get(name, default)

    def set_variable(self, name: str, value: Any):
        self.state.variables[name] = value

    def add_to_history(self, node_data: Dict[str, Any]):
        self.state.dialogue_history.append({
            "node": node_data.get("id", ""),
            "state_snapshot": self._get_state_snapshot(),
            "timestamp": len(self.state.dialogue_history),
        })

    def rollback(self, steps: int = 1) -> bool:
        if len(self.state.dialogue_history) < steps:
            return False
        for _ in range(steps):
            if self.state.dialogue_history:
                self.state.dialogue_history.pop()
        if self.state.dialogue_history:
            history = self.state.dialogue_history
            last_snapshot = history[-1]["state_snapshot"]
            self.state = GlobalState(**last_snapshot)
            self.state.dialogue_history = history
        else:
            self.state = GlobalState()
        if self.page:
            self.update_ui()
        return True

    def check_condition(self, condition: Dict[str, Any]) -> bool:
        for var_name, condition_value in condition.items():
            current_value = self.get_variable(var_name, 0)
            if isinstance(condition_value, str):
                if condition_value.startswith(">="):
                    if current_value < float(condition_value[2:]):
                        return False
                elif condition_value.startswith("<="):
                    if current_value > float(condition_value[2:]):
                        return False
                elif condition_value.startswith("=="):
                    if str(current_value) != condition_value[2:]:
                        return False
                elif condition_value.startswith("!="):
                    if str(current_value) == condition_value[2:]:
                        return False
                elif condition_value.startswith(">"):
                    if current_value <= float(condition_value[1:]):
                        return False
                elif condition_value.startswith("<"):
                    if current_value >= float(condition_value[1:]):
                        return False
            else:
                if current_value != condition_value:
                    return False
        return True

    # ------------------------------------------------------------------
    # App registration / lifecycle
    # ------------------------------------------------------------------

    def register_app(self, app: App):
        if app.app_id in self.apps:
            return
        app.set_engine(self)
        self.apps[app.app_id] = app

    def load_apps(self):
        if self._apps_loaded:
            return
        if not self.plugin_path.exists():
            self._apps_loaded = True
            return
        for app_file in self.plugin_path.glob("*.py"):
            if app_file.name.startswith("__"):
                continue
            try:
                module_name = f"src.apps.{app_file.stem}"
                module = importlib.import_module(module_name)
                for attr_name in dir(module):
                    attr = getattr(module, attr_name)
                    if isinstance(attr, type) and issubclass(attr, App) and attr != App:
                        self.register_app(attr())
            except Exception as e:
                print(f"Error loading plugin {app_file}: {e}")
        self._apps_loaded = True

    def open_app(self, app_id: str) -> bool:
        if app_id not in self.apps:
            return False
        if self.current_app:
            self.current_app.on_close()
        self.current_app = self.apps[app_id]
        self.current_state = GameState.IN_APP
        self.current_app.on_open()
        if self.page:
            self.update_ui()
        return True

    def close_app(self):
        if self.current_app:
            self.current_app.on_close()
            self.current_app = None
        self.current_state = GameState.HOME_SCREEN
        if self.page:
            self.update_ui()

    def add_notification(self, app_id: str, title: str, content: str, icon: Optional[str] = None):
        self.notifications.append({
            "app_id": app_id, "title": title, "content": content,
            "icon": icon, "timestamp": len(self.notifications),
        })
        if self.page:
            self.update_ui()

    def get_i18n(self) -> I18n:
        return self.i18n

    def get_asset_manager(self) -> AssetManager:
        return self.asset_manager

    # ------------------------------------------------------------------
    # Save / Load game
    # ------------------------------------------------------------------

    def save_game(self, slot: int = 0) -> bool:
        save_file = self.saves_path / f"save_{slot:02d}.json"
        try:
            save_data = {
                "state": asdict(self.state),
                "current_app": self.current_app.app_id if self.current_app else None,
                "notifications": self.notifications,
            }
            with open(save_file, "w", encoding="utf-8") as f:
                json.dump(save_data, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"Error saving game: {e}")
            return False

    def load_game(self, slot: int = 0) -> bool:
        save_file = self.saves_path / f"save_{slot:02d}.json"
        if not save_file.exists():
            return False
        try:
            with open(save_file, "r", encoding="utf-8") as f:
                save_data = json.load(f)
            self.state = GlobalState(**save_data["state"])
            self.notifications = save_data.get("notifications", [])
            current_app_id = save_data.get("current_app")
            if current_app_id and current_app_id in self.apps:
                self.open_app(current_app_id)
            if self.page:
                self.update_ui()
            return True
        except Exception as e:
            print(f"Error loading game: {e}")
            return False

    # ------------------------------------------------------------------
    # UI Rendering
    # ------------------------------------------------------------------

    def update_ui(self):
        if not self.page:
            return
        self.page.controls.clear()

        if self.current_state == GameState.LOCK_SCREEN:
            content = self._render_lock_screen()
        elif self.current_state == GameState.HOME_SCREEN:
            content = self._render_home_screen()
        elif self.current_state == GameState.IN_APP and self.current_app:
            try:
                content = self.current_app.render(self.page)
            except Exception as e:
                print(f"[Engine] App render error: {e}")
                content = ft.Container(
                    content=ft.Column([
                        ft.Text("Could not load app", size=18, color=ft.Colors.WHITE),
                        ft.Text(str(e), size=12, color=ft.Colors.WHITE70),
                    ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                    alignment=ft.Alignment.CENTER,
                    expand=True,
                )
            if content is not None:
                self.page.add(self._wrap_content_with_background(content))
                self.page.update()
                if hasattr(self.current_app, "after_render"):
                    self.current_app.after_render(self.page)
                return
            # Fallback if app returned None
            content = ft.Container(content=ft.Text("App returned no content", color=ft.Colors.WHITE), expand=True)
        else:
            content = ft.Container()

        self.page.add(self._wrap_content_with_background(content))
        self.page.update()

    def _wrap_content_with_background(self, content: ft.Control) -> ft.Control:
        # Give app content explicit size so it always gets layout (fixes blank gallery)
        try:
            w = getattr(self.page.window, "width", None) or 500
            h = getattr(self.page.window, "height", None) or 1000
        except Exception:
            w, h = 500, 1000
        app_container = ft.Container(content=content, expand=True, width=w, height=h)
        return ft.Stack([
            ft.Image(
                src=self.background_manager.get_current_background_path(),
                width=float("inf"), height=float("inf"), fit="cover", opacity=0.4, expand=True,
            ),
            ft.Container(
                width=float("inf"), height=float("inf"),
                gradient=ft.LinearGradient(
                    colors=[ft.Colors.with_opacity(0.3, ft.Colors.BLACK), ft.Colors.with_opacity(0.2, ft.Colors.BLACK)],
                    begin=ft.Alignment.TOP_CENTER, end=ft.Alignment.BOTTOM_CENTER,
                ),
                expand=True,
            ),
            app_container,
        ], expand=True)

    # ------------------------------------------------------------------
    # Lock screen
    # ------------------------------------------------------------------

    def _render_lock_screen(self) -> ft.Control:
        now = datetime.now()
        return ft.Container(
            content=ft.Column([
                ft.Container(height=100),
                ft.Column([
                    ft.Text(now.strftime("%H:%M"), size=120, weight=ft.FontWeight.W_100, color=ft.Colors.WHITE, text_align=ft.TextAlign.CENTER),
                    ft.Text(now.strftime("%A, %B %d"), size=24, weight=ft.FontWeight.W_400, color=ft.Colors.with_opacity(0.8, ft.Colors.WHITE), text_align=ft.TextAlign.CENTER),
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=8),
                ft.Container(expand=True),
                ft.Column([*[self._create_notification_card(n) for n in self.notifications[-3:]]], spacing=12) if self.notifications else ft.Container(),
                ft.Container(height=40),
                ft.GestureDetector(
                    content=ft.Container(
                        content=ft.Row([
                            ft.Icon(ft.icons.Icons.LOCK_OPEN, color=ft.Colors.WHITE, size=24),
                            ft.Text("Click to unlock", color=ft.Colors.WHITE, size=20),
                        ], alignment=ft.MainAxisAlignment.CENTER, spacing=12),
                        padding=24, border_radius=30,
                        bgcolor=ft.Colors.with_opacity(0.2, ft.Colors.WHITE),
                        border=ft.border.all(1, ft.Colors.with_opacity(0.3, ft.Colors.WHITE)),
                    ),
                    on_tap=lambda _: self._unlock_phone(),
                ),
                ft.Container(height=80),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            gradient=ft.LinearGradient(colors=["#667eea", "#764ba2"], begin=ft.Alignment.TOP_LEFT, end=ft.Alignment.BOTTOM_RIGHT),
            expand=True, padding=40,
        )

    # ------------------------------------------------------------------
    # Home screen
    # ------------------------------------------------------------------

    def _render_home_screen(self) -> ft.Control:
        app_rows = []
        apps_list = list(self.apps.items())
        for i in range(0, len(apps_list), 4):
            row_apps = apps_list[i:i + 4]
            app_rows.append(ft.Row([self._create_app_icon(aid, aobj) for aid, aobj in row_apps], alignment=ft.MainAxisAlignment.CENTER, spacing=30))

        dock_apps = []
        for app_id in ("messages", "gallery", "settings"):
            if app_id in self.apps:
                dock_apps.append(self._create_dock_icon(app_id, self.apps[app_id]))

        dock = ft.Container(
            content=ft.Row(dock_apps, alignment=ft.MainAxisAlignment.CENTER, spacing=40),
            height=100,
            margin=ft.margin.symmetric(horizontal=30, vertical=15),
            padding=ft.padding.symmetric(horizontal=30, vertical=15),
            border_radius=25,
            bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.WHITE),
            border=ft.border.all(1, ft.Colors.with_opacity(0.2, ft.Colors.WHITE)),
        )

        return ft.Container(
            content=ft.Column([
                ft.Container(height=60),
                ft.Text("AwiOS", size=32, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE, text_align=ft.TextAlign.CENTER),
                ft.Container(height=60),
                ft.Column(app_rows, spacing=50, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                ft.Container(expand=True),
                dock,
                ft.Container(height=40),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            expand=True, padding=40,
        )

    # ------------------------------------------------------------------
    # App icons
    # ------------------------------------------------------------------

    _APP_COLORS = {
        "messages": ["#1976D2", "#0D47A1"],
        "gallery": ["#8E24AA", "#4A148C"],
        "settings": ["#424242", "#212121"],
    }

    def _create_app_icon(self, app_id: str, app_obj: App) -> ft.GestureDetector:
        colors = self._APP_COLORS.get(app_id, ["#667eea", "#764ba2"])
        base_icon = ft.Container(
            content=ft.Icon(app_obj.icon, size=36, color=ft.Colors.WHITE),
            width=80, height=80, alignment=ft.Alignment.CENTER, border_radius=20,
            gradient=ft.LinearGradient(colors=colors, begin=ft.Alignment.TOP_LEFT, end=ft.Alignment.BOTTOM_RIGHT),
            shadow=ft.BoxShadow(spread_radius=2, blur_radius=10, color=ft.Colors.with_opacity(0.3, ft.Colors.BLACK), offset=ft.Offset(0, 4)),
        )

        icon_widget = base_icon
        if app_id == "messages" and hasattr(self, "chat_manager"):
            unread = self.chat_manager.get_total_unread_count()
            if unread > 0:
                icon_widget = ft.Stack([
                    base_icon,
                    ft.Container(
                        content=ft.Text(str(unread) if unread < 100 else "99+", size=10, color=ft.Colors.WHITE, weight=ft.FontWeight.BOLD, text_align=ft.TextAlign.CENTER),
                        width=20, height=20, border_radius=10, bgcolor=ft.Colors.RED, alignment=ft.Alignment.CENTER, right=-5, top=-5,
                    ),
                ])

        return ft.GestureDetector(
            content=ft.Column([
                icon_widget,
                ft.Text(app_obj.name, size=14, color=ft.Colors.WHITE, text_align=ft.TextAlign.CENTER, weight=ft.FontWeight.W_500, no_wrap=True),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=8),
            on_tap=lambda e, aid=app_id: self.open_app(aid),
        )

    def _create_dock_icon(self, app_id: str, app_obj: App) -> ft.GestureDetector:
        return ft.GestureDetector(
            content=ft.Container(
                content=ft.Icon(app_obj.icon, size=28, color=ft.Colors.WHITE),
                width=60, height=60, alignment=ft.Alignment.CENTER, border_radius=15,
                gradient=ft.LinearGradient(colors=["#667eea", "#764ba2"], begin=ft.Alignment.TOP_LEFT, end=ft.Alignment.BOTTOM_RIGHT),
                shadow=ft.BoxShadow(spread_radius=1, blur_radius=8, color=ft.Colors.with_opacity(0.4, ft.Colors.BLACK), offset=ft.Offset(0, 4)),
            ),
            on_tap=lambda e, aid=app_id: self.open_app(aid),
        )

    def _create_notification_card(self, notification: Dict[str, Any]):
        app_obj = self.apps.get(notification["app_id"])
        icon = app_obj.icon if app_obj else ft.icons.Icons.NOTIFICATIONS
        return ft.GestureDetector(
            content=ft.Container(
                content=ft.Row([
                    ft.Container(content=ft.Icon(icon, size=20, color=ft.Colors.WHITE), width=40, height=40, alignment=ft.Alignment.CENTER, border_radius=8, bgcolor=ft.Colors.with_opacity(0.3, ft.Colors.WHITE)),
                    ft.Column([
                        ft.Text(notification["title"], size=14, weight=ft.FontWeight.W_600, color=ft.Colors.WHITE),
                        ft.Text(notification["content"], size=12, color=ft.Colors.with_opacity(0.9, ft.Colors.WHITE), max_lines=2, overflow=ft.TextOverflow.ELLIPSIS),
                    ], spacing=2, expand=True),
                ], spacing=12),
                padding=16, border_radius=12,
                bgcolor=ft.Colors.with_opacity(0.2, ft.Colors.WHITE),
                border=ft.border.all(1, ft.Colors.with_opacity(0.3, ft.Colors.WHITE)),
            ),
            on_tap=lambda _, n=notification: self._handle_notification_click(n),
        )

    def _handle_notification_click(self, notification: Dict[str, Any]):
        app_id = notification["app_id"]
        if app_id in self.apps:
            self.open_app(app_id)
            if notification in self.notifications:
                self.notifications.remove(notification)

    def _unlock_phone(self):
        self.current_state = GameState.HOME_SCREEN
        self.update_ui()

    # ------------------------------------------------------------------
    # Run
    # ------------------------------------------------------------------

    def run(self, title: str = "AwiOS"):
        def main(page: ft.Page):
            self.page = page
            page.title = title
            page.theme_mode = ft.ThemeMode.DARK
            page.window.width = 500
            page.window.height = 1000
            page.window.min_width = 400
            page.window.min_height = 800
            page.window.resizable = True
            page.padding = 0
            page.spacing = 0
            page.vertical_alignment = ft.MainAxisAlignment.START
            page.horizontal_alignment = ft.CrossAxisAlignment.STRETCH
            self.load_apps()
            self.update_ui()

        ft.app(target=main)
