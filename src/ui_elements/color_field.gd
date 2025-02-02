## An editor to be tied to a color attribute.
extends HBoxContainer

signal focused
var attribute: AttributeColor
var attribute_name: String

const ColorPopup = preload("res://src/ui_elements/color_popup.tscn")
const checkerboard = preload("res://visual/icons/backgrounds/ColorButtonBG.svg")

@onready var color_button: Button = $Button
@onready var color_edit: LineEdit = $LineEdit
@onready var color_popup: Popup

func set_value(new_value: String, update_type := Utils.UpdateType.REGULAR):
	# Validate the value.
	if not AttributeColor.is_valid(new_value):
		sync(attribute.get_value())
		return
	
	if AttributeColor.color_equals_hex(new_value, attribute.default):
		new_value = attribute.default
	
	if AttributeColor.is_valid_hex(new_value) and new_value[0] != "#":
		new_value = "#" + new_value
	sync(attribute.autoformat(new_value))
	# Update the attribute.
	if attribute.get_value() != new_value or update_type == Utils.UpdateType.FINAL:
		match update_type:
			Utils.UpdateType.INTERMEDIATE:
				attribute.set_value(new_value, Attribute.SyncMode.INTERMEDIATE)
			Utils.UpdateType.FINAL:
				attribute.set_value(new_value, Attribute.SyncMode.FINAL)
			_:
				attribute.set_value(new_value)


func _ready() -> void:
	set_value(attribute.get_value())
	attribute.value_changed.connect(set_value)
	color_edit.tooltip_text = attribute_name


func _on_button_pressed() -> void:
	color_popup = ColorPopup.instantiate()
	color_popup.current_value = attribute.get_value()
	add_child(color_popup)
	color_popup.color_picked.connect(_on_color_picked)
	Utils.popup_under_control(color_popup, color_edit)

func _draw() -> void:
	var button_size := color_button.get_size()
	var line_edit_size := color_edit.get_size()
	draw_set_transform(Vector2(line_edit_size.x, 1))
	var stylebox := StyleBoxFlat.new()
	stylebox.corner_radius_top_right = 5
	stylebox.corner_radius_bottom_right = 5
	stylebox.bg_color = AttributeColor.get_color_from_non_url(attribute.get_value())
	draw_texture(checkerboard, Vector2.ZERO)
	draw_style_box(stylebox, Rect2(Vector2.ZERO, button_size - Vector2(1, 2)))


func _on_focus_entered() -> void:
	focused.emit()

func _on_focus_exited() -> void:
	set_value(color_edit.text)

func _on_text_submitted(new_text: String) -> void:
	set_value(new_text)


func _on_color_picked(new_color: String, close_picker: bool) -> void:
	if close_picker:
		color_popup.queue_free()
		set_value(new_color, Utils.UpdateType.FINAL)
	else:
		set_value(new_color, Utils.UpdateType.INTERMEDIATE)


func _on_button_resized() -> void:
	# Not sure why this is needed, but the button doesn't have a correct size at first
	# which screws with the drawing logic.
	queue_redraw()

func _on_text_changed(new_text: String) -> void:
	if AttributeColor.is_valid(new_text):
		color_edit.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6))
	else:
		color_edit.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.6))

func sync(new_value: String) -> void:
	if color_edit != null:
		if new_value == attribute.default:
			color_edit.add_theme_color_override(&"font_color", Color(0.64, 0.64, 0.64))
		else:
			color_edit.remove_theme_color_override(&"font_color")
		color_edit.text = new_value.trim_prefix("#")
	queue_redraw()
