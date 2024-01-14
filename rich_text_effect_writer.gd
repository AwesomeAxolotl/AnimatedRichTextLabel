extends RichTextEffect
## this script is supposed to be used in conjunction with AnimatedRichTextLabel

var bbcode = "writer"

func _process_custom_fx(char_fx: CharFXTransform):
	var node: AnimatedRichTextLabel = char_fx.env.get("node", null) as AnimatedRichTextLabel
	if node == null or node.skipped: return true
	if node._start_time < 0: node._start_time = char_fx.elapsed_time
	node._elapsed_time = char_fx.elapsed_time
	
	var progress := get_transition_progress(node, char_fx)
	# text finished
	if char_fx.relative_index == node._character_count - 1 and is_equal_approx(progress, 1.0):
		node.skipped = true
	# text reached a spot where it should wait
	if node._waits.size() > 0 and char_fx.relative_index == node._waits[0][0] - 1:
		if is_equal_approx(progress, 1.0) and !node.waiting:
			node.waiting = true
	
	node.transitions[node.transition].callv([
		char_fx, progress, node.effect_strength
	])
	return true


## 0 = invisible, 1 = fully visible, between: transitioning in
func get_transition_progress(node: AnimatedRichTextLabel, char_fx: CharFXTransform) -> float:
	if char_fx.relative_index < node.writer_offset or node.skipped: return 1.0
	if node._waits.size() > 0 and char_fx.relative_index >= node._waits[0][0]:
		return 0.0
	
	var effect_start: float = node.writer_offset - node.effect_width + \
		(char_fx.elapsed_time - node._start_time) * node.text_speed
	return minf(1.0, 1.0 - (char_fx.relative_index - effect_start) / node.effect_width)
