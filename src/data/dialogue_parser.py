"""
Parser de diálogos em JSON
Suporta ramificações, condições, mídias e escolhas do jogador.
"""

import json
from pathlib import Path
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass
from enum import Enum


class MessageType(Enum):
    """Tipos de mensagem suportados"""
    TEXT = "text"
    IMAGE = "image"
    VIDEO = "video"
    AUDIO = "audio"
    SYSTEM = "system"


@dataclass
class Choice:
    """Representa uma escolha do jogador"""
    text: str
    next_node: str
    condition: Optional[Dict[str, Any]] = None
    effects: Optional[Any] = None
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Choice':
        """Cria uma Choice a partir de um dicionário"""
        return cls(
            text=data.get("text", ""),
            next_node=data.get("next", ""),
            condition=data.get("conditions"),
            effects=data.get("effects"),
        )


@dataclass
class DialogueNode:
    """Representa um nó de diálogo"""
    node_id: str
    sender_id: str
    content: str
    message_type: MessageType = MessageType.TEXT
    choices: List[Choice] = None
    condition: Optional[Dict[str, Any]] = None
    next_node: Optional[str] = None
    metadata: Dict[str, Any] = None
    media: Optional[Dict[str, Any]] = None  # Novo campo para mídia
    text: Optional[str] = None  # Campo de texto separado
    character: Optional[str] = None  # Campo de personagem
    
    def __post_init__(self):
        if self.choices is None:
            self.choices = []
        if self.metadata is None:
            self.metadata = {}
        if self.media is None:
            self.media = {}
    
    @classmethod
    def from_dict(cls, node_id: str, data: Dict[str, Any]) -> 'DialogueNode':
        """Cria um DialogueNode a partir de um dicionário"""
        # Determina o tipo de mensagem
        node_type = data.get("type", "text")
        # Mapeia tipos de nós para tipos de mensagem
        if node_type in ["message", "choice"]:
            msg_type = MessageType.TEXT
        else:
            try:
                msg_type = MessageType(node_type)
            except ValueError:
                msg_type = MessageType.TEXT
        
        # Processa escolhas
        choices = []
        if "choices" in data:
            for choice_data in data["choices"]:
                choices.append(Choice.from_dict(choice_data))
        
        return cls(
            node_id=node_id,
            sender_id=data.get("sender_id", data.get("character", "unknown")),
            content=data.get("content", data.get("text", "")),
            message_type=msg_type,
            choices=choices,
            condition=data.get("conditions"),
            next_node=data.get("next"),
            metadata=data.get("metadata", {}),
            media=data.get("media"),
            text=data.get("text"),
            character=data.get("character")
        )
    
    def to_dict(self) -> Dict[str, Any]:
        """Converte o nó de volta para dicionário"""
        result = {
            "sender_id": self.sender_id,
            "content": self.content,
            "type": self.message_type.value
        }
        
        if self.choices:
            result["choices"] = [
                {
                    "text": c.text,
                    "next": c.next_node,
                    "conditions": c.condition
                }
                for c in self.choices
            ]
        
        if self.condition:
            result["conditions"] = self.condition
        
        if self.next_node:
            result["next"] = self.next_node
        
        if self.metadata:
            result["metadata"] = self.metadata
        
        return result


class DialogueParser:
    """
    Parser para arquivos JSON de diálogo.
    Suporta ramificações, condições, mídias e escolhas.
    """
    
    def __init__(self, engine=None):
        """
        Inicializa o parser.
        
        Args:
            engine: Referência opcional para a MobileEngine (para verificar condições)
        """
        self.engine = engine
        self.dialogues: Dict[str, Dict[str, DialogueNode]] = {}
    
    def load_dialogue(self, file_path: Union[str, Path]) -> Dict[str, DialogueNode]:
        """
        Carrega um arquivo JSON de diálogo.
        
        Args:
            file_path: Caminho para o arquivo JSON
            
        Returns:
            Dicionário mapeando node_id -> DialogueNode
        """
        file_path = Path(file_path)
        
        if not file_path.exists():
            raise FileNotFoundError(f"Arquivo de diálogo não encontrado: {file_path}")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Processa os nós
        nodes = {}
        # Se há uma seção "nodes", usa ela, senão usa o JSON inteiro
        nodes_data = data.get("nodes", data)
        for node_id, node_data in nodes_data.items():
            # Ignora seções metadata, characters, comentários e documentação
            if node_id in ["metadata", "characters"]:
                continue
            # Ignora entradas que começam com _ (comentários/documentação)
            if node_id.startswith("_"):
                continue
            # Ignora entradas que não são dicionários válidos
            if not isinstance(node_data, dict):
                continue
            nodes[node_id] = DialogueNode.from_dict(node_id, node_data)
        
        # Armazena o diálogo (usando o nome do arquivo como chave)
        dialogue_id = file_path.stem
        self.dialogues[dialogue_id] = nodes
        
        return nodes
    
    def get_node(self, dialogue_id: str, node_id: str) -> Optional[DialogueNode]:
        """
        Obtém um nó específico de um diálogo.
        
        Args:
            dialogue_id: ID do diálogo
            node_id: ID do nó
            
        Returns:
            DialogueNode ou None se não encontrado
        """
        if dialogue_id not in self.dialogues:
            return None
        
        return self.dialogues[dialogue_id].get(node_id)
    
    def get_start_node(self, dialogue_id: str) -> Optional[DialogueNode]:
        """
        Obtém o nó inicial de um diálogo (geralmente "start").
        
        Args:
            dialogue_id: ID do diálogo
            
        Returns:
            DialogueNode inicial ou None se não encontrado
        """
        return self.get_node(dialogue_id, "start")
    
    def check_node_condition(self, node: DialogueNode) -> bool:
        """
        Verifica se as condições de um nó são satisfeitas.
        
        Args:
            node: Nó a ser verificado
            
        Returns:
            True se as condições forem satisfeitas
        """
        if not node.condition:
            return True
        
        if self.engine:
            return self.engine.check_condition(node.condition)
        
        # Se não há engine, assume que a condição é verdadeira
        return True
    
    def get_available_choices(self, node: DialogueNode) -> List[Choice]:
        """
        Retorna apenas as escolhas cujas condições são satisfeitas.
        
        Args:
            node: Nó com as escolhas
            
        Returns:
            Lista de escolhas disponíveis
        """
        if not node.choices:
            return []
        
        available = []
        for choice in node.choices:
            if not choice.condition or self.check_node_condition(
                DialogueNode("temp", "temp", "", condition=choice.condition)
            ):
                available.append(choice)
        
        return available
    
    def get_next_node(self, node: DialogueNode, choice_index: Optional[int] = None) -> Optional[str]:
        """
        Obtém o próximo nó baseado em uma escolha ou no next padrão.
        
        Args:
            node: Nó atual
            choice_index: Índice da escolha selecionada (None para usar next padrão)
            
        Returns:
            ID do próximo nó ou None
        """
        if choice_index is not None and node.choices:
            if 0 <= choice_index < len(node.choices):
                return node.choices[choice_index].next_node
        
        return node.next_node
    
    def save_dialogue(self, dialogue_id: str, file_path: Union[str, Path]):
        """
        Salva um diálogo de volta para JSON.
        
        Args:
            dialogue_id: ID do diálogo
            file_path: Caminho onde salvar o arquivo
        """
        if dialogue_id not in self.dialogues:
            raise ValueError(f"Diálogo '{dialogue_id}' não encontrado")
        
        file_path = Path(file_path)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        data = {
            node_id: node.to_dict()
            for node_id, node in self.dialogues[dialogue_id].items()
        }
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
