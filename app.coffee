
audio_ctx = new AudioContext

scale_start = "C"
scale = teoria.scale scale_start, "harmonicchromatic"

keycodes = [81,65,87,83,69,68,82,70,84,71,89,72,85,74,73,75,79,76,80,186,219,222,221,13,220]

reverb = new SimpleReverb audio_ctx,
	seconds: 1
	decay: 8
	reverse: 0

reverb.connect audio_ctx.destination


scale_select = document.getElementById("scale")
scale_start_select = document.getElementById("scale-start")
disable_notes_outside_scale_checkbox = document.getElementById("disable-notes-outside-scale")
keys_container = document.getElementById("keys")
keyboard_element = document.getElementById("keyboard")

disable_notes_outside_scale = disable_notes_outside_scale_checkbox.checked
disable_notes_outside_scale_checkbox.onchange = (e)->
	disable_notes_outside_scale = e.target.checked
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
		disable = disable_notes_outside_scale and not matches
		key.element.classList[if disable then "add" else "remove"] "disabled"
		key.element.classList[if matches then "remove" else "add"] "lowlight"
		key.element.classList[if matches then "add" else "remove"] "highlight"

class Sound
	constructor: (frequency, type)->
		harmonix = 0
		
		@osc = audio_ctx.createOscillator() # Create oscillator node
		@oscs = (audio_ctx.createOscillator() for [0..harmonix])
		
		@osc.frequency.value = frequency
		osc.frequency.value = frequency * (i + 1) + (((i*0))) for osc, i in @oscs
		
		@osc.type = type ? 'saw'
		
		@osc.start(0)
		osc.start(0) for osc, i in @oscs
		
		@gain = audio_ctx.createGain()
		@gain.gain.value = 0
		
		# Waveshaping
		make_distortion_curve = (k=50)->
			n_samples = 44100
			curve = new Float32Array(n_samples)
			deg = Math.PI / 180
			for i in [0..n_samples]
				x = i * 2 / n_samples - 1
				curve[i] = ( 3 + k ) * x * 20 * deg / ( Math.PI + k * Math.abs(x) )
			curve
		
		@distortion = audio_ctx.createWaveShaper()
		@distortion.curve = make_distortion_curve(10)
		@distortion.oversample = '4x'
		
		@osc.connect(@distortion)
		osc.connect(@distortion) for osc, i in @oscs
		@distortion.connect(@gain)
		@gain.connect(reverb.input)

	play: ->
		@gain.gain.value = 1

	stop: ->
		@gain.gain.value = 0

class Key
	constructor: (@note, firstMIDI)->
		@sound = new Sound @note.fq(), 'triangle'
		@element = document.createElement 'div'
		@element.innerText = @note.toString(true)
			.replace(/^[a-g]/, ((m)-> m.toUpperCase()))
			.replace("#", "♯")
			.replace("b", "♭")
		keys_container.appendChild @element
		@element.className = "key chroma-#{"abc"[@note.midi() % 3]}"
		@element.style.position = "absolute"
		@size()
		setTimeout => @size() # in case of scrollbars
		window.addEventListener "resize", (e)=> @size()
		window.addEventListener "mouseup", (e)=> @stop()
		@element.addEventListener "mousedown", (e)=>
			return if e.button isnt 0
			@play()
			e.preventDefault()
			keys_container.focus()
	
	size: ->
		style = getComputedStyle @element
		{marginLeft, marginRight, marginTop, marginBottom} = style
		{width, height} = @element.getBoundingClientRect()
		@element.style.left = "#{(@note.midi()-firstMIDI) * (width + parseInt(marginLeft))/2}px"
		@element.style.top = "#{(@note.midi() % 2) * (height + parseInt(marginTop) + parseInt(marginBottom))}px"
		if @element.nextSibling is null
			keyboard_element.style.width = "#{parseInt(marginLeft) + parseInt(@element.style.left) + width + parseInt(marginRight)}px"
	
	play: ->
		return if disable_notes_outside_scale and not in_scale(@note)
		@sound.play()
		@element.classList.add 'playing'
	
	stop: ->
		@sound.stop()
		@element.classList.remove 'playing'

repeating = scale.simple()
notes =
	for i in [0...37]
		teoria.note repeating[i % repeating.length] + (2 + i // repeating.length)

firstMIDI = notes[0].midi()
keys = (new Key(note, firstMIDI) for note in notes)



play_note = (e)->
	return if e.defaultPrevented or e.ctrlKey or e.altKey or e.metaKey
	if keys[keycodes.indexOf(e.keyCode)]
		e.preventDefault()
		keys[keycodes.indexOf(e.keyCode)].play()

stop_note = (e)->
	keys[keycodes.indexOf(e.keyCode)]?.stop()

scale_select.addEventListener "change", update_highlight
scale_start_select.addEventListener "change", update_highlight


window.addEventListener 'keydown', play_note
window.addEventListener 'keyup', stop_note

