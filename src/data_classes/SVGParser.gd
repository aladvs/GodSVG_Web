class_name SVGParser extends RefCounted

static func svg_to_text(svg_tag: TagSVG) -> String:
	var w: String = svg_tag.attributes.width.get_value()
	var h: String = svg_tag.attributes.height.get_value()
	var viewbox: String = svg_tag.attributes.viewBox.get_value()
	
	var text := '<svg'
	if !w.is_empty():
		text += ' width="' + w + '"'
	if !h.is_empty():
		text += ' height="' + h + '"'
	if !viewbox.is_empty():
		text += ' viewBox="' + viewbox + '"'
	
	
	for attribute in svg_tag.unknown_attributes:
		text += " " + attribute.name + '="' + attribute.get_value() + '"'
	text += ">"
	
	for inner_tag in svg_tag.child_tags:
		text += _tag_to_text(inner_tag)
	return text + '</svg>'

static func _tag_to_text(tag: Tag) -> String:
	var text := ""
	text += '<' + tag.name
	for attribute_key in tag.attributes:
		var attribute: Attribute = tag.attributes[attribute_key]
		var value := attribute.get_value()
		if value == attribute.default:
			continue
		
		text += " " + attribute_key + '="' + value + '"'
	
	for attribute in tag.unknown_attributes:
		text += " " + attribute.name + '="' + attribute.get_value() + '"'
	
	if tag.is_standalone():
		text += '/>'
	else:
		text += '>'
		for child_tag in tag.child_tags:
			text += _tag_to_text(child_tag)
		text += '</' + tag.name + '>'
	
	return text


static func text_to_svg(text: String) -> TagSVG:
	var svg_tag := TagSVG.new()
	var parser := XMLParser.new()
	parser.open_buffer(text.to_ascii_buffer())
	var unclosed_tag_stack: Array[Tag] = [svg_tag]
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node_name := parser.get_node_name()
				var attrib_dict := {}
				for i in range(parser.get_attribute_count()):
					attrib_dict[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
				
				# SVG tag requires width and height without defaults, so do the logic early.
				if node_name == "svg":
					if attrib_dict.has("width"):
						svg_tag.attributes.width.set_value(attrib_dict["width"],
								Attribute.SyncMode.SILENT)
					if attrib_dict.has("height"):
						svg_tag.attributes.height.set_value(attrib_dict["height"],
								Attribute.SyncMode.SILENT)
					if attrib_dict.has("viewBox"):
						svg_tag.attributes.viewBox.set_value(attrib_dict["viewBox"],
								Attribute.SyncMode.SILENT)
					
					var unknown: Array[AttributeUnknown] = []
					for element in attrib_dict:
						if svg_tag.attributes.has(element):
							var attribute: Attribute = svg_tag.attributes[element]
							attribute.set_value(attrib_dict[element], Attribute.SyncMode.SILENT)
						else:
							unknown.append(AttributeUnknown.new(element, attrib_dict[element]))
					svg_tag.set_unknown_attributes(unknown)
					
				else:
					var tag: Tag
					match node_name:
						"circle": tag = TagCircle.new()
						"ellipse": tag = TagEllipse.new()
						"rect": tag = TagRect.new()
						"path": tag = TagPath.new()
						"line": tag = TagLine.new()
						_: tag = TagUnknown.new(node_name)
					
					var unknown: Array[AttributeUnknown] = []
					for element in attrib_dict:
						if tag.attributes.has(element):
							var attribute: Attribute = tag.attributes[element]
							attribute.set_value(attrib_dict[element], Attribute.SyncMode.SILENT)
						else:
							unknown.append(AttributeUnknown.new(element, attrib_dict[element]))
					tag.set_unknown_attributes(unknown)
					
					# Check if we're entering or exiting the tag.
					var node_offset := parser.get_node_offset()
					var closure_pos := text.find("/>", node_offset)
					if closure_pos == -1 or closure_pos >= text.find(">", node_offset):
						unclosed_tag_stack.append(tag)
					else:
						unclosed_tag_stack.back().child_tags.append(tag)
			XMLParser.NODE_ELEMENT_END:
				if unclosed_tag_stack.size() > 1:
					var closed_tag: Tag = unclosed_tag_stack.pop_back()
					unclosed_tag_stack.back().child_tags.append(closed_tag)
	
	return svg_tag


# TODO Can definitely be improved.
static func get_svg_syntax_error(text: String) -> StringName:
	# Easy cases.
	if text.is_empty():
		return &"#err_empty_svg"
	
	if text.count("<") != text.count(">"):
		return &"#err_improper_nesting"
	
	var parser := XMLParser.new()
	parser.open_buffer(text.to_ascii_buffer())
	if text.begins_with("<?"):
		parser.skip_section()
	
	var nodes: Array[String] = []  # Serves as a sort of stack.
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			# First node must be "svg", last node must be closing "svg".
			if nodes.is_empty():
				if node_name != "svg":
					return &"#err_not_svg"
			
			var offset := parser.get_node_offset()
			# Don't add tags that were closed right away to the stack.
			var closure_pos := text.find("/>", offset)
			if closure_pos == -1 or closure_pos >= text.find(">", offset):
				nodes.append(node_name)
		
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			var node_name := parser.get_node_name()
			if nodes.is_empty() or node_name != nodes.back():
				return &"#err_improper_nesting"
			nodes.pop_back()
	return &"" if nodes.is_empty() else &"#err_improper_closing"
