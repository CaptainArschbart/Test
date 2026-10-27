extends Node
## Lädt ngrok bei Bedarf nach user://bin, startet einen TCP-Tunnel und liest
## die öffentliche Adresse von http://127.0.0.1:4040/api/tunnels.
## Der Prozess gehört dem Spiel: Lobby verlassen oder Beenden beendet ihn.

const ARCHIVE_BASE := "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-%s.zip"
const TOKEN_PATH := "user://ngrok.cfg"
const PID_PATH := "user://ngrok.pid"
const BIN_DIR := "user://bin"
const TUNNEL_API := "http://127.0.0.1:4040/api/tunnels"
const POLL_SECONDS := 0.5
const MAX_POLLS := 20

signal binary_ready
signal tunnel_ready(address: String)
signal tunnel_failed(message: String)

var _http: HTTPRequest
var _poll: Timer
var _pid := 0
var _port := 7777
var _token := ""
var _polls := 0
var _job := 0
var _killing := false
var _after_binary := Callable()

const JOB_NONE := 0
const JOB_DOWNLOAD := 1
const JOB_TUNNELS := 2


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 120.0
	_http.use_threads = true
	_http.accept_gzip = false
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	_poll = Timer.new()
	_poll.wait_time = POLL_SECONDS
	_poll.timeout.connect(_poll_tunnels)
	add_child(_poll)
	get_tree().root.close_requested.connect(stop_tunnel)
	_kill_saved_pid()


func _exit_tree() -> void:
	stop_tunnel()


func binary_path() -> String:
	return BIN_DIR.path_join(binary_file_name())


func binary_file_name() -> String:
	if OS.get_name() == "Windows":
		return "ngrok.exe"
	return "ngrok"


static func download_url_for(os_name: String, arch: String) -> String:
	var slug := ""
	match os_name:
		"Windows":
			if arch == "arm64":
				slug = "windows-arm64"
			elif arch == "x86_32":
				slug = "windows-386"
			else:
				slug = "windows-amd64"
		"macOS":
			slug = "darwin-arm64" if arch == "arm64" else "darwin-amd64"
		"Linux", "FreeBSD":
			if arch == "arm64":
				slug = "linux-arm64"
			elif arch == "arm32" or arch == "arm":
				slug = "linux-arm"
			else:
				slug = "linux-amd64"
		_:
			slug = ""
	if slug.is_empty():
		return ""
	return ARCHIVE_BASE % slug


func download_url() -> String:
	return download_url_for(OS.get_name(), Engine.get_architecture_name())


static func parse_public_url(body: String) -> String:
	var parsed: Variant = JSON.parse_string(body)
	if not parsed is Dictionary:
		return ""
	var tunnels: Variant = (parsed as Dictionary).get("tunnels", [])
	if not tunnels is Array:
		return ""
	var list: Array = tunnels
	for entry: Variant in list:
		if not entry is Dictionary:
			continue
		var item := entry as Dictionary
		if str(item.get("proto", "")) != "tcp":
			continue
		var raw := str(item.get("public_url", "")).strip_edges()
		raw = raw.trim_prefix("tcp://")
		if raw.is_empty():
			continue
		return raw
	return ""


func saved_token() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(TOKEN_PATH) != OK:
		return ""
	return str(cfg.get_value("ngrok", "token", ""))


func start_tunnel(port: int, token: String) -> void:
	stop_tunnel()
	_port = port
	_token = token.strip_edges()
	_save_token(_token)
	_after_binary = _launch
	ensure_binary()


func ensure_binary() -> void:
	if FileAccess.file_exists(binary_path()):
		_binary_is_ready()
		return
	var url := download_url()
	if url.is_empty():
		_fail("Für %s gibt es kein ngrok-Paket." % OS.get_name())
		return
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BIN_DIR))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		_fail("Ordner user://bin fehlt (%d)." % dir_err)
		return
	_job = JOB_DOWNLOAD
	_http.timeout = 120.0
	_http.download_file = ProjectSettings.globalize_path(BIN_DIR.path_join("ngrok.zip"))
	var err := _http.request(url)
	if err != OK:
		_job = JOB_NONE
		_http.download_file = ""
		_fail(_download_error(err))


func stop_tunnel() -> void:
	if _killing:
		return
	_killing = true
	_polls = 0
	_job = JOB_NONE
	_after_binary = Callable()
	_poll.stop()
	if _http != null:
		_http.cancel_request()
		_http.download_file = ""
	_kill_pid(_pid)
	_pid = 0
	_clear_pid_file()
	_killing = false


func extract_archive(zip_path: String, dest_path: String, wanted_name: String) -> Error:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return err
	var found := ""
	for path: String in reader.get_files():
		if path.ends_with("/") or path.ends_with("\\"):
			continue
		if path.get_file() == wanted_name:
			found = path
			break
	if found.is_empty():
		reader.close()
		return ERR_FILE_NOT_FOUND
	var bytes := reader.read_file(found)
	reader.close()
	if bytes.is_empty():
		return ERR_FILE_CORRUPT
	var file := FileAccess.open(dest_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	return OK


func _binary_is_ready() -> void:
	var next := _after_binary
	_after_binary = Callable()
	if next.is_valid():
		next.call()
	else:
		binary_ready.emit()


func _launch() -> void:
	var exe := ProjectSettings.globalize_path(binary_path())
	if not FileAccess.file_exists(exe) and not FileAccess.file_exists(binary_path()):
		_fail("ngrok liegt nicht in user://bin.")
		return
	if not _token.is_empty() and not _token_already_applied():
		var output: Array = []
		var code := OS.execute(exe, PackedStringArray(["config", "add-authtoken", _token]), output, true)
		if code != 0:
			_fail("Authtoken abgelehnt. Token im ngrok-Dashboard prüfen.")
			return
		_mark_token_applied()
	# Ziel ist die IPv4-Loopback, der Server lauscht auf 0.0.0.0.
	var target := "127.0.0.1:%d" % _port
	_pid = OS.create_process(exe, PackedStringArray(["tcp", target]))
	if _pid <= 0:
		_fail("ngrok konnte nicht gestartet werden.")
		return
	_write_pid(_pid)
	_polls = 0
	_poll.start()


func _poll_tunnels() -> void:
	if _killing or _job == JOB_DOWNLOAD:
		return
	if _pid <= 0:
		_poll.stop()
		return
	if not OS.is_process_running(_pid):
		_fail("ngrok wurde beendet. Authtoken und Internet prüfen.")
		return
	if _job == JOB_TUNNELS:
		return
	_polls += 1
	if _polls > MAX_POLLS:
		_fail("Kein Tunnel von ngrok. Authtoken eintragen und erneut hosten.")
		return
	_job = JOB_TUNNELS
	_http.timeout = 2.0
	_http.download_file = ""
	var err := _http.request(TUNNEL_API)
	if err != OK:
		_job = JOB_NONE


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var job := _job
	_job = JOB_NONE
	if job == JOB_DOWNLOAD:
		_on_download_completed(result, response_code)
	elif job == JOB_TUNNELS:
		_on_tunnels_completed(result, response_code, body)


func _on_download_completed(result: int, response_code: int) -> void:
	var zip_path := BIN_DIR.path_join("ngrok.zip")
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail(_download_failed_text(result, response_code))
		return
	var err := extract_archive(zip_path, binary_path(), binary_file_name())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
	if err != OK:
		_fail("ngrok-Archiv ließ sich nicht entpacken (%d)." % err)
		return
	if OS.get_name() != "Windows":
		OS.execute("chmod", PackedStringArray(["+x", ProjectSettings.globalize_path(binary_path())]), [], true)
	_binary_is_ready()


func _on_tunnels_completed(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var address := parse_public_url(body.get_string_from_utf8())
	if address.is_empty():
		return
	_poll.stop()
	tunnel_ready.emit(address)


func _fail(message: String) -> void:
	if _killing:
		return
	stop_tunnel()
	tunnel_failed.emit(message)


func _download_error(err: Error) -> String:
	if err == ERR_CANT_RESOLVE or err == ERR_CANT_CONNECT:
		return "Keine Internetverbindung. ngrok konnte nicht geladen werden."
	return "Download nicht gestartet (%d)." % err


func _download_failed_text(result: int, response_code: int) -> String:
	if result == HTTPRequest.RESULT_CANT_RESOLVE or result == HTTPRequest.RESULT_CANT_CONNECT:
		return "Keine Internetverbindung. ngrok konnte nicht geladen werden."
	if result == HTTPRequest.RESULT_TIMEOUT:
		return "Zeitüberschreitung beim ngrok-Download."
	return "ngrok-Download fehlgeschlagen (%d / HTTP %d)." % [result, response_code]


func _save_token(token: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(TOKEN_PATH)
	cfg.set_value("ngrok", "token", token)
	if token != str(cfg.get_value("ngrok", "applied", "")):
		cfg.set_value("ngrok", "applied", "")
	cfg.save(TOKEN_PATH)


func _token_already_applied() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(TOKEN_PATH) != OK:
		return false
	return str(cfg.get_value("ngrok", "applied", "")) == _token and not _token.is_empty()


func _mark_token_applied() -> void:
	var cfg := ConfigFile.new()
	cfg.load(TOKEN_PATH)
	cfg.set_value("ngrok", "token", _token)
	cfg.set_value("ngrok", "applied", _token)
	cfg.save(TOKEN_PATH)


func _write_pid(pid: int) -> void:
	var file := FileAccess.open(PID_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(str(pid))
	file.close()


func _clear_pid_file() -> void:
	if FileAccess.file_exists(PID_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PID_PATH))


func _kill_saved_pid() -> void:
	if not FileAccess.file_exists(PID_PATH):
		return
	var text := FileAccess.get_file_as_string(PID_PATH).strip_edges()
	if not text.is_valid_int():
		_clear_pid_file()
		return
	_kill_pid(text.to_int())
	_clear_pid_file()


func _kill_pid(pid: int) -> void:
	if pid <= 0:
		return
	if OS.is_process_running(pid):
		OS.kill(pid)
