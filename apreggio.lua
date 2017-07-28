local normal = nil
local mode = nil

local noop = function() end

local register_key = way_cooler.register_key

local Mode = {}
Mode.__index = Mode

function Mode.new(name)
  local self = {
    bindings = { },
    name = name,
  }
  self = setmetatable(self, Mode)
  if name == nil then
      --HACK
      normal = self
  end
  return self
end

function Mode.add(self, bindings)
  local escape_bound = false
  for _, binding in ipairs(bindings) do
    local keys, action = table.unpack(binding)

    --TODO: explain what's done here
    local current = self.bindings
    for _, key in ipairs(keys) do
      --pre-register binding to allocate storage
      --we need to copy this it gets modified
      local regmods = { table.unpack(key.mods) }
      register_key({ mods = regmods, key = key.key, action = noop, loop = true, passthrough = true})

      if not current[key] then
        current[key] = { }
      end
      current = current[key]
    end
    if next(current) ~= nil then
      --FIXME: need flashier warning
      print("Duplicate binding. Overwriting.")
    end
    current.action = action

    if #keys == 1 and next(keys[1].mods) == nil and keys[1].key == "escape" then
      escape_bound = true
    end
  end

  --FIXME: allow multiple calls to add
  --escape by default returns to normal mode
  if not escape_bound then
    self.bindings[{ mods = { }, key = "escape" }] = { action = normal:mode() }
  end
end

function Mode.mode(self)
  --return a function so it can be used as a callback
  return function()
    if mode then
      --unbind previous mode
      for idx, _ in pairs(mode.bindings) do
        if idx ~= "action" then
          --we need to copy this it gets modified
          local regmods = { table.unpack(idx.mods) }
          register_key({ mods = regmods, key = idx.key, action = noop, loop = true, passthrough = true})
        end
      end
    end
    mode = self
    local function do_bindings(bindings)
      for key, binding in pairs(bindings) do
        if binding.action ~= nil then
          --we need to copy this it gets modified
          local regmods = { table.unpack(key.mods) }
          register_key({ mods = regmods, key = key.key, action = binding.action, loop = true, passthrough = false})
        else
          local regmods = { table.unpack(key.mods) }
          register_key({ mods = regmods, key = key.key, action = function() do_bindings(binding) end, loop = true, passthrough = false})
        end
      end
    end
    do_bindings(self.bindings)
  end
end

local function key(mod, key, cmd)
  if type(mod) == "string" then
    assert(cmd == nil)
    --mod, key, cmd = { }, mod, key
    return { { { mods = { }, key = mod } }, key }
  end

  --FIXME change to flat table { mod=, key=, cmd= }
  return { { { mods = mod, key = key } }, cmd }
end

local function chain(keys, cmd)
  for i, key in ipairs(keys) do
    if type(key) == "string" then
      keys[i] = { mods = { }, key = key }
    else
      keys[i] = { mods = key[1], key = key[2] }
    end
  end
  return { keys, cmd }
end

return {
  init = init,
  Mode = Mode,
  key = key,
  chain = chain,
}
