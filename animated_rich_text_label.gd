extends RichTextLabel
class_name AnimatedRichTextLabel
## AnimatedRichTextLabel implements a customizable fade-in effect with the help of bbcode.
## To use this extend AnimatedRichTextLabel on a script attached to RichTextLabel
## Also supports timed pauses / waiting on user input with the 'bbcode' [wait t=1.0]
## (negative wait time will be considered as infinite wait time)


@export var text_speed: float = 60.0: set = _set_text_speed ## transition speed in characters per second
@export var effect_width: float = 5.0 ## defines across how many characters the transition spans
@export var effect_strength: float = 5 ## can be used in transitions to modify the effect's strength
@export var transition: _transition ## choose the transition function that animates the characters
## Enable this if you want transitions to have a maximum duration to avoid very slow fade-ins at
## low speeds.
@export var use_fixed_transition: bool = true
## Defines how long an individual character's transition may last when using a fixed transition.
@export var fixed_transition_duration: float = 0.1
## If true speed tags set the text speed relative to the node's text_speed instead of a flat value
## speed tags do not 'stack' with themselves
@export var modify_speed_relative: bool = false

## available transition functions
var transitions: Array[Callable] = [
	fade_in_simple,
	fade_in_falling,
	fade_in_stamp
]

# transitions enum must match the transitions array!
## select how characters that fade in shall be displayed
enum _transition {SIMPLE, FALLING, STAMP}


signal started_waiting(duration: float) ## emitted when starting to wait / pause
signal stopped_waiting ## emitted when wait finished
signal all_displayed ## emitted when the whole text is visible


var _char_progress: Array[Array] = []
var _elapsed_time: float = 0.0
# wait syntax: [wait t=1.0]... use negative for infinite wait...
# modify this if you want a differ
var _wait_regex := RegEx.create_from_string(r"\[wait t=(-?\d+\.?\d*)\]")
var _waits: Array[Array] = []
var _wait_timer: SceneTreeTimer
var _speed_regex := RegEx.create_from_string(r"\[speed v=(\d+\.?\d*)\]|\[/speed\]")
var _speed_modifiers: Array[Array] = []
var skipped: bool = false: ## set to true to show the whole text
	set(value):
		skipped = value
		if skipped: all_displayed.emit()
var _character_count: int = 0 # get count only once for better performance
var _last_char: int = 0
var _first_char: int = 0
var _appending: bool = false
var _speed: float
var _speed_modified: bool = false

var waiting: bool = false:
	set(value):
		waiting = value
		if waiting and _waits.size() != 0:
			started_waiting.emit(_waits[0][1])
			_start_wait_timer(_waits[0][1])

@onready var writer: RichTextEffect = Writer.new(self)

# we don't put it in _process so that the user does not need to call super
# if they implement their own version of _process
func _effect_process(delta: float = get_process_delta_time()) -> void:
	if skipped: return
	
	for c in range(_first_char, _last_char + 1):
		_add_progress(c, delta)
	
	if is_equal_approx(_char_progress[_first_char][2], 1.0):
		_first_char += 1
		if _first_char == _character_count:
			skipped = true
	
	if waiting: return
	_elapsed_time += delta
	while _last_char + 1 < _character_count:
		var cur = _char_progress[_last_char]
		var next = _char_progress[_last_char + 1]
		var add_next: float = 1 / cur[1]
		if _elapsed_time > add_next:
			check_wait(_last_char + 1)
			if waiting:
				break
			else:
				_last_char += 1
				_elapsed_time -= add_next
				next[2] = _elapsed_time * next[1] / effect_width
				_adjust_last_timing()
		else:
			break


func _initialize_char_progress():
	_speed_modified = false
	_char_progress = []
	for i in _character_count:
		_add_char_to_progress(i)
	_first_char = 0
	_last_char = 0
	_elapsed_time = 0.0


func _add_char_to_progress(i: int) -> void:
	_apply_speed_modifier(i)
	_char_progress.append([i, _speed, 0.0, _speed_modified])


# setting text in this script must be done with self.text instead of text
# otherwise this is not called
func _set(property: StringName, value: Variant) -> bool:
	if property == &"text":
		value = parse_custom_codes(value)
		clear()
		push_customfx(writer, {})
		append_text(value)
		_speed = text_speed
		_character_count = get_total_character_count()
		if _appending:
			_appending = false
			if value != "": _add_char_to_progress(_character_count)
		else:
			_char_progress = []
			_elapsed_time = 0.0
			_initialize_char_progress()
		skipped = false
		waiting = false
		return true
	return false


# Set the correct speed value for the character index i.
func _apply_speed_modifier(i: int) -> void:
	while !_speed_modifiers.is_empty() and _speed_modifiers[0][0] == i:
		if _speed_modifiers[0][1] == -1:
			_speed = text_speed
			_speed_modified = false
		elif modify_speed_relative:
			_speed = text_speed * _speed_modifiers[0][1]
			_speed_modified = true
		else:
			_speed = _speed_modifiers[0][1]
			_speed_modified = true
		_speed_modifiers.pop_front()


# setter for text_speed, ensures the currently animating text's speed is adjusted
func _set_text_speed(value: float):
	for c in _char_progress:
		if modify_speed_relative:
			c[1] *= value / text_speed
		else:
			# if no speed modifier was applied
			if !c[3]: c[1] = value
	text_speed = value
	_speed = value


## prevents a character from finishing before the previous character due to speed changes
func _adjust_last_timing(i: int = _last_char) -> void:
	var expected_finish: float = _get_remaining_duration(i - 1) + \
		_get_remaining_duration(i, true) / effect_width
	var finish_last: float = _get_remaining_duration(i)
	var time_diff := finish_last - expected_finish
	_elapsed_time += time_diff
	_add_progress(i, time_diff)


func _get_remaining_duration(i: int, ignore_progress: bool = false) -> float:
	if ignore_progress:
		return 1 * effect_width / _char_progress[i][1]
	else:
		return (1 - _char_progress[i][2]) * effect_width / _char_progress[i][1]


func _add_progress(i: int, delta: float) -> void:
	_char_progress[i][2] = min(
		_char_progress[i][2] + _char_progress[i][1] * delta / effect_width, 1
		)


func check_wait(i: int):
	if !_waits.is_empty() and _waits[0][0] == i:
		waiting = true


## appending text normally will reset the animation position, use this function
## to add text to the current label (care about interations with unclosed bbcode tags)
func append(t: String) -> void:
	_appending = true
	self.text += t


## parses the pseudo-bbcodes custom to this class ([speed v=...] [wait t=...])
func parse_custom_codes(t: String) -> String:
	if !_appending:
		_waits = []
		_speed_modifiers = []
	for wait in _wait_regex.search_all(t):
		_waits.append([0, float(wait.get_string(1))])
	for modifier in _speed_regex.search_all(t):
		if modifier.get_string() == "[/speed]":
			_speed_modifiers.append([0, -1])
		else:
			_speed_modifiers.append([0, float(modifier.get_string(1))])
	text = _wait_regex.sub(_speed_regex.sub(t, "⏩", true), "⏸", true)

	var t_parsed = get_parsed_text()
	#var from := 0
	var wait_i := 0
	var speed_i := 0
	var modifier_regex := RegEx.create_from_string(r"⏸|⏩")
	for modifier: RegExMatch in modifier_regex.search_all(t_parsed):
		match modifier.get_string():
			"⏸":
				_waits[wait_i][0] = modifier.get_start() - wait_i - speed_i
				wait_i += 1
			"⏩":
				_speed_modifiers[speed_i][0] = modifier.get_start() - wait_i - speed_i
				speed_i += 1
	text = t
	return _wait_regex.sub(_speed_regex.sub(t, "", true), "", true)


func remove_wait():
	stop_wait_timer()
	if _waits.size() == 0: return
	_waits.pop_front()
	_last_char += 1
	_elapsed_time = 0.0
	stopped_waiting.emit()
	waiting = false


## Skip to the next wait tag or to the end of the text, showing all text up to
## this point. If  
func skip(all: bool = false):
	if skipped: return
	if all: skipped = true
	if _waits.size() == 0: 
		skipped = true
		return
	elif waiting:
		remove_wait()
	else:
		for i in range(_first_char, _waits[0][0]):
			_char_progress[i][2] = 1.0
		_first_char = _waits[0][0] - 1
		_last_char = _waits[0][0] - 1


func _start_wait_timer(duration: float) -> void:
	if duration < 0: return
	_wait_timer = get_tree().create_timer(duration)
	_wait_timer.timeout.connect(remove_wait)


## if the node is currently waiting and a wait time was specified, calling this
## will prevent the text from automatically resuming
func stop_wait_timer() -> void:
	if _wait_timer == null: return
	if _wait_timer.timeout.is_connected(remove_wait):
		_wait_timer.timeout.disconnect(remove_wait)
	_wait_timer = null


## Maps the progress value of the effect to a maximum effect duration.
## Duration cannot exceed the total time it takes to progress from 0 to 1.
func progress_static_duration(progress: float, duration: float, i: int) -> float:
	if _first_char == 0:
		var min_progress = 1 - duration * _speed / effect_width
		if _char_progress[0][2] < min_progress:
			_effect_process(1 / _speed * effect_width * min_progress)
	var ratio = min(1, duration * _char_progress[i][1] / effect_width)
	return (progress - 1 + ratio) / ratio


## simple alpha fade-in
func fade_in_simple(
	char_fx: CharFXTransform, progress: float, _effect_strength: float
	) -> void:
		char_fx.color.a *= progress


## characters will fall from above during transitioning in
func fade_in_falling(
	char_fx: CharFXTransform, progress: float, _effect_strength: float
	) -> void:
	if is_equal_approx(progress, 1.0): return
	char_fx.color.a *= progress
	char_fx.transform = char_fx.transform.translated(
		Vector2(0, - _effect_strength * (1 - progress))
		)


## characters will start with a large size during transitioning in
func fade_in_stamp(
	char_fx: CharFXTransform, progress: float, _effect_strength: float
	) -> void:
	if is_equal_approx(progress, 1.0): return
	char_fx.color.a *= progress
	char_fx.transform = char_fx.transform.scaled_local((
		Vector2(2.5 - 1.5 * progress, 2.5 - 1.5 * progress)
	))
	char_fx.offset = Vector2(0, (1 - progress) * _effect_strength)


class Writer extends RichTextEffect:
	var bbcode = "writer"
	var node: AnimatedRichTextLabel
	
	func _init(_node: AnimatedRichTextLabel = null):
		node = _node

	func _process_custom_fx(char_fx: CharFXTransform):
		if node == null or node.skipped: return true
		if char_fx.relative_index == 0: node._effect_process()
		var progress: float = max(0, node._char_progress[char_fx.relative_index][2])
		if node.use_fixed_transition:
			progress = node.progress_static_duration(
				progress, node.fixed_transition_duration, char_fx.relative_index
				)
		node.transitions[node.transition].callv([
			char_fx, progress, node.effect_strength
		])
		return true
