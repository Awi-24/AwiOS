"""
Classe base para aplicativos do AWI Engine.
Todos os aplicativos devem herdar desta classe.
"""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any, Union
import flet as ft
from src.utils.i18n import I18n
from src.utils.asset_manager import AssetManager


class App(ABC):
    """
    Classe base abstrata para todos os aplicativos do AWI Engine.
    
    Cada aplicativo deve implementar os métodos abstratos e pode
    sobrescrever os métodos opcionais para customizar o comportamento.
    """
    
    def __init__(self):
        """Inicializa o aplicativo"""
        self.app_id: str = ""
        self.name: str = ""
        self.icon: Union[ft.icons.Icons, str] = ft.icons.Icons.APPS  # Ícone padrão
        self.engine: Optional[Any] = None  # MobileEngine instance
    
    def set_engine(self, engine):
        """Define a referência para a engine principal"""
        self.engine = engine
    
    @abstractmethod
    def render(self, page: ft.Page):
        """
        Renderiza a interface do aplicativo na página.
        
        Args:
            page: Instância do Flet Page onde o aplicativo será renderizado
        """
        pass
    
    def on_open(self):
        """
        Chamado quando o aplicativo é aberto.
        Pode ser sobrescrito para inicializar recursos específicos.
        """
        pass
    
    def on_close(self):
        """
        Chamado quando o aplicativo é fechado.
        Pode ser sobrescrito para limpar recursos específicos.
        """
        pass
    
    def on_update(self):
        """
        Chamado a cada frame de atualização.
        Pode ser sobrescrito para atualizações contínuas.
        """
        pass
    
    def get_variable(self, name: str, default: Any = None) -> Any:
        """Obtém uma variável de estado da engine"""
        if self.engine:
            return self.engine.get_variable(name, default)
        return default
    
    def set_variable(self, name: str, value: Any):
        """Define uma variável de estado na engine"""
        if self.engine:
            self.engine.set_variable(name, value)

    def get_setting(self, name: str, default: Any = None) -> Any:
        """Obtém uma configuração persistente (engine.state.settings)."""
        if self.engine and hasattr(self.engine, "get_setting"):
            return self.engine.get_setting(name, default)
        if self.engine and hasattr(self.engine, "state") and hasattr(self.engine.state, "settings"):
            return (self.engine.state.settings or {}).get(name, default)
        return default

    def set_setting(self, name: str, value: Any):
        """Define uma configuração persistente (engine.state.settings)."""
        if self.engine and hasattr(self.engine, "set_setting"):
            return self.engine.set_setting(name, value)
        if self.engine and hasattr(self.engine, "state") and hasattr(self.engine.state, "settings"):
            if self.engine.state.settings is None:
                self.engine.state.settings = {}
            self.engine.state.settings[name] = value
    
    def check_condition(self, condition: Dict[str, Any]) -> bool:
        """Verifica uma condição usando o sistema da engine"""
        if self.engine:
            return self.engine.check_condition(condition)
        return False
    
    def close(self):
        """Fecha o aplicativo atual"""
        if self.engine:
            self.engine.close_app()
    
    def add_notification(self, title: str, content: str, icon: Optional[str] = None):
        """Adiciona uma notificação à tela de bloqueio"""
        if self.engine:
            self.engine.add_notification(self.app_id, title, content, icon)
    
    def get_i18n(self) -> Optional[I18n]:
        """Obtém o gerenciador de internacionalização"""
        if self.engine:
            return self.engine.get_i18n()
        return None
    
    def get_asset_manager(self) -> Optional[AssetManager]:
        """Obtém o gerenciador de assets"""
        if self.engine:
            return self.engine.get_asset_manager()
        return None
    
    def t(self, key: str, default: Optional[str] = None, **kwargs) -> str:
        """
        Método auxiliar para tradução.
        
        Args:
            key: Chave da tradução
            default: Valor padrão
            **kwargs: Variáveis para substituição
            
        Returns:
            String traduzida ou a chave se não houver tradução
        """
        i18n = self.get_i18n()
        if i18n:
            return i18n.t(key, default, **kwargs)
        return default if default else key
