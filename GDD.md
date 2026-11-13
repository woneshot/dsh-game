# GDD & Tech Spec: Flesh Pact (Co-op Turn-Based Battler, Godot 4)

## Стек и правила для агента
- Движок: Godot 4, строго типизированный GDScript.
- Рабочий цикл: используй скиллы `writing-plans` -> `executing-plans`. Дроби задачу на атомарные шаги (1–2 файла за шаг) и проверяй каждый шаг через `godot-mcp`.
- Экономия токенов: планирование архитектуры делай на облачном DeepSeek, а рутинную генерацию кода/сцен делегируй локальной модели (Ollama qwen).

## Геймплей
- LAN Кооп на двоих через Hamachi (`ENetMultiplayerPeer`, порт 7777).
- Общее HP игроков: 100. У каждого игрока 3 ОД (энергии) на ход и 4 карты скиллов.
- Фаза игроков: клик по карте -> отправка `@rpc("any_peer", "call_local")` -> применение эффекта (урон врагу, щит, бафф, хил).
- Когда оба нажали "End Turn" -> Фаза врага (Хост считает атаку босса и синхронизирует состояние). Всего 3 босса подряд.

## Жесткое разделение Git (ВО ИЗБЕЖАНИЕ КОНФЛИКТОВ)
- **ИГРОК 1 (Backend/Core):** трогает ТОЛЬКО `project.godot` и папку `res://core/` (`NetworkManager.gd`, `GameData.gd`, `MainMenu.tscn/.gd`, `BattleScene.tscn`, `BattleManager.gd`).
- **ИГРОК 2 (Frontend/UI/Assets):** трогает ТОЛЬКО `res://ui_entities/` (`EnemyView.tscn/.gd`, `CardView.tscn/.gd`, `TestSandbox.tscn`) и `res://assets/`. НИКОГДА не меняет `project.godot` и `res://core/`.

## Контракт интеграции (Методы и сигналы)
- `res://ui_entities/EnemyView.tscn`:
  - `setup(enemy_id: String, max_hp: int) -> void` (грузит `res://assets/enemies/{enemy_id}.png` или плейсхолдер)
  - `update_state(hp: int, shield: int, intent_text: String) -> void`
  - `play_hit_anim(damage: int) -> void` (Tween тряски + вспышка)
  - `play_attack_anim() -> void` (Tween рывка)
- `res://ui_entities/CardView.tscn`:
  - `signal card_clicked(skill_id: String)`
  - `setup(skill_id: String, title: String, cost: int, desc: String, icon: Texture2D) -> void`
  - `set_usable(can_use: bool) -> void`
