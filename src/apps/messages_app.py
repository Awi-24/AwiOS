"""
Simplified Messages app - reliable conversation flow without complex segment logic.
"""

import asyncio
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import flet as ft

from src.core.app_base import App
from src.data.dialogue_parser import Choice, DialogueNode, DialogueParser, MessageType


class MessagesApp(App):
    """Simplified chat-style dialogue application."""

    def __init__(self):
        super().__init__()
        self.app_id = "messages"
        self.name = "Messages"
        self.icon = ft.icons.Icons.MESSAGE

        self.parser = DialogueParser()

        # UI state
        self.view_mode = "chat_list"  # chat_list | conversation
        self.current_chat_id: Optional[str] = None

        # Dialogue state
        self.current_dialogue_id: Optional[str] = None
        self.current_node_id: Optional[str] = None
        self.displayed_messages: list[DialogueNode] = []
        
        # Current state
        self.waiting_for_input = False
        self.showing_choices = False
        self.current_choices: list[Choice] = []
        
        # Player stats
        self.player_stats = {"trust": 0, "affection": 0, "corruption": 0, "points": 0}
        
        # Simple interaction protection
        self._processing = False
        # Auto-advance: cancel id so pending timer is ignored after user tap
        self._auto_advance_id = 0
        
        # Media viewer
        self._viewer_open = False
        self._viewer_src: Optional[str] = None
        
        # Text speed and settings
        self.text_speed = 1.0
        self.auto_save_enabled = True
        
        # Reused ListView ref for instant scroll (no animation)
        self._messages_listview = None

    def set_engine(self, engine):
        super().set_engine(engine)
        if engine:
            self.parser.engine = engine
            self._load_settings()

    def on_open(self):
        """Setup keyboard handling when app opens."""
        if self.engine and self.engine.page:
            self.engine.page.on_keyboard_event = self._on_keyboard_event

    def on_close(self):
        """Cleanup when app closes."""
        if self.engine and self.engine.page:
            self.engine.page.on_keyboard_event = None
        self._save_state()

    def render(self, page: ft.Page):
        """Main render method."""
        if self.view_mode == "chat_list":
            return self._render_chat_list()
        else:
            return self._render_conversation()

    # ------------------------------------------------------------------
    # Chat List UI
    # ------------------------------------------------------------------

    def _render_chat_list(self):
        """Render the chat selection screen."""
        header = ft.Container(
            content=ft.Row([
                ft.IconButton(
                    icon=ft.icons.Icons.ARROW_BACK,
                    icon_color=ft.Colors.WHITE,
                    icon_size=24,
                    on_click=lambda _: self.close()
                ),
                ft.Text("Messages", size=22, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                ft.Container(expand=True),
            ]),
            padding=ft.padding.symmetric(horizontal=20, vertical=16),
            gradient=ft.LinearGradient(
                colors=["#667eea", "#764ba2"],
                begin=ft.Alignment.TOP_LEFT,
                end=ft.Alignment.BOTTOM_RIGHT
            ),
            height=70,
        )

        # Get chat list
        chat_items = []
        if self.engine and hasattr(self.engine, "chat_manager"):
            for chat in self.engine.chat_manager.get_chat_list():
                unread_count = self.engine.chat_manager.get_unread_count(chat["id"])
                chat_items.append(
                    ft.Container(
                        content=ft.GestureDetector(
                            content=ft.Row([
                                ft.Container(
                                    content=ft.CircleAvatar(
                                        foreground_image_src=chat.get("avatar", "assets/images/test.png"),
                                        radius=28,
                                    ),
                                    margin=ft.margin.only(right=16),
                                ),
                                ft.Column([
                                    ft.Text(
                                        chat.get("name", "Unknown"), 
                                        size=16, 
                                        weight=ft.FontWeight.W_600,
                                        color=ft.Colors.BLACK87
                                    ),
                                    ft.Text(
                                        chat.get("last_message", ""), 
                                        size=14, 
                                        color=ft.Colors.BLACK54,
                                        max_lines=1,
                                        overflow=ft.TextOverflow.ELLIPSIS,
                                    ),
                                ], 
                                spacing=4, 
                                expand=True,
                                alignment=ft.MainAxisAlignment.CENTER,
                                ),
                                ft.Container(
                                    content=ft.Container(
                                        content=ft.Text(
                                            str(unread_count), 
                                            size=12, 
                                            color=ft.Colors.WHITE, 
                                            weight=ft.FontWeight.BOLD
                                        ),
                                        alignment=ft.Alignment.CENTER,
                                    ),
                                    width=24,
                                    height=24,
                                    border_radius=12,
                                    bgcolor=ft.Colors.RED_400,
                                    visible=unread_count > 0,
                                    animate_scale=200,
                                ),
                            ], 
                            alignment=ft.MainAxisAlignment.START,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            on_tap=lambda e, chat_id=chat["id"]: self._open_chat(chat_id),
                        ),
                        bgcolor=ft.Colors.WHITE,
                        border_radius=12,
                        padding=ft.padding.all(16),
                        margin=ft.margin.symmetric(horizontal=16, vertical=6),
                        shadow=ft.BoxShadow(
                            spread_radius=0,
                            blur_radius=8,
                            color=ft.Colors.with_opacity(0.1, ft.Colors.BLACK),
                            offset=ft.Offset(0, 2),
                        ),
                        animate_opacity=300,
                        animate_scale=200,
                    )
                )

        return ft.Container(
            content=ft.Column([
                header,
                ft.Container(
                    expand=True,
                    content=ft.Column(
                        controls=chat_items,
                        spacing=0,
                        scroll=ft.ScrollMode.HIDDEN,
                        auto_scroll=False,
                    ),
                    bgcolor=ft.Colors.with_opacity(0.02, ft.Colors.BLACK),
                    padding=ft.padding.only(top=12, bottom=12),
                ),
            ], spacing=0),
            expand=True,
        )

    # ------------------------------------------------------------------
    # Conversation Logic
    # ------------------------------------------------------------------

    def _open_chat(self, chat_id: str):
        """Open a specific chat conversation with transition."""
        if not (self.engine and hasattr(self.engine, "chat_manager")):
            return
            
        chat = self.engine.chat_manager.get_chat(chat_id)
        if not chat:
            return

        self.current_chat_id = chat_id
        self.view_mode = "conversation"
        
        # Mark chat as read so notification badge disappears
        self.engine.chat_manager.open_chat(chat_id)
        
        # Try to restore saved state first
        if not self._load_state(chat_id):
            # No saved state, start fresh
            dialogue_file = chat.get("dialogue_file")
            if dialogue_file and Path(dialogue_file).exists():
                self._start_fresh_conversation(dialogue_file)

        self._update_ui()

        # Start auto-advance when there is a next message (speed setting controls delay)
        if (
            self.view_mode == "conversation"
            and self.waiting_for_input
            and not self.showing_choices
            and self.engine
            and self.engine.page
        ):
            self._auto_advance_id = getattr(self, "_auto_advance_id", 0) + 1
            delay = 2.5 / max(0.2, self.text_speed)
            schedule_id = self._auto_advance_id
            self.engine.page.run_task(self._auto_advance_after(delay, schedule_id))

    def _start_fresh_conversation(self, dialogue_file: str):
        """Start a new conversation from the beginning."""
        try:
            dialogue_path = Path(dialogue_file)
            self.parser.load_dialogue(dialogue_path)
            self.current_dialogue_id = dialogue_path.stem
            self.current_node_id = "start"
            self.displayed_messages = []
            self.showing_choices = False
            self.current_choices = []
            
            # Show first message
            self._advance_to_next()
            
        except Exception as e:
            print(f"Error loading dialogue: {e}")

    def _advance_to_next(self):
        """Advance to next message or show choices."""
        if not self.current_dialogue_id or not self.current_node_id:
            self.waiting_for_input = False
            return

        node = self.parser.get_node(self.current_dialogue_id, self.current_node_id)
        if not node:
            self.waiting_for_input = False
            return

        # Check conditions
        if not self.parser.check_node_condition(node):
            # Skip this node
            self.current_node_id = node.next_node
            self._advance_to_next()  # Recursively try next
            return

        # Add message to display
        self.displayed_messages.append(node)
        if len(self.displayed_messages) > 100:  # Limit history
            self.displayed_messages = self.displayed_messages[-100:]

        # Handle media
        self._handle_media(node)

        # Check if node has choices
        if node.choices:
            available_choices = self.parser.get_available_choices(node)
            if available_choices:
                self.showing_choices = True
                self.current_choices = available_choices
                self.waiting_for_input = False
                return

        # No choices, continue to next node
        self.current_node_id = node.next_node
        self.showing_choices = False
        self.current_choices = []
        self.waiting_for_input = bool(self.current_node_id)

    def _handle_advance(self):
        """Handle user advancing the conversation (tap or auto-advance timer)."""
        if self._processing or self.showing_choices:
            return
        if self.view_mode != "conversation":
            return

        # Cancel any pending auto-advance so we don't double-advance
        self._auto_advance_id = getattr(self, "_auto_advance_id", 0) + 1

        try:
            self._processing = True
            self._advance_to_next()
            self._save_state()
            self._update_ui()

            # Schedule auto-advance to next message after delay (speed setting controls delay)
            if (
                self.waiting_for_input
                and not self.showing_choices
                and self.engine
                and self.engine.page
            ):
                delay = 2.5 / max(0.2, self.text_speed)  # Slow=longer, Instant=shorter
                schedule_id = self._auto_advance_id
                self.engine.page.run_task(self._auto_advance_after(delay, schedule_id))
        finally:
            self._processing = False

    async def _auto_advance_after(self, delay: float, schedule_id: int):
        """After delay, advance to next message if this schedule wasn't cancelled (e.g. by user tap)."""
        await asyncio.sleep(delay)
        if getattr(self, "_auto_advance_id", None) != schedule_id:
            return
        self._handle_advance()

    def _select_choice(self, choice_index: int):
        """Handle user selecting a choice."""
        if self._processing or not self.showing_choices:
            return
        if choice_index < 0 or choice_index >= len(self.current_choices):
            return

        try:
            self._processing = True
            choice = self.current_choices[choice_index]

            # Add player's choice as message
            player_message = DialogueNode(
                node_id=f"player_choice_{int(time.time() * 1000)}",
                sender_id="player",
                content=choice.text,
                message_type=MessageType.TEXT,
            )
            self.displayed_messages.append(player_message)

            # Apply choice effects
            self._apply_choice_effects(choice)

            # Move to next node
            self.current_node_id = choice.next_node
            self.showing_choices = False
            self.current_choices = []

            # Continue conversation
            self._advance_to_next()
            if self.auto_save_enabled:
                self._save_state()
            self._update_ui()

        finally:
            self._processing = False

    def _apply_choice_effects(self, choice: Choice):
        """Apply stat changes from choice effects."""
        if not hasattr(choice, 'effects') or not choice.effects:
            return

        effects = choice.effects
        if isinstance(effects, dict):
            for stat, value in effects.items():
                if stat in self.player_stats and isinstance(value, (int, float)):
                    self.player_stats[stat] = max(0, self.player_stats[stat] + value)

        # Update engine variables
        if self.engine:
            for stat, value in self.player_stats.items():
                self.engine.set_variable(f"player_{stat}", value)

    # ------------------------------------------------------------------
    # Media Handling
    # ------------------------------------------------------------------

    def _handle_media(self, node: DialogueNode):
        """Handle media in dialogue nodes."""
        media_items = []
        if isinstance(node.media, list):
            media_items = node.media
        elif isinstance(node.media, dict):
            media_items = [node.media]
        
        for media in media_items:
            if not isinstance(media, dict):
                continue
                
            media_type = media.get("type")
            if media_type in ("image", "gif", "video"):
                self._unlock_image_in_gallery(media.get("src"))

    def _unlock_image_in_gallery(self, src: str):
        """Unlock media in gallery app."""
        if not src or not self.engine:
            return
        
        asset_path = src if src.startswith("assets/") else f"assets/{src}"
        gallery = self.engine.apps.get("gallery")
        if gallery and hasattr(gallery, "unlock_media"):
            try:
                gallery.unlock_media(asset_path)
            except Exception:
                pass

    def _open_media_viewer(self, src: str):
        """Open media viewer overlay."""
        try:
            # Ensure the path exists
            if not src:
                return
            
            # Handle both assets/ prefixed and non-prefixed paths
            if not src.startswith("assets/"):
                src = f"assets/{src}"
            
            self._viewer_src = src
            self._viewer_open = True
            self._update_ui()
        except Exception as e:
            print(f"Error opening media viewer: {e}")
            self._close_media_viewer()

    def _close_media_viewer(self):
        """Close media viewer overlay."""
        self._viewer_open = False
        self._viewer_src = None
        self._update_ui()

    # ------------------------------------------------------------------
    # Conversation UI
    # ------------------------------------------------------------------

    def _render_conversation(self):
        """Render the conversation screen."""
        chat_name = self._get_chat_name()
        
        header = ft.Container(
            content=ft.Row([
                ft.IconButton(
                    icon=ft.icons.Icons.ARROW_BACK,
                    icon_color=ft.Colors.WHITE,
                    icon_size=24,
                    on_click=lambda _: self._back_to_chat_list()
                ),
                ft.Text(chat_name, size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                ft.Container(expand=True),
            ]),
            padding=ft.padding.symmetric(horizontal=20, vertical=16),
            gradient=ft.LinearGradient(
                colors=["#667eea", "#764ba2"],
                begin=ft.Alignment.TOP_LEFT,
                end=ft.Alignment.BOTTOM_RIGHT
            ),
            height=70,
        )

        # Messages area - reuse ListView to avoid scroll animation
        message_controls = []
        for i, msg in enumerate(self.displayed_messages):
            message_controls.append(self._create_message_bubble(msg))

        # Reverse so with reverse=True ListView, newest is at bottom and view stays there
        reversed_controls = list(reversed(message_controls))
        if self._messages_listview is None:
            self._messages_listview = ft.ListView(
                controls=reversed_controls,
                spacing=12,
                padding=ft.padding.all(20),
                auto_scroll=False,
                scroll=ft.ScrollMode.HIDDEN,
                reverse=True,  # Keeps newest at bottom, no scroll jump on click
            )
        else:
            self._messages_listview.controls = reversed_controls
        
        messages_area = ft.Container(
            expand=True,
            content=self._messages_listview,
            bgcolor=ft.Colors.with_opacity(0.02, ft.Colors.BLACK),
        )

        # Make messages area tappable to advance but prevent scroll interference  
        if self.waiting_for_input and not self.showing_choices:
            # Wrap with GestureDetector that doesn't interfere with scroll position
            messages_area = ft.GestureDetector(
                content=messages_area,
                on_tap=lambda _: self._handle_advance_without_scroll(),
            )

        # Animated choices area
        choices_area = ft.Container(
            visible=self.showing_choices,
            content=self._render_choices() if self.showing_choices else ft.Container(),
            padding=ft.padding.all(20) if self.showing_choices else ft.padding.all(0),
            bgcolor=ft.Colors.WHITE,
            animate_opacity=300,
            animate=400,
        )

        # Modern status area
        status_text = "Tap to continue..." if self.waiting_for_input else "Conversation ended"
        if self.showing_choices:
            status_text = "Choose an option..."

        status_area = ft.Container(
            content=ft.Row([
                ft.Container(
                    content=ft.Text(
                        status_text, 
                        size=14, 
                        color=ft.Colors.BLACK54,
                        weight=ft.FontWeight.W_500,
                    ),
                    padding=ft.padding.symmetric(horizontal=16, vertical=8),
                    bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.BLUE_GREY),
                    border_radius=20,
                ),
                ft.Container(expand=True),
                ft.Container(
                    content=ft.Row([
                        ft.Icon(ft.icons.Icons.FAVORITE, color=ft.Colors.RED_400, size=18),
                        ft.Text(f"{int(self.player_stats['affection'])}", size=14, weight=ft.FontWeight.W_600),
                        ft.Container(width=16),
                        ft.Icon(ft.icons.Icons.STAR, color=ft.Colors.AMBER_400, size=18),
                        ft.Text(f"{int(self.player_stats['points'])}", size=14, weight=ft.FontWeight.W_600),
                    ], spacing=4),
                    padding=ft.padding.symmetric(horizontal=12, vertical=8),
                    bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.BLACK),
                    border_radius=20,
                ),
            ], spacing=8),
            padding=ft.padding.all(20),
            bgcolor=ft.Colors.WHITE,
            height=80,  # Slightly taller for better proportions
        )

        main_content = ft.Column([
            header,
            ft.Container(content=messages_area, expand=True),
            choices_area,
            status_area,
        ], spacing=0, expand=True)

        # Add media viewer overlay if open
        if self._viewer_open and self._viewer_src:
            return self._render_media_overlay()

        return main_content

    def _create_message_bubble(self, node: DialogueNode) -> ft.Control:
        """Create a message bubble for a dialogue node."""
        is_player = node.sender_id == "player"
        text_content = node.text or node.content

        bubble_content = []
        
        # Add text with speed effect
        if text_content:
            if self.text_speed >= 3.0:  # Instant speed
                displayed_text = text_content
            else:
                # Calculate how much text to show based on speed and time
                chars_per_second = 30 * self.text_speed  # Base 30 chars/second
                # For now, show full text (we can add animation later if needed)
                displayed_text = text_content
                
            bubble_content.append(
                ft.Text(
                    displayed_text,
                    size=15,
                    color=ft.Colors.WHITE if is_player else ft.Colors.BLACK87,
                    selectable=True,
                    weight=ft.FontWeight.W_400,
                )
            )

        # Add media if present (handle both single dict and array formats)
        media_items = []
        if isinstance(node.media, list):
            media_items = node.media
        elif isinstance(node.media, dict) and node.media.get("type"):
            media_items = [node.media]
        
        for media_item in media_items:
            if isinstance(media_item, dict) and media_item.get("type"):
                media_widget = self._create_media_widget(media_item)
                if media_widget:
                    bubble_content.append(media_widget)

        # Add timestamp
        bubble_content.append(
            ft.Text(
                datetime.now().strftime("%H:%M"),
                size=11,
                color=ft.Colors.with_opacity(0.7, ft.Colors.WHITE if is_player else ft.Colors.BLACK),
                text_align=ft.TextAlign.RIGHT if is_player else ft.TextAlign.LEFT,
            )
        )

        # Modern bubble container with subtle animation
        bubble = ft.Container(
            content=ft.Column(bubble_content, spacing=6, tight=True),
            padding=ft.padding.all(16),
            border_radius=ft.border_radius.only(
                top_left=20, top_right=20,
                bottom_left=6 if is_player else 20,
                bottom_right=20 if is_player else 6,
            ),
            bgcolor=ft.Colors.BLUE_500 if is_player else ft.Colors.WHITE,
            margin=ft.margin.only(left=80 if is_player else 0, right=0 if is_player else 80),
            shadow=ft.BoxShadow(
                spread_radius=0,
                blur_radius=8,
                color=ft.Colors.with_opacity(0.15, ft.Colors.BLACK),
                offset=ft.Offset(0, 2),
            ),
            animate_opacity=400,
            animate_offset=300,
        )

        return ft.Row([
            bubble if not is_player else ft.Container(expand=True),
            ft.Container(expand=True) if not is_player else bubble,
        ], alignment=ft.MainAxisAlignment.END if is_player else ft.MainAxisAlignment.START)

    def _create_media_widget(self, media: dict) -> Optional[ft.Control]:
        """Create widget for media content."""
        media_type = media.get("type")
        src = media.get("src", "")
        
        if not src:
            return None
            
        asset_path = src if src.startswith("assets/") else f"assets/{src}"

        if media_type in ("image", "gif"):
            return ft.GestureDetector(
                content=ft.Container(
                    content=ft.Image(src=asset_path, width=220, height=160, fit="cover"),
                    border_radius=12,
                    margin=ft.margin.only(top=8),
                    shadow=ft.BoxShadow(
                        spread_radius=0,
                        blur_radius=8,
                        color=ft.Colors.with_opacity(0.2, ft.Colors.BLACK),
                        offset=ft.Offset(0, 2),
                    ),
                ),
                on_tap=lambda _, path=asset_path: self._open_media_viewer(path),
            )
        elif media_type == "video":
            return ft.GestureDetector(
                content=ft.Container(
                    content=ft.Stack([
                        ft.Container(
                            width=220, 
                            height=130,
                            bgcolor=ft.Colors.with_opacity(0.9, ft.Colors.BLACK),
                            border_radius=12,
                        ),
                        ft.Container(
                            width=220, 
                            height=130,
                            content=ft.Column([
                                ft.Icon(ft.icons.Icons.PLAY_CIRCLE_FILLED, size=48, color=ft.Colors.WHITE),
                                ft.Text("Tap to view", size=12, color=ft.Colors.WHITE70),
                            ], 
                            spacing=8,
                            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            alignment=ft.Alignment.CENTER,
                        ),
                    ]),
                    margin=ft.margin.only(top=8),
                    shadow=ft.BoxShadow(
                        spread_radius=0,
                        blur_radius=8,
                        color=ft.Colors.with_opacity(0.2, ft.Colors.BLACK),
                        offset=ft.Offset(0, 2),
                    ),
                ),
                on_tap=lambda _, path=asset_path: self._open_media_viewer(path),
            )
        return None

    def _render_choices(self) -> ft.Control:
        """Render choice buttons."""
        if not self.current_choices:
            return ft.Container()

        choice_buttons = []
        colors = [
            ["#667eea", "#764ba2"],  # Purple-blue gradient
            ["#f093fb", "#f5576c"],  # Pink gradient  
            ["#4facfe", "#00f2fe"],  # Blue gradient
        ]
        
        for i, choice in enumerate(self.current_choices):
            color_pair = colors[i % len(colors)]
            choice_buttons.append(
                ft.Container(
                    content=ft.GestureDetector(
                        content=ft.Container(
                            content=ft.Text(
                                choice.text,
                                size=16,
                                color=ft.Colors.WHITE,
                                weight=ft.FontWeight.W_500,
                                text_align=ft.TextAlign.CENTER,
                            ),
                            padding=ft.padding.symmetric(horizontal=24, vertical=16),
                            border_radius=25,
                            gradient=ft.LinearGradient(
                                colors=color_pair,
                                begin=ft.Alignment.TOP_LEFT,
                                end=ft.Alignment.BOTTOM_RIGHT,
                            ),
                        ),
                        on_tap=lambda e, idx=i: self._select_choice(idx),
                    ),
                    shadow=ft.BoxShadow(
                        spread_radius=0,
                        blur_radius=10,
                        color=ft.Colors.with_opacity(0.3, ft.Colors.BLACK),
                        offset=ft.Offset(0, 4),
                    ),
                    animate_opacity=300 + (i * 100),  # Staggered animation
                    animate_scale=200,
                )
            )

        return ft.Column(
            controls=choice_buttons,
            spacing=16,
            horizontal_alignment=ft.CrossAxisAlignment.STRETCH,
        )

    def _render_media_overlay(self) -> ft.Control:
        """Render media viewer overlay."""
        if not self._viewer_src:
            return ft.Container()

        return ft.Container(
            content=ft.Column([
                # Header with close button
                ft.Container(
                    content=ft.Row([
                        ft.Container(expand=True),
                        ft.IconButton(
                            icon=ft.icons.Icons.CLOSE,
                            icon_color=ft.Colors.WHITE,
                            icon_size=28,
                            on_click=lambda _: self._close_media_viewer(),
                        ),
                    ]),
                    padding=ft.padding.all(16),
                ),
                # Image content
                ft.Container(
                    content=ft.GestureDetector(
                        content=ft.Container(
                            content=ft.Image(
                                src=self._viewer_src, 
                                fit="contain",
                                border_radius=12,
                                error_content=ft.Text(
                                    "Image not found", 
                                    color=ft.Colors.WHITE70,
                                    size=16
                                ),
                            ),
                            alignment=ft.Alignment.CENTER,
                        ),
                        on_tap=lambda _: self._close_media_viewer(),
                    ),
                    expand=True,
                    alignment=ft.Alignment.CENTER,
                    padding=ft.padding.all(20),
                ),
                # Footer instructions
                ft.Container(
                    content=ft.Text(
                        "Tap image or close button to exit",
                        size=14,
                        color=ft.Colors.WHITE70,
                        text_align=ft.TextAlign.CENTER,
                    ),
                    padding=ft.padding.only(bottom=20),
                ),
            ], spacing=0),
            bgcolor=ft.Colors.with_opacity(0.95, ft.Colors.BLACK),
            expand=True,
        )

    # ------------------------------------------------------------------
    # Navigation and Utilities
    # ------------------------------------------------------------------

    def _back_to_chat_list(self):
        """Return to chat list with animation."""
        self._save_state()
        self.view_mode = "chat_list"
        self.current_chat_id = None
        # Add small delay for smooth transition
        self._update_ui()

    def _get_chat_name(self) -> str:
        """Get current chat display name."""
        if self.current_chat_id and self.engine and hasattr(self.engine, "chat_manager"):
            chat = self.engine.chat_manager.get_chat(self.current_chat_id)
            if chat:
                return chat.get("name", "Chat")
        return "Chat"

    def _load_settings(self):
        """Load settings from engine."""
        if not self.engine:
            return
        settings_app = self.engine.apps.get("settings")
        if settings_app:
            self.text_speed = settings_app.get_setting("text_speed", 1.0)
            self.auto_save_enabled = settings_app.get_setting("auto_save", True)

    def _handle_advance_without_scroll(self):
        """Handle advancing conversation while maintaining scroll position at bottom."""
        self._handle_advance()

    def after_render(self, page: ft.Page):
        """Force chat to stay at bottom: scroll to end instantly, no animation."""
        if (
            self._messages_listview is not None
            and self.view_mode == "conversation"
            and not getattr(self, "_viewer_open", False)
        ):
            try:
                self._messages_listview.scroll_to(offset=-1, duration=0)
                page.update()
            except Exception:
                pass

    def _update_ui(self):
        """Update the UI."""
        if self.engine:
            self.engine.update_ui()

    # ------------------------------------------------------------------
    # Keyboard Handling
    # ------------------------------------------------------------------

    def _on_keyboard_event(self, e: ft.KeyboardEvent):
        """Handle keyboard events."""
        if self.view_mode != "conversation":
            return

        if not hasattr(e, 'key') or not e.key:
            return

        key = e.key.strip()

        if key in ("Enter", "Space"):
            if self.showing_choices:
                return  # Don't advance when showing choices
            self._handle_advance()
        elif key in ("Digit1", "Digit2", "Digit3") and self.showing_choices:
            choice_idx = int(key[-1]) - 1  # Convert Digit1->0, Digit2->1, etc
            if 0 <= choice_idx < len(self.current_choices):
                self._select_choice(choice_idx)

    # ------------------------------------------------------------------
    # State Persistence (Simplified)
    # ------------------------------------------------------------------

    def _save_state(self):
        """Save current conversation state."""
        if not self.current_chat_id or not self.current_dialogue_id:
            return

        try:
            state = {
                "dialogue_id": self.current_dialogue_id,
                "current_node_id": self.current_node_id,
                "player_stats": self.player_stats.copy(),
                "displayed_messages": [
                    {
                        "node_id": msg.node_id,
                        "sender_id": msg.sender_id,
                        "content": msg.content,
                        "text": getattr(msg, "text", None),
                        "media": getattr(msg, "media", None),
                    }
                    for msg in self.displayed_messages[-50:]  # Save last 50 messages
                ],
            }

            saves_path = self.engine.saves_path if self.engine else Path("saves")
            state_file = Path(saves_path) / "conversation_states.json"
            state_file.parent.mkdir(exist_ok=True)

            all_states = {}
            if state_file.exists():
                with open(state_file, "r", encoding="utf-8") as f:
                    all_states = json.load(f)

            all_states[self.current_chat_id] = state

            with open(state_file, "w", encoding="utf-8") as f:
                json.dump(all_states, f, indent=2, ensure_ascii=False)

        except Exception as e:
            print(f"Error saving state: {e}")

    def _load_state(self, chat_id: str) -> bool:
        """Load saved conversation state."""
        try:
            saves_path = self.engine.saves_path if self.engine else Path("saves")
            state_file = Path(saves_path) / "conversation_states.json"
            
            if not state_file.exists():
                return False

            with open(state_file, "r", encoding="utf-8") as f:
                all_states = json.load(f)

            state = all_states.get(chat_id)
            if not state:
                return False

            # Get dialogue file from chat
            dialogue_file = None
            if self.engine and hasattr(self.engine, "chat_manager"):
                chat = self.engine.chat_manager.get_chat(chat_id)
                if chat:
                    dialogue_file = chat.get("dialogue_file")

            if not dialogue_file or not Path(dialogue_file).exists():
                return False

            # Load dialogue
            dialogue_path = Path(dialogue_file)
            self.parser.load_dialogue(dialogue_path)
            
            # Restore state
            self.current_dialogue_id = state.get("dialogue_id")
            self.current_node_id = state.get("current_node_id")
            self.player_stats.update(state.get("player_stats", {}))

            # Restore messages
            self.displayed_messages = []
            for msg_data in state.get("displayed_messages", []):
                msg = DialogueNode(
                    node_id=msg_data.get("node_id", ""),
                    sender_id=msg_data.get("sender_id", "unknown"),
                    content=msg_data.get("content", ""),
                    text=msg_data.get("text"),
                    media=msg_data.get("media"),
                    message_type=MessageType.TEXT,
                )
                self.displayed_messages.append(msg)

            # Set up current state
            if self.current_node_id:
                self.waiting_for_input = True
                self.showing_choices = False
                
                # Check if current node has choices
                node = self.parser.get_node(self.current_dialogue_id, self.current_node_id)
                if node and node.choices:
                    available_choices = self.parser.get_available_choices(node)
                    if available_choices:
                        self.showing_choices = True
                        self.current_choices = available_choices
                        self.waiting_for_input = False
            else:
                self.waiting_for_input = False
                self.showing_choices = False

            return True

        except Exception as e:
            print(f"Error loading state: {e}")
            return False

    # ------------------------------------------------------------------
    # Public API (for main.py compatibility)
    # ------------------------------------------------------------------

    def load_chat(self, dialogue_file: str, start_node: str = "start"):
        """Public API to load a chat (used by main.py)."""
        # This is called before the app is opened, so just ignore it
        # The actual chat loading happens when user opens a chat
        pass