"""
Sistema de Internacionalização (i18n)
Suporta múltiplos idiomas e troca dinâmica de idioma
"""

import json
from pathlib import Path
from typing import Dict, Optional


class I18n:
    """
    Gerenciador de internacionalização.
    Carrega arquivos de tradução e fornece strings traduzidas.
    """
    
    def __init__(self, locales_path: str = "locales", default_language: str = "en_US"):
        """
        Inicializa o sistema de i18n.
        
        Args:
            locales_path: Caminho para os arquivos de tradução
            default_language: Idioma padrão (formato: pt_BR, en_US, etc.)
        """
        self.locales_path = Path(locales_path)
        self.default_language = default_language
        self.current_language = default_language
        self.translations: Dict[str, Dict[str, str]] = {}
        
        # Carrega traduções disponíveis
        self._load_translations()
    
    def _load_translations(self):
        """Carrega todos os arquivos de tradução disponíveis"""
        if not self.locales_path.exists():
            self.locales_path.mkdir(parents=True, exist_ok=True)
            return
        
        for locale_file in self.locales_path.glob("*.json"):
            language = locale_file.stem
            try:
                with open(locale_file, 'r', encoding='utf-8') as f:
                    self.translations[language] = json.load(f)
            except Exception as e:
                print(f"Error loading translation {language}: {e}")
    
    def set_language(self, language: str) -> bool:
        """
        Define o idioma atual.
        
        Args:
            language: Código do idioma (ex: "pt_BR", "en_US")
            
        Returns:
            True se o idioma foi alterado com sucesso
        """
        if language in self.translations:
            self.current_language = language
            return True
        return False
    
    def get(self, key: str, default: Optional[str] = None, **kwargs) -> str:
        """
        Obtém uma string traduzida.
        
        Args:
            key: Chave da tradução (pode usar notação de ponto: "app.messages.title")
            default: Valor padrão se a chave não for encontrada
            **kwargs: Variáveis para substituição na string (ex: name="João")
            
        Returns:
            String traduzida
        """
        # Tenta obter a tradução do idioma atual
        translation = self._get_nested(
            self.translations.get(self.current_language, {}),
            key
        )
        
        # Se não encontrou, tenta o idioma padrão
        if translation is None:
            translation = self._get_nested(
                self.translations.get(self.default_language, {}),
                key
            )
        
        # Se ainda não encontrou, usa a chave ou o default
        if translation is None:
            translation = default if default is not None else key
        
        # Substitui variáveis na string
        if kwargs:
            try:
                translation = translation.format(**kwargs)
            except KeyError:
                pass
        
        return translation
    
    def _get_nested(self, data: dict, key: str) -> Optional[str]:
        """
        Obtém um valor aninhado usando notação de ponto.
        
        Args:
            data: Dicionário de dados
            key: Chave com notação de ponto (ex: "app.messages.title")
            
        Returns:
            Valor encontrado ou None
        """
        keys = key.split('.')
        current = data
        
        for k in keys:
            if isinstance(current, dict) and k in current:
                current = current[k]
            else:
                return None
        
        return current if isinstance(current, str) else None
    
    def t(self, key: str, default: Optional[str] = None, **kwargs) -> str:
        """
        Alias para get() - método mais curto para tradução.
        
        Args:
            key: Chave da tradução
            default: Valor padrão
            **kwargs: Variáveis para substituição
            
        Returns:
            String traduzida
        """
        return self.get(key, default, **kwargs)
