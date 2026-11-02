extends Control
const Adapter = preload("res://addons/gua/gua_auto_adapter.gd")
var gua = Adapter.new()
func _ready() -> void:
    var button = Button.new()
    button.text = "Start"
    button.size = Vector2(160, 60)
    button.pressed.connect(func(): button.text = "Clicked")
    add_child(button)
    gua.attach(self)
    gua.update("tester")
    var port = OS.get_environment("GUA_BRIDGE_PORT").to_int()
    if not gua.start_inspector_bridge(port if port > 0 else 8765):
        push_error("Gua tester fixture bridge startup failed")
func _process(_delta: float) -> void:
    gua.update("tester")
