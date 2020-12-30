--- ~ Sines v0.8 ~
-- E1 - norns volume
-- E2 - select sine 1-16
-- E3 - set sine amplitude
-- K2 + E2 - change note
-- K2 + E3 - detune
-- K2 + K3 - set voice panning
-- K3 + E2 - change envelope
-- K3 + E3 - change FM index
-- K1 + E2 - change sample rate
-- K1 + E3 - change bit depth
local sliders = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local env_types = {"drone", "am1", "am2", "am3", "pulse1", "pulse2", "pulse3", "pulse4", "ramp1", "ramp2", "ramp3", "ramp4", "evolve1", "evolve2", "evolve3", "evolve4"}
-- env_num, env_bias, attack, decay. bias of 1.0 is used to create a static drone
local envs = {{1, 1.0, 1.0, 1.0},--drone
{2, 0.0, 0.001, 0.01},--am1
{3, 0.0, 0.001, 0.02},--am2
{4, 0.0, 0.001, 0.05},--am3
{5, 0.0, 0.001, 0.1},--pulse1
{6, 0.0, 0.001, 0.2},--pulse2
{7, 0.0, 0.001, 0.5},--pulse3
{8, 0.0, 0.001, 0.8},--pulse4
{9, 0.0, 1.5, 0.01},--ramp1
{10, 0.0, 2.0, 0.01},--ramp2
{11, 0.0, 3.0, 0.01},--ramp3
{12, 0.0, 4.0, 0.01},--ramp4
{13, 0.3, 10.0, 10.0},--evolve1
{14, 0.3, 15.0, 11.0},--evolve2
{15, 0.3, 20.0, 12.0},--evolve3
{16, 0.3, 25.0, 15.0}--evolve4
}
local env_values = {}
local fm_index_values = {}
local bit_depth_values = {}
local smpl_rate_values = {}
local edit = 1
local env_edit = 1
local accum = 1
local env_accum = 1
local step = 0
local freq_increment = 0
local cents_increment = 0
local cents_values = {}
local scale_names = {}
local notes = {}
local key_1_pressed = 0
local key_2_pressed = 0
local key_3_pressed = 0
local toggle = false
local pan_display = "m"

engine.name = "Sines"
MusicUtil = require "musicutil"

function init()
  print("loaded Sines engine")
  add_params()
  set_voices()
end

function add_params()
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
  end
  params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 5,
  action = function() build_scale() end}
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
  action = function() build_scale() end}
  --set voice vol, fm, env controls
  for i = 1,16 do
    params:add_control("vol" .. i, "voice " .. i .. " volume", controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0))
    params:set_action("vol" .. i, function(x) set_voice(i - 1, x) end)
  end
  for i = 1,16 do
    params:add_control("fm_index" .. i, "fm index " .. i, controlspec.new(0.1, 200.0, 'lin', 0.1, 3.0))
    params:set_action("fm_index" .. i, function(x) engine.fm_index(i - 1, x) end)
  end
  for i = 1,16 do
    params:add_number("env" .. i, "envelope " .. i, 1, 16, 1)
    params:set_action("env" .. i, function(x) set_env(i, x) end)
  end
  for i = 1,16 do
    params:add_number("smpl_rate" .. i, "sample rate " .. i, 4410, 44100, 44100)
    params:set_action("smpl_rate" .. i, function(x) engine.sample_rate(i - 1, x) end)
  end
  for i = 1,16 do
    params:add_number("bit_depth" .. i, "bit depth " .. i, 1, 24, 24)
    params:set_action("bit_depth" .. i, function(x) engine.bit_depth(i - 1, x) end)
  end
  params:default()
  edit = 0
end

function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
  local num_to_add = 16 - #notes
  for i = 1, num_to_add do
    table.insert(notes, notes[16 - num_to_add])
  end
  for i = 1,16 do
    --also set notes
    set_freq(i, MusicUtil.note_num_to_freq(notes[i]))
  end
end

function set_voice(voice_num, value)
  engine.vol(voice_num, value)
  --also set the currently edited voice
  edit = voice_num
end

function set_voices()
  for i = 1,16 do
    cents_values[i] = 0
    env_values[i] = env_types[params:get("env" .. i)]
    fm_index_values[i] = params:get("fm_index" .. i)
    smpl_rate_values[i] = params:get("smpl_rate" .. i)
    bit_depth_values[i] = params:get("bit_depth" .. i)
  end
end

function set_env(synth_num, env_num)
  --goofy way to loop through the envs list, but whatever
  for i = 1,16 do
    if envs[i][1] == env_num then
      engine.env_bias(synth_num - 1, envs[i][2])
      engine.amp_atk(synth_num - 1, envs[i][3])
      engine.amp_rel(synth_num - 1, envs[i][4])
    end
  end
  env_edit = env_num
  env_values[synth_num] = env_types[env_edit]  
end

function set_freq(synth_num, value)
  engine.hz(synth_num - 1, value)
  engine.hz_lag(synth_num - 1, 0.005)
end

function set_synth_pan(synth_num, value)
  engine.pan(synth_num - 1, value)
end

--update when a cc change is detected
m = midi.connect()
m.event = function(data)
  redraw()
  local d = midi.to_msg(data)
  if d.type == "cc" then
    --set all the sliders + fm values
    for i = 1,16 do
      sliders[i] = (params:get("vol" .. i))*32-1
      fm_index_values[i] = params:get("fm_index" .. i)
      bit_depth_values[i] = params:get("bit_depth" .. i)
      smpl_rate_values[i] = params:get("smpl_rate" .. i)
      if sliders[i] > 32 then sliders[i] = 32 end
      if sliders[i] < 0 then sliders[i] = 0 end
    end
  end
  redraw()
end

function set_pan()
  -- pan position on the bus, -1 is left, 1 is right
  if key_2_pressed == 1 and key_3_pressed == 1 then
    toggle = not toggle
    if toggle then
      pan_display = "l/r"
      --set hard l/r pan values
      for i = 1,16 do
        if i % 2 == 0 then
          --even, pan right
          set_synth_pan(i,1)
        elseif i % 2 == 1 then
          --odd, pan left
          set_synth_pan(i,-1)
        end
      end
    end
    if not toggle then
      pan_display = "m"
      for i = 1,16 do
        set_synth_pan(i,0)
      end
    end
  end
end

function enc(n, delta)
  if n == 1 then
    if key_1_pressed == 0 then 
      params:delta('output_level', delta)
    end
  elseif n == 2 then
    if key_1_pressed == 0 and key_2_pressed == 0 and key_3_pressed == 0 then
      --navigate up/down the list of sliders
      --accum wraps around 0-15
      accum = (accum + delta) % 16
      --edit is the slider number
      edit = accum
    elseif key_1_pressed == 0 and key_2_pressed == 0 and key_3_pressed == 1 then
      env_accum = (env_accum + delta) % 16
      --env_edit is the env_values selector
      env_edit = env_accum
      --set the env
      set_env(edit+1, env_edit+1)
    elseif key_1_pressed == 0 and key_2_pressed == 1 and key_3_pressed == 0 then
      -- increment the note value with delta
      notes[edit+1] = notes[edit+1] + util.clamp(delta, -1, 1)
      set_freq(edit+1, MusicUtil.note_num_to_freq(notes[edit+1]))
      cents_values[edit+1] = 0
      cents_increment = 0
      freq_increment = 0
    elseif key_1_pressed == 1 and key_2_pressed == 0 and key_3_pressed == 0 then
      --set sample rate
      params:set("smpl_rate" .. edit+1, params:get("smpl_rate" .. edit+1) + (delta) * 100)
      smpl_rate_values[edit+1] = params:get("smpl_rate" .. edit+1)
    end
  elseif n == 3 then
    if key_1_pressed == 0 and key_3_pressed == 0 and key_2_pressed == 0 then
      --set the slider value
      sliders[edit+1] = sliders[edit+1] + delta
      amp_value = util.clamp(((sliders[edit+1] + delta) * .026), 0.0, 1.0)
      params:set("vol" .. edit+1, amp_value)
      if sliders[edit+1] > 32 then sliders[edit+1] = 32 end
      if sliders[edit+1] < 0 then sliders[edit+1] = 0 end
    elseif key_1_pressed == 0 and key_2_pressed == 1 and key_3_pressed == 0 then
      -- increment the current note freq
      freq_increment = freq_increment + util.clamp(delta, -1, 1) * 0.1
      -- calculate increase in cents
      -- https://music.stackexchange.com/questions/17566/how-to-calculate-the-difference-in-cents-between-a-note-and-an-arbitrary-frequen
      cents_increment = 3986*math.log((MusicUtil.note_num_to_freq(notes[edit+1]) + freq_increment)/(MusicUtil.note_num_to_freq(notes[edit+1])))
      -- round down to 2 dec points
      cents_increment = math.floor((cents_increment) * 10 / 10)
      cents_values[edit+1] = cents_increment
      set_freq(edit+1, MusicUtil.note_num_to_freq(notes[edit+1]) + freq_increment)
    elseif key_1_pressed == 0 and key_2_pressed == 0 and key_3_pressed == 1 then
      -- set the index_slider value
      params:set("fm_index" .. edit+1, params:get("fm_index" .. edit+1) + (delta) * 0.1)
      fm_index_values[edit+1] = params:get("fm_index" .. edit+1)
    elseif key_1_pressed == 1  and key_2_pressed == 0 and key_3_pressed == 0 then
      --set bit depth
      params:set("bit_depth" .. edit+1, params:get("bit_depth" .. edit+1) + (delta))
      bit_depth_values[edit+1] = params:get("bit_depth" .. edit+1)
    end
  end
  redraw()
end

function key(n, z)
  --use these keypress variables to add extra functionality on key hold
  if n == 1 and z == 1 then
    key_1_pressed = 1
  elseif n == 1 and z == 0 then
    key_1_pressed = 0  
  elseif n == 2 and z == 1 then
    key_2_pressed = 1
  elseif n == 2 and z == 0 then
    key_2_pressed = 0
  elseif n == 3 and z == 1 then
    key_3_pressed = 1
  elseif n == 3 and z == 0 then
    key_3_pressed = 0
  end
  set_pan()
  redraw()
end

function redraw()
  screen.aa(1)
  screen.line_width(2.0)
  screen.clear()

  for i= 0, 15 do
    if i == edit then
      screen.level(15)
    else
      screen.level(2)
    end
    screen.move(32+i*4, 62)
    screen.line(32+i*4, 60-sliders[i+1])
    screen.stroke()
  end
  screen.level(10)
  screen.line(32+step*4, 68)
  screen.stroke()
  --display current values
  screen.move(0,5)
  screen.level(2)
  screen.text("Note: ")
  screen.level(15)
  screen.text(MusicUtil.note_num_to_name(notes[edit+1],true) .. " ")
  screen.level(2)
  screen.text("Detune: ")
  screen.level(15)
  screen.text(cents_values[edit+1] .. " cents")
  screen.move(0,12)
  screen.level(2)
  screen.text("Env: ")
  screen.level(15)
  screen.text(env_values[edit+1])
  screen.level(2)
  screen.text(" FM Ind: ")
  screen.level(15)
  screen.text(fm_index_values[edit+1])
  screen.move(0,19)
  screen.level(2)
  screen.text("Smpl rate: ")
  screen.level(15)
  screen.text(smpl_rate_values[edit+1]/1000)
  screen.level(2)
  screen.text(" Bit dpt: ")
  screen.level(15)
  screen.text(bit_depth_values[edit+1])
  screen.move(0,26)
  screen.level(2)
  screen.text("Pan: ")
  screen.level(15)
  screen.text(pan_display)
  screen.level(2)
  screen.text(" Vol: ")
  screen.level(15)
  screen.text(math.floor((params:get('output_level')) * 10 / 10) .. " dB")
  screen.update()
end