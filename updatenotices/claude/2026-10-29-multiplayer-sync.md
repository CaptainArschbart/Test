# Multiplayer-Sync · Claude (für Arschi)

## 2026-10-29 · PvP, Waffen, Gegner, Granaten, Beute und Map-Wahl im Multiplayer

- **Auftrag:** Allgemeiner Multiplayer-Sync. Gewünscht waren PvP-Schaden, Waffen-Sync, PvE-Schaden, Granaten und fallengelassene Items. Im Multiplayer soll man außerdem die Map wählen können.

### Grundidee
- **Spielerfiguren** gleichen sich wie bisher selbst ab (PlayerSync, PlayerAvatarSync). Treffer an einer Figur gehen an den Rechner, der sie steuert: `Player.apply_damage` schickt dafür das RPC `_net_damage`.
- **Gegner, Testwache und Beute** gehören dem Host. Er rechnet die KI und teilt Beute zu. Die Clients zeigen nur an und schicken ihre Treffer an den Host.
- **Neues Autoload `WorldSync`** (`autoload/world_sync.gd`, eingetragen in `project.godot`). Es übernimmt den Abgleich von Pickups, Granaten, NPC-Zuständen, Treffer-Weiterleitung, Geräuschen und Respawn.
- **Offline** ist das Verhalten unverändert. `WorldSync.is_online()` zählt den `OfflineMultiplayerPeer` nicht als Sitzung.

### Neu
- `autoload/world_sync.gd`:
  - **Pickups:**
    - Jedes Pickup hat eine `net_id`. Pickups aus der Map heißen `s:<Pfad>`, neue heißen `<Peer>:<Nummer>`.
    - `spawn_pickup()` erzeugt das Item lokal und schickt es an alle.
    - Aufheben geht über `request_take()` an den Host. Der Host verteilt, meldet allen die neue Menge (`_set_pickup_count_remote`) und gibt dem Anfragenden die Items (`_grant`). Passt inzwischen nicht mehr alles ins Inventar, fällt der Rest vor die Füße.
    - Ein Client, der später beitritt, bekommt den Stand aller Pickups (`_pickup_snapshot`).
  - **Granaten:**
    - Der Werfer meldet die Granate (`announce_grenade`), die anderen sehen eine Kopie (`ThrownGrenade.remote`).
    - Die Explosion kommt vom Werfer (`announce_explosion`), mit dessen Position.
    - Die Kopie macht keinen Schaden. Kommt keine Meldung, verschwindet sie 2 s nach ihrer Zündzeit.
  - **NPCs** (Gruppe `net_npc`):
    - Der Host schickt alle 0,1 s `net_get_state()` aller NPCs, die Clients übernehmen es mit `net_apply_state()`.
    - Ereignisse laufen über `npc_event()` → `net_event()`.
    - Treffer eines Clients gehen per `forward_hit()` an den Host. Der Angreifer wird dabei das Ziel des Gegners (`net_set_attacker`).
    - NPCs, die der Host 3 s nicht mehr schickt (z. B. abgeräumte Leichen), verschwinden auch beim Client.
  - **Geräusche:** Eigene Geräusche eines Clients (Schritte, Schüsse, Explosionen) gehen zusätzlich an den Host. So hören dessen Gegner auch Clients.
  - **Respawn:** `notify_revived()` lässt online nur die Gegner vergessen, die genau diesen Spieler gejagt haben. Offline vergessen wie bisher alle.
- `tools/tests/test_mp_sync.gd`: Test mit zwei Prozessen (Host und Client), für `testmap` und `slum`. Der Aufruf steht im Dateikopf.

### Geändert
- `autoload/network_manager.gd`: neues Signal `client_ready(id)`, sobald ein Client die Map geladen hat.
- `scenes/menu/main_menu.gd`: In der Multiplayer-Lobby gibt es eine Auswahlliste „MAP: …“ mit denselben Maps wie bei „Start“. Vorausgewählt ist die Testmap wie bisher.
  - HOST (Portfreigabe), HOST (NGROK) und SPIEL STARTEN nehmen die gewählte Map.
  - Wird die Map nach dem Hosten geändert, gilt sie für „SPIEL STARTEN“ und für alle, die danach beitreten.
- `scenes/player/player.gd`:
  - Neu: `take_hit()` (PvP mit Waffe oder Klinge, Kopftreffer ×1,5), `melee_hit()` (Fäuste mit Rückstoß), `apply_damage()` und RPC `_net_damage()`.
  - Gegnerschaden nimmt `_net_damage` nur vom Host an, PvP-Schaden (`pvp*`) von jedem Mitspieler. Ein Treffer übers Netz zählt höchstens 300.
  - Bei einem PvP-Treffer erscheint „Treffer von Runner-X“.
  - Fallengelassene Items und Items beim Tod laufen über `WorldSync.spawn_pickup`. Sie liegen jetzt in der Map-Szene, vorher lagen sie unter `NetworkManager/Players`.
  - Respawn ruft `WorldSync.notify_revived`.
- `scenes/player/player_avatar_sync.gd`:
  - Neues Feld `net_visibility` (Schleich-Sichtbarkeit), in `player.tscn` als Replikations-Property 14 eingetragen. `net_position` ist jetzt Property 15 und bleibt damit die letzte.
  - Die fremde Figur übernimmt Tod, Noclip, Tempo, Hocken und Sichtbarkeit, damit die Gegner beim Host Clients richtig wahrnehmen.
- `scenes/weapons/weapon_holder.gd`:
  - Der Schussstrahl trifft jetzt Layer world und player. Die eigene Figur ist ausgenommen.
  - Die anderen Spieler sehen Funken und Staub am Einschlag (RPC `_remote_impact`). Mündungsfeuer und Schuss-Ton gab es schon vorher.
- `scenes/player/item_user.gd`:
  - Die Klinge trifft auch andere Spieler.
  - Geworfene Granaten werden über `WorldSync.announce_grenade` an alle gemeldet.
- `scenes/player/player_melee.gd`: Fäuste treffen auch andere Spieler (Layer player in der Zielsuche).
- `scenes/items/grenade.gd`:
  - Neue Felder `remote` und `net_id`, neue Funktion `explode_remote()`.
  - Andere Spieler im Radius bekommen Schaden über `apply_damage(…, &"pvp_grenade")`.
- `scenes/items/pickup.gd`: Gruppe `item_pickup`, Felder `net_id` und `take_pending`, Funktion `set_count()`. Online fragt das Aufheben den Host.
- `scenes/inventory/inventory.gd`: neue Funktion `space_for(item)`. Sie sagt, wie viel noch ins Inventar passt.
- `scenes/enemies/enemy.gd`:
  - Im Multiplayer rechnet nur der Host. Gegner jagen den nächsten lebenden Spieler und prüfen das jede Sekunde neu. Im Kampf mit Sicht bleiben sie beim aktuellen Ziel.
  - Schaden geht über `apply_damage`.
  - Schüsse, Rufe, Töne, Treffer, EMP und Tod werden an die Clients geschickt (`_show_shot`, `_show_say`, `_play_sfx`, `_show_death`).
  - Beute kommt über `WorldSync.spawn_pickup`.
  - Clients zeigen den Gegner geglättet, mit Animation und Laser. Ihre Schleich-Anzeige zeigt, wenn ein Gegner sie bemerkt.
- `scenes/enemies/enemy_director.gd`: Die Detailstufe richtet sich beim Host nach dem nächsten Spieler, nicht nur nach der eigenen Kamera.
- `scenes/stealth/stealth_guard.gd` (Testwache): gleiches Prinzip wie bei den Gegnern, aber mit weniger Feldern.
- `scenes/stealth/stealth_noise.gd`: `emit()` gibt eigene Geräusche an `WorldSync.forward_noise` weiter. Neu ist `emit_local()`.
- `scenes/survival/death_screen.gd`: neue Ursachen `pvp`, `pvp_melee` und `pvp_grenade`.
- `tools/tests/test_money.gd`: Die Prüfung beim Tod sucht den Credchip-Stapel jetzt in der Gruppe `item_pickup`, weil er in der Map-Szene liegt.

### Entscheidungen und Gründe
- **Host bestimmt Gegner und Beute:** Sonst sehen Spieler verschiedene Gegner, und Beute ließe sich doppelt aufheben. Die alte Lösung „jeder Rechner jagt seinen eigenen Spieler“ ist weg.
- **Der Schütze entscheidet über Treffer:** Bei Schüssen und Granaten berechnet der Rechner des Schützen den Treffer und schickt nur den Schaden. Das ist einfach und fühlt sich ohne Verzögerung an, ist aber nicht schummelsicher. Für ein Koop-Projekt unter Freunden reicht das.
- **Eigene Pakete statt `MultiplayerSynchronizer`:** Gegner sind feste Knoten der Map und werden nicht gespawnt. Ein Paket pro 0,1 s für alle NPCs ist einfacher und kommt auch mit Spielern klar, die später beitreten.

### Getestet (Godot 4.7.2 headless, Windows, Host und Client über ENet auf 127.0.0.1)
- `test_mp_sync -- testmap`: Host 14/0, Client 17/0.
  - Der Client lässt einen Drink fallen, der Host sieht ihn und hebt ihn auf, danach ist er bei beiden weg.
  - Zwei Anfragen direkt hintereinander nach demselben Stapel: Der Client bekommt genau einmal 5, der Host nichts.
  - PvP: Ein Pistolenschuss des Clients senkt die HP des Hosts von 100 auf 75, die Ursache ist `pvp`.
  - Granate des Hosts: Der Client sieht die Kopie. Seine HP fallen von 100 auf 41, die Ursache ist `pvp_grenade`, und die Kopie ist danach weg.
  - Testwache: Sie steht beim Client 0,2 m neben der Stelle, an die der Host sie gesetzt hat. 30 Schaden vom Client kommen beim Host an (100 → 70).
- `test_mp_sync -- slum`: Host 9/0, Client 10/0.
  - Der Host hostet über das Hauptmenü mit der Map-Auswahl „Sektor 7“.
  - Der Gegner nimmt den Client als nächstes Ziel. Er steht beim Client 3,0 m daneben, und sein Schaden kommt beim Client an.
  - Der Client erledigt den Gegner. Bei beiden ist er tot und hat 3 Beute-Pickups.
  - Lebende Gegner beim Client bekommen Pakete vom Host.
- `test_bank_net`: Host 8/0, Client 8/0. `test_bank` 41/0, `test_money` 25/0, `test_consumables` 45/0, `test_sector7_enemies` 15/0, `test_player_melee` 42/0. Kein `SCRIPT ERROR`.
- `test_weapons_smg_grenade`: 18 Fehler, so viele wie vorher auf main. Ursache ist, dass sich die Maus unter Windows headless nicht einfangen lässt.

### Nicht getestet
- Echte Hardware, Internet bzw. ngrok/WebSocket und mehr als zwei Spieler.
- Wie flüssig die Gegner beim Client bei echter Latenz aussehen. Getestet ist nur lokal mit 0,1 s Paketabstand.

### Vorfall während der Arbeit
- `git pull.bat` (macht `git stash` und dann `git pull origin main`) wurde im Projektordner ausgeführt, während ich arbeitete. Meine Änderungen lagen danach in `stash@{0}`. Ich habe sie mit `git stash pop` zurückgeholt, verloren ging nichts. Der Pull selbst hat nichts geändert.

### Git
- Branch `claude/multiplayer-sync` baut auf `claude/bankautomat` (#45) auf, das wiederum auf #44. Der Zwischenstand-Commit 53205ac hat den Stand gegen weitere Stashes gesichert.

### Offen
- Passanten (`civilian.gd`) und Autos (`traffic_*`) laufen weiter auf jedem Rechner für sich und sind nicht synchronisiert.
- Inventar, Waffenmunition und Hunger/Durst sind weiter lokal pro Spieler.
- Physik-Objekte, die von Explosionen weggestoßen werden (RigidBody), bewegen sich nur beim Werfer.
- Es gibt keine echten Spielernamen und keinen Schalter, um PvP auszuschalten.
