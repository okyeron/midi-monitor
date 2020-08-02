--  
--   MIDI MONITOR
--   0.5 - @okyeron
--
--
--   E1 - select MIDI device
--   E3 - scrollback through MIDI messages
--
--   K2 - toggle unmute/mute internal synth
--   K3 - clear screen / buffer
--

engine.name = 'PolyPerc'


local devicepos = 1
local mdevs = {}
local midi_device
local msg = {}

--local t = 0 -- last tap time
--local dt = 1 -- last tapped delta
local default_bpm = 90
local tempo
local running = false
local clocking = false

local blinkers = {false}
local mute = true

local midi_buffer = {}
local midi_buffer_len = 256
local buff_start = 1

-- display grid setup
local line_height = 8
local line_offset = 16
local col1 = 0
local col2 = 11
local col3 = 29
local col4 = col3 + 18
local col5 = col4 + 44
local col6 = 128

-- 

function blink_generator(x)
  while true do
      --print (clock.get_beats() )
    clock.sync(1/2)
      --print (clock.get_beats() )
    blinkers[x] = not blinkers[x]
    redraw()
  end
end

-- 
-- INIT
-- 

function init()
  clear_midi_buffer()
  engine.amp(0)
  --_norns.rev_off()

  connect()
  get_midi_names()
  print_midi_names()
 
  -- setup params
  
  params:add{type = "option", id = "midi_device", name = "MIDI-device", options = mdevs , default = 1,
    action = function(value)
      midi_device.event = nil
      --grid.cleanup()
      midi_device = midi.connect(value)
      midi_device.event = midi_event
      midi.update_devices()

      mdevs = {}
      get_midi_names()
      params.params[1].options = mdevs
      --tab.print(params.params[1].options)
      devicepos = value
      if clocking then 
        clock.cancel(blink_id)
        clocking = false
      end
      print ("midi ".. devicepos .." selected: " .. mdevs[devicepos])
      
    end}

  clock.set_source(1)
  params:set("clock_source", 2)
  params:set("clock_tempo", default_bpm)
  
  --tempo = util.round (clock.get_tempo(), 1)
  --tempo2 = util.round (params:get("clock_tempo"),1)
  --print(tempo)
  --print(tempo2)

  
  -- Render Style
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)

end
-- END INIT


function get_midi_names()
  -- Get a list of grid devices
  for id,device in pairs(midi.vports) do
    mdevs[id] = device.name
  end
end

function print_midi_names()
  -- Get a list of grid devices
  print ("MIDI Devices:")
  for id,device in pairs(midi.vports) do
    mdevs[id] = device.name
    print(id, mdevs[id])
  end
end

function connect()
  midi.update_devices()
  midi_device = midi.connect(devicepos)
  midi_device.event = midi_event
  --midi_device.add = on_midi_add
  --midi_device.remove = on_midi_remove
end

function clear_midi_buffer()
  midi_buffer = {}
  for z=1,midi_buffer_len do
    table.insert(midi_buffer, {})
  end 
end

function midi_event(data)
  msg = midi.to_msg(data)
  if msg.type == "start" then
      clock.transport.reset()
      clock.transport.start()
  elseif msg.type == "continue" then
    if running then 
      clock.transport.stop()
    else 
      clock.transport.start()
    end
  end 
  if msg.type == "stop" then
    clock.transport.stop()
  end 

  if msg.type == "clock" then
    if not clocking then
      clocking = true
      blink_id = clock.run(blink_generator, 1)
      tempo = util.round (clock.get_tempo(), 1)
    end
  else
    -- {msg.ch, msg.note , msg.vel, msg.type, msg.val}
    temp_msg = {}
    if msg.ch then temp_msg[1] = msg.ch else temp_msg[1] = "" end
    if msg.note then temp_msg[2] = msg.note else temp_msg[2] = "" end
    if msg.vel then temp_msg[3] = msg.vel else temp_msg[3] = "" end
    if msg.type and msg.type ~= "clock" then 
      if msg.cc then
        temp_msg[4] = msg.type ..": ".. msg.cc
      else
        temp_msg[4] = msg.type 
      end
    else 
      temp_msg[4] = "" 
    end
    if msg.val then temp_msg[5] = msg.val else temp_msg[5] = "" end
    table.insert (midi_buffer, 1, temp_msg)
    
    if not mute then
      play(msg) -- play notes with default engine
    end
    
    redraw()
  end
end


-- 
-- CLOCK coroutines
-- 

function pulse()
  while true do
    --clock.sync(1/8)
    --step_event()
  end
end

function clock.transport.start()
  print("transport.start")
  running = true

  --id = clock.run(pulse)
  --running = true
end

function clock.transport.stop()
  print("transport.stop")
  running = false
end

function clock.transport.reset()
  --print("transport.reset")
end

--
-- play notes
--

function play(msg)
  if msg.type == 'note_on' then
    hz = note_to_hz(msg.note)
    --print(hz)
    engine.amp(msg.vel / 127)
    engine.hz(hz)
  end
  if msg.type == 'note_off' then
    engine.amp(0)
  end
end

--
-- Interaction
--

function key(n, z)
  if n==2 and z == 1 then
    mute = not mute
  end
  if n == 3 and z == 1 then
    clear_midi_buffer()
  end
  redraw()
end

function enc(id,delta)
  if id == 1 then
    --print(params:get("midi_device"))
    params:set("midi_device", util.clamp(devicepos+delta, 1,4))
    if clocking then
      clock.cancel(blink_id)
      clocking = false
    end
  end
  if id == 2 then
  end 
  if id == 3 then
    buff_start = util.clamp(buff_start + delta, 1, midi_buffer_len-5)
  end
  
  redraw()
end

--
-- Screen Render
--

function draw_labels()
  screen.level(1)
  screen.move(col1,(line_height * 2))
  screen.text('ch')
  screen.move(col2,(line_height * 2))
  screen.text('num')
  screen.move(col3,(line_height * 2))
  screen.text('vel')
  screen.move(col4,(line_height * 2))
  screen.text('type')
  screen.move(col5,(line_height * 2))
  screen.text('value')
  screen.move(col6,(line_height * 2))
  screen.text_right('ln')
end

function draw_event()
  for i=1,6 do
    --print("i:",i)
    buf_idx = buff_start + i - 1
    if midi_buffer[buf_idx][1] ~= nil then
      screen.level(12)
      screen.move(col1+1,(line_offset + line_height * i))
      screen.text(midi_buffer[buf_idx][1])
      screen.move(col2+1,(line_offset + line_height * i))
      screen.text(midi_buffer[buf_idx][2])
      screen.move(col3+2,(line_offset + line_height * i))
      screen.text(midi_buffer[buf_idx][3])
      screen.move(col4,(line_offset + line_height * i))
      screen.text(midi_buffer[buf_idx][4])
      screen.move(col5,(line_offset + line_height * i))
      screen.text(midi_buffer[buf_idx][5])
      screen.stroke()
      screen.level(3)
      screen.move(col6,(line_offset + line_height * i))
      screen.text_right(buf_idx)
      screen.stroke()
    end
  end 
end

function redraw()
  tempo_disp = util.round (clock.get_tempo(), 1)

  screen.clear()
  draw_labels()
  if msg then
    draw_event()
  end
  
  screen.level(3)
  screen.move(90,7)
  screen.text('bpm')
  screen.move(110,7)
  screen.text(tempo_disp)
  screen.stroke()
  
  if blinkers[1] and clocking then
      screen.level(12)
      screen.rect(124, 3, 4, 4)
      screen.fill()  
      -- screen.pixel(112, 6)
  else 
      screen.level(1)
      screen.rect(124, 3, 4, 4)
      screen.fill()  
  end
  
  screen.level(1)
  screen.line_width (1.5)
  screen.move(0, 18)
  screen.line (128, 18)
  screen.stroke()

  --screen.line_width (1)
  --screen.move(116, 10)
  --screen.line (116, 64)
  --screen.stroke()

  screen.level(15)
  screen.move(0, 7)
  screen.text(devicepos .. ": ".. mdevs[devicepos])

  screen.update()
end

--
-- Utils
--

function note_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

