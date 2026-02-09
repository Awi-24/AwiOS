"""
Gerenciador de backgrounds da aplicação.
Descobre automaticamente imagens em assets/images/.
"""

import json
from pathlib import Path
from typing import List, Dict, Any

SUPPORTED_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp"}


class BackgroundManager:
    """Gerencia os backgrounds disponíveis e selecionados"""

    def __init__(self, engine):
        self.engine = engine
        base = getattr(engine, "saves_path", None) or Path("saves")
        self.config_file = Path(base) / "background_config.json"
        self.config_file.parent.mkdir(exist_ok=True)

        self.assets_path = getattr(engine, "assets_path", None) or Path("assets")

        self.available_backgrounds: List[Dict[str, Any]] = []
        self.current_background = "default"

        # Descobre imagens automaticamente e carrega config salva
        self._discover_images()
        self._load_config()

    # ------------------------------------------------------------------
    # Descoberta automática
    # ------------------------------------------------------------------

    def _discover_images(self):
        """Escaneia assets/images/ e cria a lista de backgrounds."""
        self.available_backgrounds = []

        images_dir = Path(self.assets_path) / "images"
        if not images_dir.exists():
            return

        for img_file in sorted(images_dir.iterdir()):
            if not img_file.is_file():
                continue
            if img_file.suffix.lower() not in SUPPORTED_IMAGE_EXTENSIONS:
                continue

            bg_id = img_file.stem  # ex: "test", "bg1", "bg2"
            rel_path = str(Path("assets/images") / img_file.name)
            display_name = img_file.stem.replace("_", " ").title()

            self.available_backgrounds.append({
                "id": bg_id,
                "name": display_name,
                "path": rel_path,
                "unlocked": True,  # todas desbloqueadas por padrão
            })

        # Garante que "test" (se existir) seja o primeiro e sirva de default
        self.available_backgrounds.sort(
            key=lambda b: (0 if b["id"] == "test" else 1, b["id"])
        )

        print(f"[Backgrounds] {len(self.available_backgrounds)} imagens descobertas")

    # ------------------------------------------------------------------
    # Persistência
    # ------------------------------------------------------------------

    def _load_config(self):
        """Carrega configuração salva (background atual + lista de bloqueados)."""
        if not self.config_file.exists():
            return
        try:
            with open(self.config_file, "r", encoding="utf-8") as f:
                config = json.load(f)
            self.current_background = config.get("current_background", "default")
            locked = set(config.get("locked_backgrounds", []))
            for bg in self.available_backgrounds:
                if bg["id"] in locked:
                    bg["unlocked"] = False
        except Exception as e:
            print(f"Error loading background config: {e}")

    def save_config(self):
        """Salva configuração de backgrounds."""
        try:
            locked = [bg["id"] for bg in self.available_backgrounds if not bg["unlocked"]]
            config = {
                "current_background": self.current_background,
                "locked_backgrounds": locked,
            }
            with open(self.config_file, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving background config: {e}")

    # ------------------------------------------------------------------
    # API pública
    # ------------------------------------------------------------------

    def get_current_background_path(self) -> str:
        """Retorna o caminho do background atual."""
        for bg in self.available_backgrounds:
            if bg["id"] == self.current_background:
                return bg["path"]
        # Fallback: caminho direto ou primeira imagem disponível
        if self.current_background and Path(self.current_background).exists():
            return self.current_background
        if self.available_backgrounds:
            return self.available_backgrounds[0]["path"]
        return "assets/images/test.png"

    def set_background(self, background_id: str) -> bool:
        """Define um novo background (precisa estar desbloqueado)."""
        for bg in self.available_backgrounds:
            if bg["id"] == background_id and bg["unlocked"]:
                self.current_background = background_id
                self.save_config()
                return True
        return False

    def unlock_background(self, background_id: str):
        """Desbloqueia um background."""
        for bg in self.available_backgrounds:
            if bg["id"] == background_id:
                bg["unlocked"] = True
                self.save_config()
                break

    def get_available_backgrounds(self) -> List[Dict[str, Any]]:
        """Retorna lista de backgrounds disponíveis."""
        return self.available_backgrounds.copy()

    def get_unlocked_backgrounds(self) -> List[Dict[str, Any]]:
        """Retorna apenas backgrounds desbloqueados."""
        return [bg for bg in self.available_backgrounds if bg["unlocked"]]

    def refresh(self):
        """Re-escaneia assets/images/ (útil após adicionar novas imagens)."""
        saved_current = self.current_background
        self._discover_images()
        self.current_background = saved_current
        self._load_config()
