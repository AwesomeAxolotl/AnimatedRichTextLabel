extends RichTextLabel
class_name AnimatedRichTextLabel
## AnimatedRichTextLabel implements a customizable fade-in effect with the help of bbcode.
## To use this extend AnimatedRichTextLabel on a script attached to RichTextLabel
## Also supports timed pauses / waiting on user input with the 'bbcode' [wait t=1.0]
## (negative wait time will be considered as infinite wait time)

# TODO: adjusting text speed should adjust 
# TODO: pausing the game should interact properly with the timers


@export var text_speed: float = 60.0 ## transition speed in characters per second 
@export var effect_width: float = 5.0 ## defines across how many characters the transition spans
@export var effect_strength: float = 5 ## can be used in transitions to modify the effect's strength
@export var transition: _transition ## choose the transition function that animates the characters

## Type-writer like bbcode effect that saves state in this instance's properties
var writer: RichTextEffect = preload("res://rich_text_effect_writer.gd").new()

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

# wait syntax: [wait t=1.0]... use negative for infinite wait...
# modify this if you want a differ
var _wait_regex := RegEx.create_from_string(r"\[wait t=(-?\d+\.?\d*)\]")
var _waits: Array[Array] = []
var _wait_timer: SceneTreeTimer
var skipped: bool = false: ## set to true to show the whole text
	set(value):
		skipped = value
		if skipped: all_displayed.emit()
var _start_time: float = 0.0 # reference time when animation started in seconds
var _elapsed_time: float = 0.0 # received from the writer script
var _character_count: int = 0 # get count only once for better performance
var _appending: bool = false

var waiting: bool = false:
	set(value):
		waiting = value
		if waiting and _waits.size() != 0:
			started_waiting.emit(_waits[0][1])
			_start_wait_timer(_waits[0][1])

## The character index the writer effect starts from. 
## Change to start the transition at the chosen index.
var writer_offset: int = 0 


# setting text in this script must be done with self.text instead of text
# otherwise this is not called
func _set(property: StringName, value: Variant) -> bool:
	if property == &"text":
		value = parse_waits(value)
		clear()
		push_customfx(writer, {"node": self})
		append_text(value)
		if _appending:
			_appending = false
			writer_offset = _get_current_offset()
		else:
			writer_offset = 0
		_start_time = 0.0
		_character_count = get_total_character_count()
		skipped = false
		waiting = false
		return true
	return false


## appending text normally will reset the animation position, use this function
## to add text to the current label (care about interations with unclosed bbcode tags)
func append(t: String) -> void:
	print("append_called")
	_appending = true
	self.text += t


func _get_current_offset() -> int:
	return clampi(
		ceil((_elapsed_time - _start_time) * text_speed + writer_offset), 
		0,
		_character_count - 1
	)

func parse_waits(t: String) -> String:
	if !_appending: _waits = []
	for wait in _wait_regex.search_all(t):
		_waits.append([0, float(wait.get_string(1))])
	text = _wait_regex.sub(t, "⏸", true)
	var t_parsed = get_parsed_text()
	var from := 0
	for i in t_parsed.count("⏸"):
		from = t_parsed.find("⏸", from) + 1
		_waits[i][0] = from - i - 1
	text = _wait_regex.sub(t, "", true)
	return text


func remove_wait():
	stop_wait_timer()
	if _waits.size() == 0: return
	_start_time = -1.0
	writer_offset = _waits[0][0]
	_waits.pop_front()
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
	else:
		remove_wait()


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
