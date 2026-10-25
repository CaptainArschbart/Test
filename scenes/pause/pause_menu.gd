extends CanvasLayer
## Pausemenü im Spiel. Esc (ui_cancel) öffnet und schließt es.
##
## Beim Öffnen wird der SceneTree angehalten und die Maus freigegeben. Die Optionen sind
## dieselbe Szene wie im Hauptmenü (scenes/options/options_menu.tscn): Entwurf, dann
## "Übernehmen" schreibt über Settings.apply_values() ins Spiel und nach
## user://settings.cfg. F11 schaltet Vollbild, solange das Menü offen ist (main.gd
## bekommt bei angehaltenem Spiel keine Eingaben) und wird von Settings gespeichert.

const OptionsMenu := preload("res://scenes/options/options_menu.gd")

## Szene, die "Zurück zum Hauptmenü" lädt.
@export_file("*.tscn") var main_menu_scene := "res://scenes/menu/main_menu.tscn"

@onready var main_page: Control = %MainPage
@onready var options: OptionsMenu = %Options
@onready var resume_button: Button = %ResumeButton
@onready var options_button: Button = %OptionsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Das Menü muss auch bei angehaltenem Spiel Eingaben bekommen.
	process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.pressed.connect(close)
	options_button.pressed.connect(_show_options)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options.closed.connect(_show_main_page)

	if OS.has_feature("web"):
		quit_button.hide()


func _exit_tree() -> void:
	# Wird die Szene verlassen, während pausiert ist, darf die Pause nicht mitwandern.
	if visible:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not visible:
			open()
		elif options.visible:
			options.request_back()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		# Während der Pause bekommt main.gd keine Eingaben, deshalb hier. Die Optionen
		# ziehen das Vollbild im Entwurf selbst nach (Settings.changed).
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()


## Hält das Spiel an und zeigt das Menü.
func open() -> void:
	if visible:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options.hide()
	main_page.show()
	show()
	resume_button.grab_focus()


## Schließt das Menü, setzt das Spiel fort und fängt die Maus wieder ein.
func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_options() -> void:
	main_page.hide()
	options.open()


func _show_main_page() -> void:
	main_page.show()
	options_button.grab_focus()


func _on_main_menu_pressed() -> void:
	# Ein angehaltener Baum würde sonst auch das Hauptmenü einfrieren.
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
