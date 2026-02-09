"""
Gerenciador de Assets
Implementa lazy loading e cache de recursos
"""

from pathlib import Path
from typing import Dict, Optional, Any
import flet as ft


class AssetManager:
    """
    Gerencia o carregamento e cache de assets (imagens, áudio, vídeo).
    Implementa lazy loading para otimizar o uso de memória.
    """
    
    def __init__(self, assets_path: str = "assets"):
        """
        Inicializa o gerenciador de assets.
        
        Args:
            assets_path: Caminho base para os assets
        """
        self.assets_path = Path(assets_path)
        self.cache: Dict[str, Any] = {}
        self.max_cache_size = 50  # Máximo de assets em cache
    
    def get_image_path(self, relative_path: str) -> Path:
        """
        Obtém o caminho completo de uma imagem.
        
        Args:
            relative_path: Caminho relativo da imagem
            
        Returns:
            Path completo do arquivo
        """
        return self.assets_path / "images" / relative_path
    
    def get_audio_path(self, relative_path: str) -> Path:
        """
        Obtém o caminho completo de um áudio.
        
        Args:
            relative_path: Caminho relativo do áudio
            
        Returns:
            Path completo do arquivo
        """
        return self.assets_path / "audio" / relative_path
    
    def get_video_path(self, relative_path: str) -> Path:
        """
        Obtém o caminho completo de um vídeo.
        
        Args:
            relative_path: Caminho relativo do vídeo
            
        Returns:
            Path completo do arquivo
        """
        return self.assets_path / "video" / relative_path
    
    def load_image(self, relative_path: str, cache: bool = True) -> Optional[str]:
        """
        Carrega uma imagem e retorna o caminho.
        Se cache=True, armazena o caminho em cache.
        
        Args:
            relative_path: Caminho relativo da imagem
            cache: Se deve armazenar em cache
            
        Returns:
            Caminho da imagem ou None se não encontrada
        """
        cache_key = f"image:{relative_path}"
        
        # Verifica cache
        if cache_key in self.cache:
            return self.cache[cache_key]
        
        # Verifica se o arquivo existe
        image_path = self.get_image_path(relative_path)
        if not image_path.exists():
            print(f"Imagem não encontrada: {image_path}")
            return None
        
        # Converte para string (Flet aceita strings de caminho)
        path_str = str(image_path.absolute())
        
        # Adiciona ao cache se solicitado
        if cache:
            self._add_to_cache(cache_key, path_str)
        
        return path_str
    
    def load_audio(self, relative_path: str, cache: bool = True) -> Optional[str]:
        """
        Carrega um arquivo de áudio e retorna o caminho.
        
        Args:
            relative_path: Caminho relativo do áudio
            cache: Se deve armazenar em cache
            
        Returns:
            Caminho do áudio ou None se não encontrado
        """
        cache_key = f"audio:{relative_path}"
        
        if cache_key in self.cache:
            return self.cache[cache_key]
        
        audio_path = self.get_audio_path(relative_path)
        if not audio_path.exists():
            print(f"Áudio não encontrado: {audio_path}")
            return None
        
        path_str = str(audio_path.absolute())
        
        if cache:
            self._add_to_cache(cache_key, path_str)
        
        return path_str
    
    def load_video(self, relative_path: str, cache: bool = True) -> Optional[str]:
        """
        Carrega um arquivo de vídeo e retorna o caminho.
        
        Args:
            relative_path: Caminho relativo do vídeo
            cache: Se deve armazenar em cache
            
        Returns:
            Caminho do vídeo ou None se não encontrado
        """
        cache_key = f"video:{relative_path}"
        
        if cache_key in self.cache:
            return self.cache[cache_key]
        
        video_path = self.get_video_path(relative_path)
        if not video_path.exists():
            print(f"Vídeo não encontrado: {video_path}")
            return None
        
        path_str = str(video_path.absolute())
        
        if cache:
            self._add_to_cache(cache_key, path_str)
        
        return path_str
    
    def _add_to_cache(self, key: str, value: Any):
        """
        Adiciona um item ao cache, removendo o mais antigo se necessário.
        
        Args:
            key: Chave do cache
            value: Valor a ser armazenado
        """
        # Remove o mais antigo se o cache estiver cheio
        if len(self.cache) >= self.max_cache_size:
            # Remove o primeiro item (FIFO)
            oldest_key = next(iter(self.cache))
            del self.cache[oldest_key]
        
        self.cache[key] = value
    
    def clear_cache(self):
        """Limpa o cache de assets"""
        self.cache.clear()
    
    def preload_assets(self, asset_list: list):
        """
        Pré-carrega uma lista de assets.
        
        Args:
            asset_list: Lista de tuplas (tipo, caminho_relativo)
                       Ex: [("image", "avatar/waifu_01.png"), ("audio", "bgm/main_theme.mp3")]
        """
        for asset_type, relative_path in asset_list:
            if asset_type == "image":
                self.load_image(relative_path)
            elif asset_type == "audio":
                self.load_audio(relative_path)
            elif asset_type == "video":
                self.load_video(relative_path)
