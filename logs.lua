local _, addon = ...
local utils = addon.utils
local L = addon.L

local mod = {}

local unitName
local UIFrame, frameName
local loaded, fetched, spellId

local logs = {}

local _G = _G
local format = _G.string.format

local function resetList()
  local i = 1
  local btn = _G[frameName..'_LogBtn_'..i]
  while btn do
    btn:Hide()
    i = i + 1
    btn = _G[frameName..'_LogBtn'..i]
  end
end

local function resetFrameStatus()
  logs = table.wipe(logs)
  loaded, fetched, spellId = nil, nil, nil
  resetList()
end

local function loadLogs()
  if spellId then
    logs = {}

    for n, p in pairs(Elvin_Cooldowns[spellId].players) do
      for k, v in pairs(p.logs) do
        tinsert(logs, {
          time = k,
          player = n,
          target = v
        })
      end
    end
    table.sort(logs, function(a, b) return (a.time > b.time) end)
  end
  loaded=true
end



local function fetchLogs()
  resetList()

  -- Set title
  local spellName = GetSpellLink(spellId) or GetSpellInfo(spellId)
  local currentTime = utils.getCurrentTime()
  if spellName then
    _G[frameName..'Title']:SetText(format('%2$s - %1$s', spellName, date('%Y/%m/%d', currentTime)))
  end

  local scrollFrame = _G[frameName..'ListScrollFrame']
  local scrollChild = _G[frameName..'ListScrollFrameScrollChild']
  scrollChild:SetHeight(scrollFrame:GetHeight())
  scrollChild:SetWidth(scrollFrame:GetWidth())
  local height = 0

  for k, v in ipairs(logs) do
    local btnName = frameName..'_LogBtn_'..k
    local btn = _G[btnName] or CreateFrame('Button', btnName, scrollChild, 'ElvinCDs_LogsButton')
    btn:SetID(k)
    btn:Show()

    -- Set the time:
    _G[btnName..'Time']:SetText(date('%H:%M', v.time))

    -- Prepare classes
    local pID, tID = utils.getPlayerUnitId(v.player), utils.getPlayerUnitId(v.target)
    local _, pClass = UnitClass(pID)
    local name = '|cff'..utils.classColorHex(pClass)..v.player..'|r'
    if tID ~= 'none' then
      local _, tClass = UnitClass(tID)
      name = name..' > '..'|cff'..utils.classColorHex(tClass)..v.target..'|r'
    end
    _G[btnName..'Name']:SetText(name)

    btn:SetScript('OnClick', function(self, button)
      if button == 'LeftButton' and IsControlKeyDown() then
        if v.target == '' or v.target == unitName then
          utils.announce(L:F('%s used %s at %s', v.player, spellName, date('%H:%M', v.castTime)), 'RAID')
        else
          utils.announce(L:F('%s used %s on %s at %s', v.player, spellName, v.target, date('%H:%M', v.castTime)), 'RAID')
        end
      end
    end)

    btn:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, -height)
    btn:SetPoint('RIGHT', scrollChild, 'RIGHT', 0, 0)
    height = height + btn:GetHeight()
  end

  fetched=true
end

local function updateUIFrame(self, elapsed)
  if utils.update(self, frameName, 0.05, elapsed) then
    if not loaded then loadLogs() end
    if not fetched then fetchLogs() end

    local index = #logs+1
    local btn = _G[frameName..'_LogBtn_'..index]
    while btn do
      btn:Hide()
      index = index + 1
      btn = _G[frameName..'_LogBtn_'..index]
    end
  end
end

function mod:onLoad(frame)
  if not frame then return end
  UIFrame = frame
  frameName = frame:GetName()
  frame:RegisterForDrag('LeftButton')
  frame:SetScript('OnUpdate', updateUIFrame)
  frame:SetScript('OnHide', resetFrameStatus)
  tinsert(UISpecialFrames, frameName)
end



function mod:view(id)
  if UIFrame:IsShown() then
    resetFrameStatus()
  end
  if not id or not Elvin_Cooldowns[id] then return end
  spellId = id
end

function mod:reset()
  resetFrameStatus()
end

local fname = 'ElvinCDs_LogsFrame'
local mainFrame = CreateFrame('Frame', fname)
mainFrame:SetScript('OnUpdate', function(self, elapsed)
  if utils.update(self, fname, 0.05, elapsed) then

    if not unitName then
      unitName = select(1, UnitName('player'))
      addon.unitName = unitName
    end

    utils.showHide(UIFrame, (spellId and Elvin_Cooldowns[spellId]))
  end
end)


addon.Logs = mod
