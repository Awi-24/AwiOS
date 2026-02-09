"""
Carregador de configurações
"""

import json
from pathlib import Path
from typing import Dict, Any


class ConfigLoader:
    """Carrega e gerencia configurações do arquivo config.json"""
    
    def __init__(self, config_path: str = "config.json"):
        """
        Inicializa o carregador de configurações.
        
        Args:
            config_path: Caminho para o arquivo de configuração
        """
        self.config_path = Path(config_path)
        self.config: Dict[str, Any] = {}
        self.load()
    
    def load(self):
        """Carrega o arquivo de configuração"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    self.config = json.load(f)
            except Exception as e:
                print(f"Error loading configuration: {e}")
                self.config = self._default_config()
        else:
            self.config = self._default_config()
    
    def _default_config(self) -> Dict[str, Any]:
        """Retorna a configuração padrão"""
        return {
            "engine": {
                "assets_path": "assets",
                "saves_path": "saves",
                "locales_path": "locales",
                "default_language": "en_US"
            },
            "ui": {
                "theme_mode": "dark",
                "window_width": 400,
                "window_height": 800,
                "phone_width": 360,
                "phone_height": 720
            },
            "performance": {
                "max_cache_size": 50,
                "lazy_load_assets": True,
                "preload_common_assets": True
            },
            "features": {
                "rollback_enabled": True,
                "skip_enabled": True,
                "auto_read_enabled": True,
                "gallery_persistent": True,
                "hot_reload": False
            }
        }
    
    def get(self, key: str, default: Any = None) -> Any:
        """
        Obtém um valor de configuração usando notação de ponto.
        
        Args:
            key: Chave da configuração (ex: "engine.assets_path")
            default: Valor padrão se não encontrado
            
        Returns:
            Valor da configuração ou default
        """
        keys = key.split('.')
        current = self.config
        
        for k in keys:
            if isinstance(current, dict) and k in current:
                current = current[k]
            else:
                return default
        
        return current
    
    def save(self):
        """Salva a configuração de volta para o arquivo"""
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving configuration: {e}")
