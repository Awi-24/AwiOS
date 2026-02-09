# 🎨 Guia para Criadores - AwiOS Engine

**Crie suas próprias Visual Novels SEM PROGRAMAR!**

Este guia é para você que quer criar histórias interativas mas não sabe programar.

---

## 🚀 Início Rápido (3 Passos)

### 1️⃣ Execute o Jogo
```bash
python main.py
```

### 2️⃣ Jogue o Tutorial
Abra o app **Messages** e jogue o chat **AwiOS Tutorial** (complete_tutorial.json). Ele mostra mensagens, escolhas, efeitos, mídia e condições.

### 3️⃣ Crie Sua História
Copie `assets/dialogues/complete_tutorial.json` para um novo arquivo (ex: `minha_historia.json`) e edite. Ou crie um JSON do zero seguindo a estrutura abaixo.

---

## 📝 Como Criar uma História

### Passo 1: Copie o tutorial ou crie um arquivo
```bash
# Na pasta assets/dialogues/:
# Copie complete_tutorial.json para minha_historia.json
# Ou crie um novo arquivo minha_historia.json
```

### Passo 2: Edite com um Editor de Texto
Qualquer editor funciona:
- **Notepad** (Windows)
- **TextEdit** (Mac)  
- **Notepad++** (recomendado)
- **VS Code** (melhor com plugin JSON)

### Passo 3: Preencha as Informações

```json
{
  "metadata": {
    "title": "Minha Primeira História",
    "description": "Uma aventura emocionante",
    "author": "Seu Nome"
  }
}
```

### Passo 4: Defina os Personagens

```json
{
  "characters": {
    "player": {
      "name": "Você",
      "color": "#2196F3"
    },
    "amigo": {
      "name": "Seu Melhor Amigo",
      "color": "#4CAF50"
    }
  }
}
```

### Passo 5: Crie as Mensagens

```json
{
  "nodes": {
    "start": {
      "type": "message",
      "character": "amigo",
      "text": "Oi! Como você está hoje?",
      "next": "resposta"
    },
    
    "resposta": {
      "type": "choice",
      "character": "amigo",
      "text": "Conte-me!",
      "choices": [
        {
          "text": "Estou ótimo! 😊",
          "next": "feliz",
          "effects": {
            "affection": 2,
            "points": 10
          }
        },
        {
          "text": "Poderia estar melhor... 😔",
          "next": "triste",
          "effects": {
            "trust": 1,
            "points": 5
          }
        }
      ]
    },
    
    "feliz": {
      "type": "message",
      "character": "amigo",
      "text": "Que bom! Fico feliz por você!",
      "next": null
    },
    
    "triste": {
      "type": "message",
      "character": "amigo",
      "text": "Sinto muito... Quer conversar sobre isso?",
      "next": null
    }
  }
}
```

---

## 🎯 Recursos Principais

### ✉️ Mensagens Simples
```json
{
  "type": "message",
  "character": "nome_personagem",
  "text": "Olá! Bem-vindo!",
  "next": "proximo_no"
}
```

### 🔀 Escolhas
```json
{
  "type": "choice",
  "character": "personagem",
  "text": "Pergunta?",
  "choices": [
    {
      "text": "Opção 1",
      "next": "caminho_1",
      "effects": {
        "affection": 2,
        "points": 10
      }
    }
  ]
}
```

### 📊 Sistema de Stats
Suas escolhas afetam 4 stats principais:
- ❤️ **affection** - Afeição/romance
- ⭐ **points** - Pontuação geral
- 🤝 **trust** - Confiança
- 💀 **corruption** - Escolhas sombrias

```json
"effects": {
  "affection": 5,    // Aumenta
  "trust": -2,       // Diminui
  "points": 10
}
```

### 🖼️ Imagens
```json
{
  "text": "Olhe esta foto!",
  "media": {
    "type": "image",
    "src": "images/foto.png"
  }
}
```

**Como adicionar suas imagens:**
1. Coloque a imagem em: `assets/images/`
2. Use o nome no `src`: `"images/sua_foto.png"`

**Nota (v1.0):** Áudio em mensagens não é reproduzido nesta versão. Use `image`, `gif` ou `video`.

---

## 🎮 Controles do Jogo

- **CLIQUE / ENTER / SPACE** – Avançar mensagem (ou aguardar auto-advance)
- **Teclas 1, 2, 3** – Escolher opções rapidamente
- **Velocidade** – Ajuste em Settings → Message display speed

---

## 💡 Dicas Importantes

### ✅ Faça Isso:
- ✅ Sempre comece com um nó chamado `"start"`
- ✅ Use `"next": null` no último nó para terminar
- ✅ Teste sua história jogando antes de compartilhar
- ✅ Teste diferentes caminhos reiniciando o chat
- ✅ Mantenha backups dos seus arquivos
- ✅ Use emojis para deixar mais expressivo! 😊
- ✅ Nomes descritivos: `intro`, `choice_help_friend`, `ending_good`

### ❌ Evite Isso:
- ❌ Não use caracteres especiais nos IDs de nós
- ❌ Não esqueça vírgulas entre elementos
- ❌ Não deixe nós sem `"next"` (use `null` para terminar)
- ❌ Não use aspas simples (`'`) - sempre duplas (`"`)
- ❌ Não se esqueça de fechar chaves `{` e colchetes `[`

---

## 🐛 Problemas Comuns

### "JSON inválido"
- **Causa**: Vírgula faltando ou sobrando
- **Solução**: Use [jsonlint.com](https://jsonlint.com) para validar

### "Arquivo não encontrado"
- **Causa**: Caminho errado da mídia
- **Solução**: Verifique se o arquivo está em `assets/images/` e o `src` no JSON está correto (ex: `images/foto.png`)

### "Nó não encontrado"
- **Causa**: `"next"` aponta para um nó que não existe
- **Solução**: Confira se o nome do nó está correto (case-sensitive!)

### Jogo trava
- **Causa**: Nó sem `next` (deve ser `null` explicitamente)
- **Solução**: Adicione `"next": null` no último nó

---

## 📚 Arquivo de Exemplo

- **complete_tutorial.json** – Tutorial completo com mensagens, escolhas, efeitos, mídia (image/gif/video) e condições. Use como base ou referência.

---

## 🎨 Workflow Recomendado

1. **Planeje sua história**
   - Personagens principais
   - Início, meio e fim
   - Escolhas importantes
   - Múltiplos finais?

2. **Copie o tutorial ou crie um JSON**
   - `complete_tutorial.json` → `sua_historia.json` (ou crie do zero)

3. **Escreva linearmente primeiro**
   - Crie o caminho principal sem escolhas
   - Teste para ver se funciona

4. **Adicione escolhas**
   - Pontos de decisão importantes
   - Effects para mudar stats

5. **Adicione mídia**
   - Imagens/GIFs/vídeos nos momentos certos (em `assets/images/`)

6. **Teste tudo**
   - Jogue sua história
   - Teste todos os caminhos

7. **Refine**
   - Ajuste diálogos
   - Balance os stats
   - Adicione detalhes

---

## 🌟 Recursos Avançados

### Múltiplos Finais
Crie finais diferentes baseados nos stats:
```json
"final_check": {
  "type": "message",
  "character": "narrator",
  "text": "Calculando seu final...",
  "next": "ending_romantic"
}
```

**Dica**: Use conditions (futuro) para escolher final automaticamente baseado em stats.

### Variáveis Customizadas
Você pode criar suas próprias variáveis:
- `quest_completed`
- `secret_discovered`  
- `days_passed`
- `relationship_level`

### Ramificações Complexas
```
      start
        |
     escolha1
      /   \
   pathA  pathB
      \   /
     converge
        |
     escolha2
     /  |  \
   end1 end2 end3
```

---

## 🎓 Próximos Passos

1. **Jogue o tutorial** (complete_tutorial.json)
2. **Copie e edite** para criar sua história
3. **Crie uma história curta** (5–10 nós)
4. **Teste no jogo**
5. **Incremente aos poucos**
6. **Compartilhe sua criação!**

---

## 💬 Dicas de Escrita

### Bons Diálogos:
- ✅ Naturais e conversacionais
- ✅ Mostram personalidade dos personagens
- ✅ Dão contexto suficiente
- ✅ Escolhas significativas

### Escolhas Interessantes:
- ✅ Têm consequências claras
- ✅ Refletem personalidade do jogador
- ✅ Levam a caminhos diferentes
- ✅ Nenhuma é "obviamente errada"

### Use Emojis com Moderação:
- 😊 Para expressar emoções
- ❤️ Para momentos românticos
- 😱 Para surpresa/drama
- 🎮 Para contexto de jogo
- ⚠️ Para avisos importantes

---

## 📦 Checklist Antes de Compartilhar

- [ ] História testada do início ao fim
- [ ] Todos os caminhos funcionam
- [ ] Imagens/mídia incluídos em assets/images
- [ ] JSON validado (sem erros de sintaxe)
- [ ] Metadata preenchido (título, autor, descrição)
- [ ] Stats balanceados
- [ ] Sem nós órfãos (não conectados)
- [ ] Finais satisfatórios

---

## 🆘 Precisa de Ajuda?

1. **Leia** `assets/dialogues/complete_tutorial.json`
2. **Consulte** README.md e QUICK_START.md
3. **Teste frequentemente** para pegar erros cedo
4. **Comece simples** e vá adicionando complexidade

---

## ✨ Divirta-se Criando!

A AwiOS Engine foi feita para ser **fácil e acessível**. 

Você não precisa saber programar para criar histórias incríveis!

**Boa sorte e boas criações! 🎮💕**

---

*Documentação da AwiOS Engine v1.0.0*
