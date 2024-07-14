-- Enhanced Generative Rain Animation
-- for Norns
-- v2.0

engine.name = "Showers"

local raindrops = {}
local max_raindrops = 500
local min_raindrops = 50
local current_max_raindrops = max_raindrops
local splashes = {}
local lightning = false
local lightning_timer = 0
local flash_interval = 0
local flashes = 0
local flash_intensity = 15
local last_lightning_time = 0
local DEBOUNCE_TIME = 5 -- 5 second debounce
local startup_time = 0
local STARTUP_DELAY = 5 -- 5 second startup delay
local screen_ping_timer

function init()
  update_raindrop_count(0.3) -- Initialize with default rain value

  params:add_separator()

  params:add {
    type = 'control',
    id = 'rain',
    name = 'rain',
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.3),
    action = function(v) 
      print("Rain set to: " .. v)
      engine.rain(v)
      update_raindrop_count(v)
    end
  }

  params:add {
    type = 'control',
    id = 'thunder',
    name = 'thunder',
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.5),
    action = function(v) 
      print("Thunder set to: " .. v)
      engine.thunder(v)
    end
  }

  params:add{
    type = "option", 
    id = "keep_screen_on", 
    name = "Keep Screen On",
    options = {"No", "Yes"},
    default = 2,
    action = function(value)
      if value == 1 then
        screen_ping_timer:stop()
      else
        screen_ping_timer:start()
      end
    end
  }

  screen_timer = metro.init()
  screen_timer.time = 1/30
  screen_timer.event = function()
    update_raindrops()
    update_splashes()
    update_lightning()
    redraw()
  end
  screen_timer:start()

  screen_ping_timer = metro.init()
  screen_ping_timer.time = 5 -- Ping every 5 seconds
  screen_ping_timer.event = function()
    screen.ping()
  end
  screen_ping_timer:start()

  osc.event = function(path, args, from)
    print("Received OSC message:", path, args[1])
    if path == "/thunder" then
      print("Thunder message received, value:", args[1])
      attempt_trigger_lightning()
    end
  end

  startup_time = os.time()
  print("Showers script initialized")
end

function update_raindrop_count(rain_value)
  current_max_raindrops = math.floor(min_raindrops + (max_raindrops - min_raindrops) * rain_value)
  while #raindrops > current_max_raindrops do
    table.remove(raindrops)
  end
  while #raindrops < current_max_raindrops do
    add_raindrop()
  end
end

function enc(n, d)
  if n == 1 then
    params:delta("output_level", d)
  elseif n == 2 then
    params:delta("rain", d)
  elseif n == 3 then
    params:delta("thunder", d)
  end
end

function add_raindrop()
  local drop = {
    x = math.random(0, 127),
    y = math.random(0, 63),
    size = 1,
    speed = math.random(1, 4)
  }
  table.insert(raindrops, drop)
end

function add_splash(x, y)
  local splash = {
    x = x,
    y = y,
    age = 0
  }
  table.insert(splashes, splash)
end

function update_raindrops()
  for i, drop in ipairs(raindrops) do
    drop.y = drop.y + drop.speed
    if drop.y > 64 then
      add_splash(drop.x, 63)
      drop.y = 0
      drop.x = math.random(0, 127)
      drop.speed = math.random(1, 5)
    end
  end
end

function update_splashes()
  for i = #splashes, 1, -1 do
    local splash = splashes[i]
    splash.age = splash.age + 1
    if splash.age > 2 then
      table.remove(splashes, i)
    end
  end
end

function attempt_trigger_lightning()
  local current_time = os.time()
  if current_time - startup_time < STARTUP_DELAY then
    print("Lightning prevented during startup delay")
    return
  end
  if current_time - last_lightning_time >= DEBOUNCE_TIME then
    trigger_lightning()
    last_lightning_time = current_time
  else
    print("Lightning debounced. Time since last: " .. (current_time - last_lightning_time) .. " seconds")
  end
end

function trigger_lightning()
  lightning = true
  flashes = math.random(3, 8)
  lightning_timer = math.random(1, 15)
  flash_interval = lightning_timer / flashes
  flash_intensity = math.random(10, 15)
  print("Lightning triggered: flashes =", flashes, "timer =", lightning_timer, "intensity =", flash_intensity)
end

function update_lightning()
  if lightning then
    lightning_timer = lightning_timer - 1
    if lightning_timer <= 0 then
      flashes = flashes - 1
      if flashes <= 0 then
        lightning = false
      else
        lightning_timer = math.random(math.floor(flash_interval * 0.5), math.ceil(flash_interval * 1.5))
        flash_intensity = math.random(10, 15)
      end
    end
  end
end

function redraw()
  screen.ping()
  screen.clear()
  if lightning and lightning_timer % 2 == 0 then
    screen.level(flash_intensity) -- Variable intensity for lightning
    screen.rect(0, 0, 128, 64)
    screen.fill()
    screen.level(0) -- Dark drops during lightning
  else
    screen.level(15)
  end

  for i, drop in ipairs(raindrops) do
    if not lightning then
      if drop.speed <= 2 then
        screen.level(3)  -- Grey for slower drops
      else
        screen.level(15)  -- White for faster drops
      end
    else
      screen.level(0)  -- Dark drops during lightning
    end
    screen.rect(drop.x, drop.y, drop.size, drop.size)
    screen.fill()
  end

  screen.level(8)
  for i, splash in ipairs(splashes) do
    screen.circle(splash.x, splash.y, splash.age / 2)
    screen.stroke()
  end

  screen.update()
end

function cleanup()
  screen_ping_timer:stop()
end