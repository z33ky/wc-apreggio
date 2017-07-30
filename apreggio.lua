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
    --TODO: explain what's done here
    local current = self.bindings
    for _, key in ipairs(binding) do
      --pre-register binding to allocate storage
      --we need to copy this as it gets modified
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
    current.action = binding.cmd
  end
end

local function unbind(bindings)
  for key, val in pairs(bindings) do
    if key == "action" then
      unbind(val)
    else
      --we need to copy this as it gets modified
      local regmods = { table.unpack(key.mods) }
      register_key({ mods = regmods, key = key.key, action = noop, loop = true, passthrough = true})
    end
  end
end

function Mode.enter(self, previous)
  if mode then
    unbind(mode.bindings)
    --make sure escape is unbound
    register_key({ mods = { }, key = "escape", action = noop, loop = true, passthrough = true})
  end

  previous = previous or mode
  mode = self

  local function do_bindings(bindings, rec)
    for key, binding in pairs(bindings) do
      if binding.action ~= nil then
        --we need to copy this as it gets modified
        local regmods = { table.unpack(key.mods) }
        register_key({ mods = regmods, key = key.key, action = binding.action, loop = true, passthrough = false})
      else
        local regmods = { table.unpack(key.mods) }
        register_key({ mods = regmods, key = key.key, action = function() do_bindings(binding, true) end, loop = true, passthrough = false})
      end
    end
    --escape by default returns to normal mode
    local _, first = next(bindings)
    if self ~= normal and not (#first == 1 and next(first[1].mods) == nil and first[1].key == "escape") then
      local target = rec and mode ~= previous and mode or previous
      register_key({ mods = { }, key = "escape", action = target:mode(previous), loop = true, passthrough = false})
    end
  end
  do_bindings(self.bindings, false)
end

function Mode.mode(self, ...)
  --returns self.enter() as a function so it can be used as a callback
  local args = { ... }
  return function() self:enter(table.unpack(args)) end
end

local function key(mod, key, cmd)
  if type(mod) == "string" then
    assert(cmd == nil)
    --mod, key, cmd = { }, mod, key
    return { { mods = { }, key = mod }, cmd = key }
  end

  return { { mods = mod, key = key }, cmd = cmd }
end

local function chain(keys, cmd)
  for i, key in ipairs(keys) do
    if type(key) == "string" then
      keys[i] = { mods = { }, key = key }
    else
      keys[i] = { mods = key[1], key = key[2] }
    end
  end
  keys.cmd = cmd
  return keys
end

return {
  init = init,
  Mode = Mode,
  key = key,
  chain = chain,
}
