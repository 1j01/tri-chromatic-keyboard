
audio_ctx = new AudioContext

scale_start = "C"
scale = teoria.scale scale_start, "harmonicchromatic"

reverb = new SimpleReverb audio_ctx,
	seconds: 1
	decay: 8
	reverse: 0

reverb.connect audio_ctx.destination


scale_select = document.getElementById("scale")
scale_start_select = document.getElementById("scale-start")
disable_keys_outside_scale_checkbox = document.getElementById("disable-keys-outside-scale")
keys_container = document.getElementById("keys")
keyboard_element = document.getElementById("keyboard")

disable_keys_outside_scale = disable_keys_outside_scale_checkbox.checked
disable_keys_outside_scale_checkbox.onchange = (e)->
	disable_keys_outside_scale = e.target.checked
	update_highlight()

in_scale = (note)->
	scale_name = scale_select.selectedOptions[0].value
	scale_start = scale_start_select.selectedOptions[0].value
	scale_notes = teoria.scale(scale_start, scale_name).notes()
	scale_midi_values = (scale_note.midi() % 12 for scale_note in scale_notes)
	(note.midi() % 12) in scale_midi_values

update_highlight = (e)->
	for key in keys
		matches = in_scale(key.note)
		disable = disable_keys_outside_scale and not matches
		key.element.classList[if disable then "add" else "remove"] "disabled"
		key.element.classList[if matches then "remove" else "add"] "lowlight"
		key.element.classList[if matches then "add" else "remove"] "highlight"

instrument = "marimba" # "vibraphone" # "acoustic_grand_piano"
MIDI.loadPlugin
	api: "webaudio"
	soundfontUrl: "./lib/soundfont/" # "https://gleitz.github.io/midi-js-soundfonts/FluidR3_GM/"
	instrument: instrument
	onprogress: (state, progress)->
		console?.log(state, progress)
	onerror: (err)->
		console?.error(err)
	onsuccess: ->
		console?.log "MIDI.js loaded"
		MIDI.programChange(0, MIDI.GM.byName[instrument].number)

class Key
	constructor: (@note, firstMIDI)->
		@element = document.createElement 'div'
		@element.dataset.note =
		@element.innerText =
			@note.toString(true)
				.replace(/^[a-g]/, ((m)-> m.toUpperCase()))
				.replace("#", "♯")
				.replace("b", "♭")
		keys_container.appendChild @element
		@element.className = "key chroma-#{"abc"[@note.midi() % 3]}"
		@element.style.position = "absolute"
		@size()
		setTimeout => @size() # in case of scrollbars
		window.addEventListener "resize", (e)=> @size()
		@element.key = @
		@pressedness = 0
	
	size: ->
		style = getComputedStyle @element
		{marginLeft, marginRight, marginTop, marginBottom} = style
		{width, height} = @element.getBoundingClientRect()
		@element.style.left = "#{(@note.midi()-firstMIDI) * (width + parseInt(marginLeft))/2}px"
		@element.style.top = "#{(@note.midi() % 2) * (height + parseInt(marginTop) + parseInt(marginBottom))}px"
		if @element.nextSibling is null
			keyboard_element.style.width = "#{parseInt(marginLeft) + parseInt(@element.style.left) + width + parseInt(marginRight)}px"
	
	play: ->
		return if disable_keys_outside_scale and not in_scale(@note)
		delay = 0 # play one note every quarter second
		velocity = 127 # how hard the note hits
		MIDI.setVolume(0, 127)
		MIDI.noteOn(0, @note.midi(), velocity, delay)
		@element.classList.add 'playing'
	
	stop: ->
		MIDI.noteOff(0, @note.midi(), 0)
		@element.classList.remove 'playing'
	
	press: ->
		@pressedness++
		@play() unless @element.classList.contains 'playing'
	
	release: ->
		if --@pressedness <= 0
			@pressedness = 0
			@stop()


repeating = scale.simple()
notes =
	for i in [0...37]
		teoria.note repeating[i % repeating.length] + (2 + i // repeating.length)

firstMIDI = notes[0].midi()
keys = (new Key(note, firstMIDI) for note in notes)



# keycodes = [81,65,87,83,69,68,82,70,84,71,89,72,85,74,73,75,79,76,80,186,219,222,221,13,220]

# blank_layout =
# 	name: 'blank'
# 	layout: [
# 		['','','','','','','','','','','','','']
# 		['','','','','','','','','','','','','']
# 		['','','','','','','','','','','']
# 		['','','','','','','','','','']
# 	]
# 	offsets: [0, 1.5, 1.75, 2.25]


# ll = new Layoutline(layouts, 200)
# current_layout = blank_layout

interleave_arrays = (arrays)->
	result = []
	max_length = 0
	for array in arrays
		max_length = Math.max(max_length, array.length)
	for i in [0..max_length]
		for array in arrays
			if i < array.length
				result.push(array[i])
	result
	# result = []
	# i = 0
	# loop
	# 	ended = no
	# 	for row in keycode_rows
	# 		if i >= row.length
	# 			ended = yes
	# 		else
	# 			result.push(row[i])
	# 	break if ended
	# 	i += 1
	# result

keycode_rows = [
	[192,49,50,51,52,53,54,55,56,57,48,189,187,8]
	[9,81,87,69,82,84,89,85,73,79,80,219,221,220]
	# [65,83,68,70,71,72,74,75,76,186,222,13]
	# [90,88,67,86,66,78,77,188,190,191,16]
]
recording_row_index = keycode_rows.length
keycodes = interleave_arrays(keycode_rows)

pressed_keyboard_keys = {}

window.addEventListener 'keydown', (e)->
	return if e.defaultPrevented or e.ctrlKey or e.altKey or e.metaKey
	# keycode_rows[recording_row_index] ?= []
	# keycode_rows[recording_row_index].push(e.keyCode)
	# console.log JSON.stringify(keycode_rows)
	if keys[keycodes.indexOf(e.keyCode)]
		e.preventDefault()
		return if pressed_keyboard_keys[e.keyCode]
		pressed_keyboard_keys[e.keyCode] = on
		keys[keycodes.indexOf(e.keyCode)].press()

window.addEventListener 'keyup', (e)->
	delete pressed_keyboard_keys[e.keyCode]
	keys[keycodes.indexOf(e.keyCode)]?.release()


scale_select.addEventListener "change", update_highlight
scale_start_select.addEventListener "change", update_highlight


pointers = {}

keys_container.setAttribute "touch-action", "none"

window.addEventListener "pointerup", (e)->
	if pointers[e.pointerId]
		pointers[e.pointerId].key?.release()
		delete pointers[e.pointerId]

window.addEventListener "pointercancel", (e)->
	if pointers[e.pointerId]
		pointers[pointerId].key?.release()
		delete pointers[e.pointerId]

window.addEventListener "blur", (e)->
	for keyCodeKey, keyIsDown of pressed_keyboard_keys
		keyCode = parseInt(keyCodeKey)
		keys[keycodes.indexOf(keyCode)]?.release()
	pressed_keyboard_keys = {}
	for pointerId, _ of pointers
		pointers[pointerId].key?.release()
		delete pointers[pointerId]

keys_container.addEventListener "contextmenu", (e)->
	# easily accidentally triggered trying to use multitouch
	e.preventDefault()

keys_container.addEventListener "mousedown", (e)->
	# prevent selection starting (preventing selectstart here doesn't work)
	e.preventDefault()

keys_container.addEventListener "pointerdown", (e)->
	if e.button is 0
		pointers[e.pointerId]?.key?.release()
		pointers[e.pointerId] = {}
		pointers[e.pointerId].key = e.target.key
		e.target.key?.press()

keys_container.addEventListener "pointerover", (e)->
	if pointers[e.pointerId]
		pointers[e.pointerId].key?.release()
		pointers[e.pointerId].key = e.target.key
		e.target.key?.press()

keys_container.addEventListener "pointerout", (e)->
	if pointers[e.pointerId]
		pointers[e.pointerId].key?.release()
		pointers[e.pointerId].key = null
