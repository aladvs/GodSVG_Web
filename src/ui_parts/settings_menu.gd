extends PanelContainer

const ContextPopup = preload("res://src/ui_elements/context_popup.tscn")
const PaletteConfigWidget = preload("res://src/ui_parts/palette_config.tscn")
const plus_icon = preload("res://visual/icons/Plus.svg")

@onready var lang_button: Button = %Language
@onready var palette_container: VBoxContainer = %PaletteContainer


func _ready() -> void:
	update_language_button()
	rebuild_color_palettes()

func _on_window_mode_pressed() -> void:
	GlobalSettings.save_window_mode = not GlobalSettings.save_window_mode

func _on_svg_pressed() -> void:
	GlobalSettings.save_svg = not GlobalSettings.save_svg

func _on_close_pressed() -> void:
	queue_free()

func _on_language_pressed() -> void:
	var btn_arr: Array[Button] = []
	for lang in ["en", "bg", "de"]:
		btn_arr.append(Utils.create_btn(
				TranslationServer.get_locale_name(lang) + " (" + lang + ")",
				_on_language_chosen.bind(lang)))
	var lang_popup := ContextPopup.instantiate()
	add_child(lang_popup)
	lang_popup.set_button_array(btn_arr, true, lang_button.size.x)
	Utils.popup_under_control(lang_popup, lang_button)

func _on_language_chosen(locale: String) -> void:
	GlobalSettings.language = locale
	update_language_button()

func update_language_button() -> void:
	lang_button.text = tr(&"#language") + ": " + TranslationServer.get_locale().to_upper()


func add_palette() -> void:
	for palette in GlobalSettings.get_palettes():
		# If there's an unnamed pallete, don't add a new one (there'll be a name clash).
		if palette.name.is_empty():
			return
	
	GlobalSettings.get_palettes().append(ColorPalette.new())
	GlobalSettings.save_user_data()
	rebuild_color_palettes()

func rebuild_color_palettes() -> void:
	for palette_config in palette_container.get_children():
		palette_config.queue_free()
	
	for palette in GlobalSettings.get_palettes():
		var palette_config := PaletteConfigWidget.instantiate()
		palette_container.add_child(palette_config)
		palette_config.assign_palette(palette)
		palette_config.layout_changed.connect(rebuild_color_palettes)
	# The button for adding a new palette looks quite unusual and should be on the bottom.
	# So I'm setting up its own theming here.
	var normal_sb := StyleBoxFlat.new()
	var hover_sb := StyleBoxFlat.new()
	var pressed_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color("#def1")
	hover_sb.bg_color = Color("#def2")
	pressed_sb.bg_color = Color("#def4")
	for sb: StyleBoxFlat in [normal_sb, hover_sb, pressed_sb]:
		sb.set_corner_radius_all(5)
		sb.set_content_margin_all(4)
	var add_palette_button := Button.new()
	add_palette_button.add_theme_stylebox_override(&"normal", normal_sb)
	add_palette_button.add_theme_stylebox_override(&"hover", hover_sb)
	add_palette_button.add_theme_stylebox_override(&"pressed", pressed_sb)
	add_palette_button.icon = plus_icon
	add_palette_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_palette_button.focus_mode = Control.FOCUS_NONE
	add_palette_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	palette_container.add_child(add_palette_button)
	add_palette_button.pressed.connect(add_palette)
