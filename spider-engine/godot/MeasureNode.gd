extends Node

@export var server_url: String = "http://<IP_СЕРВЕРА>"
@export var username: String = "spider"
@export var password: String = "твой_пароль"
@export var result_label: Label
@export var status_icon: Sprite2D

var http_client: HTTPRequest
var is_measuring: bool = false

func _ready():
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)

func measure():
	if is_measuring:
		return
	is_measuring = true
	if result_label:
		result_label.text = "Измерение..."
		result_label.modulate = Color.GRAY

	var tex = get_viewport().get_texture()
	var img = tex.get_image()
	var png_data = img.to_png_data()
	var base64 = png_data.to_base64()

	var payload = {
		"frame_b64": base64,
		"context": {
			"camera_id": "main",
			"part_type": "shaft_001"
		}
	}

	var json_str = JSON.stringify(payload)
	var body = json_str.to_utf8_buffer()

	var plain = username + ":" + password
	var auth_header = "Authorization: Basic " + plain.to_base64()

	var headers = PackedStringArray([
		auth_header,
		"Content-Type: application/json"
	])

	http_client.request(
		server_url + "/measure/full",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

func _on_request_completed(result, code, headers, body):
	is_measuring = false
	if result == OK and code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		_process_result(response)
	else:
		if result_label:
			result_label.text = "Ошибка: HTTP " + str(code)
			result_label.modulate = Color.RED

func _process_result(res: Dictionary):
	if not res.has("verdict"):
		if result_label:
			result_label.text = "Неожиданный ответ"
			result_label.modulate = Color.ORANGE
		return

	var verdict = res["verdict"]
	var annotation = res.get("annotation", {})
	var label_text = annotation.get("label", "Без статуса")
	var color_hex = annotation.get("color", "#000000")

	if result_label:
		result_label.text = label_text
		var c = Color.from_html(color_hex)
		result_label.modulate = c

	if status_icon and verdict == "pass":
		status_icon.texture = preload("res://icons/ok.png")
	elif status_icon and verdict == "fail":
		status_icon.texture = preload("res://icons/fail.png")