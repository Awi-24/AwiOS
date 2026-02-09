"""
Settings App – engine configuration.
"""

import flet as ft
from src.core.app_base import App
from pathlib import Path


class SettingsApp(App):
    """App de configurações da engine"""

    def __init__(self):
        super().__init__()
        self.app_id = "settings"
        self.name = "Settings"
        self.icon = ft.icons.Icons.SETTINGS

        self.available_languages = ["en_US", "pt_BR"]
        self.language_names = {"en_US": "English", "pt_BR": "Português"}

        self.text_speeds = [0.5, 1.0, 1.5, 2.0, 3.0]
        self.speed_names = {0.5: "Slow", 1.0: "Normal", 1.5: "Fast", 2.0: "Very Fast", 3.0: "Instant"}

    def render(self, page):
        header = ft.Container(
            content=ft.Row([
                ft.IconButton(icon=ft.icons.Icons.ARROW_BACK, icon_color=ft.Colors.WHITE, on_click=lambda _: self.close()),
                ft.Text("Settings", size=20, weight=ft.FontWeight.W_600, color=ft.Colors.WHITE),
                ft.Container(expand=True),
                ft.IconButton(icon=ft.icons.Icons.RESTORE, icon_color=ft.Colors.WHITE, tooltip="Restore Defaults", on_click=lambda _: self._restore_defaults()),
            ], spacing=12),
            padding=ft.padding.symmetric(horizontal=16, vertical=12),
            gradient=ft.LinearGradient(colors=["#FF6B6B", "#4ECDC4"], begin=ft.Alignment.CENTER_LEFT, end=ft.Alignment.CENTER_RIGHT),
        )

        settings_content = ft.Column([
            self._create_section("Game", [
                self._create_language_setting(),
                self._create_text_speed_setting(),
                self._create_auto_save_setting(),
                self._create_notifications_setting(),
            ]),
            ft.Divider(height=20),
            self._create_section("Gallery", [
                self._create_unlock_gallery_setting(),
                self._create_clear_gallery_setting(),
            ]),
            ft.Divider(height=20),
            self._create_section("Advanced", [
                self._create_reset_progress_setting(),
            ]),
            ft.Divider(height=20),
            self._create_section("Credits", [
                self._create_credits_info(),
            ]),
            ft.Container(height=40),
            ft.Container(
                content=ft.Text("AwiOS v1.0.0", size=12, color=ft.Colors.with_opacity(0.6, ft.Colors.BLACK), text_align=ft.TextAlign.CENTER),
                alignment=ft.Alignment.CENTER,
            ),
        ], spacing=0, scroll=ft.ScrollMode.AUTO, expand=True)

        return ft.Column([
            header,
            ft.Container(content=settings_content, padding=20, expand=True),
        ], spacing=0, expand=True)

    def _create_section(self, title: str, settings: list):
        return ft.Container(
            content=ft.Column([
                ft.Text(title, size=18, weight=ft.FontWeight.W_600, color=ft.Colors.WHITE),
                ft.Container(height=8),
                ft.Column(settings, spacing=12),
            ]),
            padding=16, border_radius=12,
            bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.WHITE),
            border=ft.border.all(1, ft.Colors.with_opacity(0.3, ft.Colors.WHITE)),
            margin=ft.margin.only(bottom=16),
        )

    def _create_language_setting(self):
        current_lang = self.get_setting("language", "en_US")
        return ft.Row([
            ft.Icon(ft.icons.Icons.LANGUAGE, color=ft.Colors.BLUE_600),
            ft.Column([
                ft.Text("Language", size=14, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE),
                ft.Text("Change UI language", size=12, color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE)),
            ], spacing=2, expand=True),
            ft.Dropdown(
                value=str(current_lang),
                options=[ft.dropdown.Option(lang, self.language_names[lang]) for lang in self.available_languages],
                width=120,
                on_select=lambda e: self._change_language(e.control.value),
            ),
        ], spacing=12, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    def _create_text_speed_setting(self):
        current_speed = self.get_setting("text_speed", 1.0)
        return ft.Row([
            ft.Icon(ft.icons.Icons.SPEED, color=ft.Colors.GREEN_600),
            ft.Column([
                ft.Text("Text Speed", size=14, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE),
                ft.Text("Message display speed", size=12, color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE)),
            ], spacing=2, expand=True),
            ft.Dropdown(
                value=str(current_speed),
                options=[ft.dropdown.Option(str(speed), self.speed_names[speed]) for speed in self.text_speeds],
                width=120,
                on_select=lambda e: self._change_text_speed(float(e.control.value)),
            ),
        ], spacing=12, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    def _create_auto_save_setting(self):
        auto_save = self.get_setting("auto_save", True)
        return ft.Row([
            ft.Icon(ft.icons.Icons.SAVE, color=ft.Colors.ORANGE_600),
            ft.Column([
                ft.Text("Auto Save", size=14, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE),
                ft.Text("Save progress automatically", size=12, color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE)),
            ], spacing=2, expand=True),
            ft.Switch(value=auto_save, on_change=lambda e: self._toggle_auto_save(e.control.value)),
        ], spacing=12, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    def _create_notifications_setting(self):
        notifications_enabled = self.get_setting("notifications", True)
        return ft.Row([
            ft.Icon(ft.icons.Icons.NOTIFICATIONS, color=ft.Colors.AMBER_600),
            ft.Column([
                ft.Text("Notifications", size=14, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE),
                ft.Text("Show message notifications", size=12, color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE)),
            ], spacing=2, expand=True),
            ft.Switch(value=notifications_enabled, on_change=lambda e: self._toggle_notifications(e.control.value)),
        ], spacing=12, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    def _create_unlock_gallery_setting(self):
        return ft.Row([
            ft.Icon(ft.icons.Icons.LOCK_OPEN, color=ft.Colors.PURPLE_600),
            ft.Column([
                ft.Text("Unlock Gallery", size=14, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE),
                ft.Text("Unlock all backgrounds", size=12, color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE)),
            ], spacing=2, expand=True),
            ft.ElevatedButton("Unlock", on_click=lambda _: self._unlock_gallery(), style=ft.ButtonStyle(color=ft.Colors.WHITE, bgcolor=ft.Colors.PURPLE_600)),
        ], spacing=12, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    def _create_clear_gallery_setting(self):
        return ft.Row([
            ft.Icon(ft.icons.Icons.CLEAR, color=ft.Colors.RED_600),
            ft.Column([
                ft.Text("Clear Gallery", size=14, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE),
                ft.Text("Remove unlocked chat media", size=12, color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE)),
            ], spacing=2, expand=True),
            ft.ElevatedButton("Clear", on_click=lambda _: self._clear_gallery(), style=ft.ButtonStyle(color=ft.Colors.WHITE, bgcolor=ft.Colors.RED_600)),
        ], spacing=12, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    def _create_reset_progress_setting(self):
        return ft.Row([
            ft.Icon(ft.icons.Icons.RESTART_ALT, color=ft.Colors.RED_800),
            ft.Column([
                ft.Text("Reset Progress", size=14, weight=ft.FontWeight.W_500, color=ft.Colors.WHITE),
                ft.Text("Erase all game progress", size=12, color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE)),
            ], spacing=2, expand=True),
            ft.ElevatedButton("Reset", on_click=lambda _: self._reset_progress(), style=ft.ButtonStyle(color=ft.Colors.WHITE, bgcolor=ft.Colors.RED_800)),
        ], spacing=12, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def _change_language(self, language: str):
        if self.engine:
            self.set_setting("language", language)
            self.engine.i18n.set_language(language)
        self._show_toast(f"Language: {self.language_names.get(language, language)}")

    def _change_text_speed(self, speed: float):
        self.set_setting("text_speed", speed)
        if self.engine and self.engine.apps.get("messages"):
            try:
                self.engine.apps["messages"].text_speed = speed
                self.engine.apps["messages"]._load_settings()  # Reload settings
            except Exception:
                pass
        self._show_toast(f"Speed: {self.speed_names.get(speed, speed)}")

    def _toggle_auto_save(self, value: bool):
        self.set_setting("auto_save", value)
        self._show_toast("Auto save " + ("on" if value else "off"))

    def _toggle_notifications(self, value: bool):
        self.set_setting("notifications", value)
        self._show_toast("Notifications " + ("enabled" if value else "disabled"))

    def _unlock_gallery(self):
        if not self.engine:
            return
        if hasattr(self.engine, "background_manager"):
            for bg in self.engine.background_manager.get_available_backgrounds():
                self.engine.background_manager.unlock_background(bg["id"])
        self._show_toast("All backgrounds unlocked!")
        self.engine.update_ui()

    def _clear_gallery(self):
        if not self.engine:
            return
        gallery = self.engine.apps.get("gallery")
        if gallery and hasattr(gallery, "clear_unlocked_media"):
            gallery.clear_unlocked_media()
        self._show_toast("Chat media cleared!")
        self.engine.update_ui()

    def _reset_progress(self):
        if not self.engine:
            return
        self.engine.state.variables.clear()
        self.engine.state.dialogue_history.clear()
        self.engine.state.unlocked_content.clear()
        base = self.engine.saves_path if hasattr(self.engine, "saves_path") else Path("saves")
        for filename in ("conversation_states.json", "unlocked_media.json", "chats_state.json", "background_config.json"):
            p = Path(base) / filename
            try:
                if p.exists():
                    p.unlink()
            except Exception:
                pass
        self._show_toast("Progress reset!")

    def _restore_defaults(self):
        self.set_setting("language", "en_US")
        self.set_setting("text_speed", 1.0)
        self.set_setting("auto_save", True)
        if self.engine:
            self.engine.i18n.set_language("en_US")
        self._show_toast("Defaults restored!")
        if self.engine:
            self.engine.update_ui()

    def _create_credits_info(self):
        return ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Icon(ft.icons.Icons.CODE, color=ft.Colors.WHITE, size=20),
                    ft.Text("Developed by", size=14, color=ft.Colors.WHITE70),
                ], spacing=8),
                ft.Container(height=8),
                ft.GestureDetector(
                    content=ft.Row([
                        ft.Icon(ft.icons.Icons.LINK, color=ft.Colors.BLUE_300, size=18),
                        ft.Text("Awi-24 on GitHub", size=14, color=ft.Colors.BLUE_300, weight=ft.FontWeight.W_600),
                        ft.Icon(ft.icons.Icons.OPEN_IN_NEW, color=ft.Colors.BLUE_300, size=16),
                    ], spacing=6),
                    on_tap=lambda _: self._open_github_link(),
                ),
            ]),
            padding=12,
            border_radius=8,
            bgcolor=ft.Colors.with_opacity(0.05, ft.Colors.WHITE),
            border=ft.border.all(1, ft.Colors.with_opacity(0.2, ft.Colors.WHITE)),
        )
    
    def _open_github_link(self):
        import webbrowser
        try:
            webbrowser.open("https://github.com/Awi-24")
            self._show_toast("Opening GitHub profile...")
        except Exception:
            self._show_toast("Could not open link")

    def _show_toast(self, message: str):
        if self.engine and self.engine.page:
            self.engine.page.snack_bar = ft.SnackBar(content=ft.Text(message), duration=2000)
            self.engine.page.snack_bar.open = True
            self.engine.page.update()
