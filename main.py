"""
AwiOS - Visual Novel Engine
Main entry point for the application.
"""

from src.core.engine import MobileEngine
from src.apps.messages_app import MessagesApp
from src.apps.gallery_app import GalleryApp
from src.apps.settings_app import SettingsApp
from src.utils.config_loader import ConfigLoader


def main():
    """Main entry point."""
    # Load configuration
    config = ConfigLoader()
    
    # Create engine with config
    engine = MobileEngine(
        assets_path=config.get("engine.assets_path", "assets"),
        saves_path=config.get("engine.saves_path", "saves"),
        locales_path=config.get("engine.locales_path", "locales")
    )

    # Apply default language from config (if no saved override)
    default_lang = config.get("engine.default_language", None)
    if default_lang and engine.get_setting("language", None) is None:
        engine.set_setting("language", default_lang)
        engine.i18n.set_language(default_lang)
    
    # Configure asset manager
    engine.asset_manager.max_cache_size = config.get("performance.max_cache_size", 50)
    
    # Register core apps (messages, gallery, settings only)
    messages_app = MessagesApp()
    gallery_app = GalleryApp()
    settings_app = SettingsApp()
    
    engine.register_app(messages_app)
    engine.register_app(gallery_app)
    engine.register_app(settings_app)

    # Load default tutorial (new users start here)
    messages_app.load_chat("assets/dialogues/complete_tutorial.json")
    
    # Load plugin apps automatically
    engine.load_apps()
    
    # Start the engine
    title = "AwiOS - Visual Novel Engine"
    engine.run(title=title)


if __name__ == "__main__":
    main()
