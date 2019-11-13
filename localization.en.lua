local _, addon = ...

local _G = _G
local setmetatable = _G.setmetatable
local tostring, format, gsub = _G.tostring, _G.string.format, _G.string.gsub
local rawset, rawget = _G.rawset, _G.rawget

local L = setmetatable({}, {
  __newindex = function(self, key, value)
    rawset(self, key, value == true and key or value)
  end,
  __index = function(self, key)
    return key
  end
})

-- Quick usage of string.format
-- @param line the line to print
-- @param ...
-- @return returns the formatted
function L:F(line, ...)
  line = L[line]
  return format(line, ...)
end

addon.L = L
