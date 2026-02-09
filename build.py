"""
Script de build para criar executável com PyInstaller
"""

import subprocess
import sys
from pathlib import Path


def build_executable():
    """Cria um executável usando PyInstaller"""
    print("Construindo executável com PyInstaller...")
    
    # Comando PyInstaller
    cmd = [
        "pyinstaller",
        "--name=AwiOS",
        "--onefile",
        "--windowed",  # Sem console no Windows
        "--add-data=assets;assets",  # Inclui assets (Windows)
        "--add-data=locales;locales",  # Inclui traduções (Windows)
        "--hidden-import=flet",
        "--hidden-import=src",
        "main.py"
    ]
    
    # Ajusta para Linux/Mac
    if sys.platform != "win32":
        cmd[4] = "--add-data=assets:assets"
        cmd[5] = "--add-data=locales:locales"
    
    try:
        subprocess.run(cmd, check=True)
        print("Build concluído! Executável em dist/AwiOS")
    except subprocess.CalledProcessError as e:
        print(f"Erro no build: {e}")
        sys.exit(1)
    except FileNotFoundError:
        print("PyInstaller não encontrado. Instale com: pip install pyinstaller")
        sys.exit(1)


if __name__ == "__main__":
    build_executable()
