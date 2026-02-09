"""
Gerenciador de conversas e notificações
"""

import json
import time
from pathlib import Path
from typing import Dict, List, Any, Optional
import flet as ft


class ChatManager:
    """Gerencia múltiplas conversas e notificações"""

    def __init__(self, engine):
        self.engine = engine
        base = getattr(engine, "saves_path", None) or Path("saves")
        self.chats_file = Path(base) / "chats_state.json"
        self.chats_file.parent.mkdir(exist_ok=True)

        self.chats: Dict[str, Dict[str, Any]] = {}
        self.active_chat_id: Optional[str] = None
        self.unread_messages: Dict[str, int] = {}

        self.load_chats_state()
        self._initialize_default_chats()

    # ------------------------------------------------------------------
    # Chats padrão
    # ------------------------------------------------------------------

    def _initialize_default_chats(self):
        """Registra chats padrão se ainda não existirem."""
        default_chats = [
            {
                "id": "complete_tutorial",
                "name": "AwiOS Tutorial",
                "avatar": "assets/images/test.png", 
                "dialogue_file": "assets/dialogues/complete_tutorial.json",
                "last_message": "Welcome to the complete AwiOS tutorial!",
                "last_message_time": time.time() - 300,
                "unread_count": 1,
                "status": "online",
            },
        ]

        for chat in default_chats:
            if chat["id"] not in self.chats:
                self.chats[chat["id"]] = chat
                self.unread_messages[chat["id"]] = chat["unread_count"]

    # ------------------------------------------------------------------
    # Persistência
    # ------------------------------------------------------------------

    def load_chats_state(self):
        if self.chats_file.exists():
            try:
                with open(self.chats_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self.chats = data.get("chats", {})
                self.unread_messages = data.get("unread_messages", {})
                self.active_chat_id = data.get("active_chat_id")
            except Exception as e:
                print(f"Error loading chats: {e}")

    def save_chats_state(self):
        try:
            data = {
                "chats": self.chats,
                "unread_messages": self.unread_messages,
                "active_chat_id": self.active_chat_id,
                "last_updated": time.time(),
            }
            with open(self.chats_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving chats: {e}")

    # ------------------------------------------------------------------
    # API pública
    # ------------------------------------------------------------------

    def get_chat_list(self) -> List[Dict[str, Any]]:
        """Retorna lista de chats ordenada por última mensagem."""
        chat_list = list(self.chats.values())
        chat_list.sort(key=lambda x: x.get("last_message_time", 0), reverse=True)
        return chat_list

    def get_chat(self, chat_id: str) -> Optional[Dict[str, Any]]:
        return self.chats.get(chat_id)

    def open_chat(self, chat_id: str):
        if chat_id in self.chats:
            self.active_chat_id = chat_id
            self.mark_messages_as_read(chat_id)
            self.save_chats_state()

    def mark_messages_as_read(self, chat_id: str):
        if chat_id in self.unread_messages:
            self.unread_messages[chat_id] = 0
        if chat_id in self.chats:
            self.chats[chat_id]["unread_count"] = 0

    def add_new_message(self, chat_id: str, message: str, from_player: bool = False):
        if chat_id not in self.chats:
            return
        self.chats[chat_id]["last_message"] = message
        self.chats[chat_id]["last_message_time"] = time.time()

        if not from_player:
            self.unread_messages[chat_id] = self.unread_messages.get(chat_id, 0) + 1
            self.chats[chat_id]["unread_count"] = self.unread_messages[chat_id]
            if chat_id != self.active_chat_id:
                self._show_message_notification(chat_id, message)

        self.save_chats_state()

    def _show_message_notification(self, chat_id: str, message: str):
        if not (self.engine and self.engine.page):
            return
        chat = self.chats.get(chat_id)
        if not chat:
            return
        self.engine.page.snack_bar = ft.SnackBar(
            content=ft.Row([
                ft.Icon(ft.icons.Icons.MESSAGE, color=ft.Colors.WHITE),
                ft.Column([
                    ft.Text(chat["name"], weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE, size=12),
                    ft.Text(
                        message[:50] + "..." if len(message) > 50 else message,
                        color=ft.Colors.WHITE, size=11,
                    ),
                ], spacing=2),
            ], spacing=8),
            duration=3000,
            bgcolor=ft.Colors.BLUE_600,
        )
        self.engine.page.snack_bar.open = True
        self.engine.page.update()

    def get_total_unread_count(self) -> int:
        return sum(self.unread_messages.values())

    def get_unread_count(self, chat_id: str) -> int:
        return self.unread_messages.get(chat_id, 0)

    def format_time(self, timestamp: float) -> str:
        diff = time.time() - timestamp
        if diff < 60:
            return "now"
        if diff < 3600:
            return f"{int(diff / 60)}m"
        if diff < 86400:
            return f"{int(diff / 3600)}h"
        return f"{int(diff / 86400)}d"
