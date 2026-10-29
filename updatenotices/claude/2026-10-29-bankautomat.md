# Bankautomat · Claude (für Arschi)

## 2026-10-29 · Konto, Einzahlen/Abheben und Überweisungen an andere Spieler

- **Auftrag:** Ein Bankautomat, an dem man Geld einzahlen und abheben kann. Im Multiplayer soll man an andere Spieler überweisen können. Den Knopf „Überweisen“ soll es auch im Einzelspieler geben, für spätere Funktionen.

### Neu
- `scenes/interact/bank_terminal.gd`: Bankautomat als `StaticBody3D` auf Layer world, wie `vending_machine.gd`. Gehäuse, Bildschirm „NC-BANK / KARTE EINLEGEN“, schräges Tastenfeld, Kartenschlitz, Geldausgabe, magenta Leuchtkanten, Schild „NC-BANK ¢“ und Licht entstehen im Code. Größe 0,9 × 2,1 × 0,6 m (`size`), Name über `bank_name`. Mit E steht „[E] NC-BANK-Automat benutzen“ unter dem Fadenkreuz. E öffnet das Bankfenster.
- `scenes/interact/bank_ui.gd`: das Bankfenster, eine `CanvasLayer` auf Layer 5 (über HUD und Inventar, unter dem Pausemenü). Es wird beim ersten Benutzen als Kind `BankUI` am lokalen Player angelegt und danach nur ein- und ausgeblendet. Inhalt:
  - Kopf „NC-BANK  TERMINAL // 24H“, darunter BARGELD und KONTO in Gold.
  - Betragsfeld (nur Ziffern, max. 7 Stellen), Schnellknöpfe +10, +50, +100, +500 und C zum Leeren.
  - Einzahlen, Abheben, Alles einzahlen, Alles abheben.
  - Überweisung: Auswahlliste der Empfänger und Knopf „Überweisen“. Der Knopf ist immer da. Ohne Empfänger, also im Einzelspieler oder allein online, ist er gesperrt. Darunter steht dann „Überweisungen an andere Spieler gehen im Multiplayer.“ Die Empfängerliste lädt sich bei offenem Fenster alle 0,5 s neu, damit Spieler, die neu dazukommen oder gehen, erscheinen bzw. verschwinden.
  - Statuszeile mit Rückmeldung, z. B. „170 ¢ abgehoben.“ oder „Zu wenig Guthaben auf dem Konto.“, und der Knopf „Schließen“.
  - Esc oder E schließt das Fenster. E schließt nur, wenn das Betragsfeld keinen Fokus hat. Bei Tod schließt es sich von selbst.
- `tools/tests/test_bank.gd`: Test mit 41 Prüfungen zu Konto, Grenzen, Überweisung, Fenster, Tod und Platzierung in Testmap und Sektor 7.
- `tools/tests/test_bank_net.gd`: Multiplayer-Test mit zwei Prozessen, Host und Client. Aufruf steht im Dateikopf.

### Geändert
- `scenes/inventory/inventory.gd`:
  - Neues Bankkonto `bank`, Export `starting_bank` (Standard 0).
  - Neue Signale `bank_changed(balance, delta)` und `transfer_received(amount, from_name)`.
  - Neue Funktionen:
    - `add_bank()` und `spend_bank()`.
    - `deposit()` und `withdraw()`: buchen nur so viel um, wie da ist und auf die andere Seite passt (Grenze `MAX_MONEY` gilt für beide Seiten).
    - `send_transfer(target_inventory, amount, from_name)`.
    - RPC `receive_transfer(amount)` (`any_peer`, `reliable`).
    - `credit_transfer()`.
    - `peer_display_name(peer_id)`: liefert „Runner-1 (Host)“ bzw. „Runner-<ID mod 10000>“.
- `scenes/player/player.gd`: neues Feld `open_panel`, das auf das gerade offene Fenster außer dem Inventar zeigt. Bei einer eingehenden Überweisung erscheint die Meldung „Überweisung: +120 ¢ von Runner-1 (Host)“ in Grün.
- `scenes/inventory/inventory_ui.gd`: Solange `player.open_panel` gesetzt ist, öffnet Tab das Inventar nicht. `_process` hebt die Eingabesperre dann nicht auf, sonst hätte es sie jeden Frame gelöst.
- `scenes/pause/pause_menu.gd`: Beim Öffnen der Pause schließt `_close_inventory()` auch ein offenes `open_panel`.
- `scenes/testmap/testmap.tscn`: neuer Knoten `Vending/BankTerminal` bei (−11,2 | 0,2 | 37,3), neben dem Noodle-Automaten und in dieselbe Richtung gedreht. `load_steps` steht jetzt auf 52.
- `scenes/slum/slum.tscn` (Sektor 7): neuer Knoten `Vending/BankTerminal` bei (7,0 | 0,15 | 50,6), in derselben Reihe wie die Cola- und Noodle-Automaten.

### Entscheidungen und Gründe
- **Konto und Bargeld:** `money` bleibt das Bargeld, das im HUD steht und beim Tod fällt. `bank` ist das Konto und bleibt beim Tod erhalten. Dadurch hat der Automat einen Zweck: Geld auf der Bank ist sicher.
- **Überweisung im Netz:** Das Inventar ist nicht synchronisiert. Deshalb bucht der Absender lokal ab und schickt `receive_transfer.rpc_id(empfänger, betrag)` an den Inventar-Knoten des Empfängers (`/root/NetworkManager/Players/<id>/Inventory`). Der Name des Absenders kommt beim Empfänger aus `get_remote_sender_id()` und nicht aus einem Parameter, den der Absender mitschickt.
- **Offline:** `send_transfer` schreibt die Gutschrift direkt gut. Damit lassen sich später auch NPC-Konten oder Ähnliches als Empfänger anschließen. Die Empfängerliste kommt aus `list_recipients()` in `bank_ui.gd`.
- **Ohne `class_name`:** `bank_terminal.gd` und `bank_ui.gd` haben keinen `class_name` und werden per `preload` benutzt. So fehlt nach einem Pull kein Eintrag im Klassen-Cache (siehe `vital_sounds.gd`).
- **Spielernamen:** Es gibt noch keine Spielernamen, deshalb steht „Runner-<ID>“ in der Liste.

### Getestet (Godot 4.7.2 headless, Windows)
- `test_bank`: 41/0. Abgedeckt:
  - Einzahlen und Abheben mit Teilbeträgen, Konto voll und Bargeld voll, negative Beträge.
  - Überweisung zwischen zwei Inventaren, abgelehnte Fälle.
  - Fenster öffnen und schließen, Sperre bleibt 5 Frames stehen, Überweisen-Knopf im Einzelspieler sichtbar und gesperrt, Betragsfeld filtert Ziffern, Knöpfe buchen um und die Anzeige stimmt.
  - Tod: Bargeld fällt, Konto bleibt.
  - Automat steckt in Testmap und Sektor 7 in keiner Kollision, davor ist Boden und Platz für eine Spielerkapsel.
- `test_bank_net`: Host und Client je 8/0. Der Host überweist 120 an den Client, der Client 30 zurück. Die Kontostände stimmen (Host 110, Client 290), die Namen in der Liste und bei der Gutschrift stimmen, und der Knopf ist online frei. Verbindung über ENet auf 127.0.0.1:7791.
- `test_money`: 25/0. `test_consumables`: 45/0.
- Im ersten Lauf von `test_bank` kam beim Kartenwechsel einmal `player_stealth.gd:215 !is_inside_tree()`. Im zweiten Lauf kam die Meldung nicht. Sie stammt nicht aus diesem PR.

### Nicht getestet
- Optik von Automat und Fenster auf echter Hardware, Maus und Tastatur im echten Fenster.
- Multiplayer über das Internet bzw. ngrok/WebSocket. Getestet ist nur ENet lokal.

### Git
- Branch `claude/bankautomat` baut auf `claude/credits-hud` (PR #44) auf. Mein Merge von #44 wurde blockiert, weil ein Merge ohne Review nicht automatisch erlaubt war. Der PR zielt deshalb zuerst auf `claude/credits-hud`.

### Offen
- Das Konto wird nicht gespeichert (es gibt noch keinen Spielstand).
- Geht ein Empfänger genau während der Überweisung offline, ist der Betrag weg. Es gibt keine Rückbuchung.
- Es gibt keine echten Spielernamen.
