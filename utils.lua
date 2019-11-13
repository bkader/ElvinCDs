local _, addon = ...
local mod = {}




--------------------------------------------------------------------------------
--> Tables:

-- Fills table with another.
function mod.fillTable(t1, t2)
  for i, v in pairs(t2) do
    if t1[i] == nil then
      t1[i] = v
    elseif type(v) == 'table' then
      mod.fillTable(v, t2[i])
    end
  end
end

-- DeepCopy:
function mod.deepCopy(src)
  local res = {}
  for k, v in pairs(src) do
    if type(v) == 'table' then
      res[k] = mod.deepCopy(v)
    else
      res[k] = v
    end
  end
  return res
end

-- Checks if the given entry exists in the table:
function mod.checkEntry(t, e)
  for i, v in ipairs(t) do
    if v == e then
      return true -- At least one
    end
  end
  return false
end

-- Removes all entry occurrences from a table:
function mod.removeEntry(t, e)
  local removed = false
  for i = #t, 1, -1 do
    if t[i] == e then
      tremove(t, i)
      removed = true
    end
  end
  return removed
end

-- Returns the given table's length:
function mod.tableLen(t)
  local length = 0
  for _, _ in pairs(t) do
    length = length + 1
  end
  return length
end

-- Checks if the given table is empty:
function mod.isEmpty(t)
  for _, _ in pairs(t) do
    return false
  end
  return true
end

-- Inserts a unique value to table:
function table.insertUnique(t, val)
  local found
  if type(t) == 'table' then
    for k, v in pairs(t) do
      if val == v then
        found = true
        break
      end
    end
    if not found then
      tinsert(t, val)
    end
  end
  return found
end

--------------------------------------------------------------------------------
--> Strings:

-- Trim a string:
function string.trim(str)
  return gsub(str, '^%s*(.-)%s*$', '%1')
end

--------------------------------------------------------------------------------
--> Frames:

-- Toggle element visibility:
function mod.toggle(f, callback)
  if not f then
    return
  elseif f:IsShown() then
    f:Hide()
  else
    f:Show()
  end
  if callback and type(callback) == 'function' then
    callback()
  end
end

-- Show/Hide frame:
function mod.showHide(f, cond, callback, ...)
  if not f then
    return
  elseif cond and not f:IsShown() then
    f:Show()
  elseif not cond and f:IsShown() then
    f:Hide()
  end
  if callback and type(callback) == 'function' then
    callback(...)
  end
end

-- Shows with callback:
function mod.show(f, callback, ...)
  if f and not f:IsShown() then f:Show() end
  if callback and type(callback) == 'function' then
    callback(...)
  end
end

-- Hide frame:
function mod.hide(f, callback, ...)
  if f and f:IsShown() then f:Hide() end
  if callback and type(callback) == 'function' then
    callback(...)
  end
end

-- Enable/Disable button:
function mod.enableDisable(b, cond)
  if not b then
    return
  elseif cond and b:IsEnabled() == 0 then
    b:Enable()
  elseif not cond and b:IsEnabled() == 1 then
    b:Disable()
  end
end

-- Toggle button highlight status:
function mod.highlight(b, cond)
  if not b then
    return
  elseif cond then
    b:LockHighlight()
  else
    b:UnlockHighlight()
  end
end

-- Change element text:
function mod.setText(f, str1, str2, cond)
  if not f then return end
  if cond then
    f:SetText(str1)
  else
    f:SetText(str2)
  end
end

-- Better frame OnUpdate:
function mod.update(frame, frameName, period, elapsed)
  local t = frameName and frame[frameName] or 0
  t = t + elapsed
  if t > period then
    frame[frameName] = 0
    return true
  end
  frame[frameName] = t
  return false
end

--------------------------------------------------------------------------------
--> Callbacks:
do
  local pcall, error = _G.pcall, _G.error

  -- Tables of registered callbacks:
  local callbacks = {}

  -- Register a callback function:
  function mod.registerCallback(e, func)
    if e and type(func) == 'function' then
      callbacks[e] = callbacks[e] or {}
      tinsert(callbacks[e], func)
      return #callbacks
    end
    error('Usage: mod.registerCallback(action, callback)', 2)
  end

  -- Executes a previously register action.
  function mod.triggerEvent(e, ...)
    if callbacks[e] then
      for i, v in ipairs(callbacks[e]) do
        local ok, err = pcall(v, a, ...)
        if not ok then
          mod.print(format('Error while executing callback %s for event %s: %s', tostring(v), tostring(a), err))
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
--> Task Manager:
do
  -- Table of scheduled tasks:
  local tasks = {}

  -- Schedule a task:
  function mod.schedule(sec, func, ...)
    local task = {}
    task.time = time() + sec
    task.func = func
    task.args = {}
    for i = 1, select('#', ...) do
      task.args[i] = select(i, ...)
    end
    -- tasks[#tasks+1] = task
    tinsert(tasks, task)
  end

  -- Reschedule a task:
  function mod.reschedule(func, sec)
    for i = 1, #tasks do
      if tasks[i].func == func then
        tasks[i].time = tasks[i].time + sec
        break
      end
    end
  end

  -- Unschedule a task:
  function mod.unschedule(func)
    for i, v in pairs(tasks) do
      if func == v.func then
        tremove(tasks, i)
        break
      end
    end
  end

  -- Run all scheduled tasks:
  function mod.run()
    local now = time()
    for i = 1, #tasks do
      local task = tasks[i]
      if task and type(task.func) == 'function' and task.time <= now then
        task.func(unpack(task.args, 0))
        tremove(tasks, i) -- Only once!
      end
    end
  end
end
--------------------------------------------------------------------------------
--> Date & Time:
do
  local GetGameTime = _G.GetGameTime
  local match = _G.string.match
  local floor = _G.math.floor
  local time, date = _G.time, _G.date

  -- Convert seconds to readable clock string:
  function mod.sec2clock(sec)
    local sec = tonumber(sec)
    if sec <= 0 then
      return '00:00:00'
    end
    local hours, mins, secs
    hours = format('%02.f', floor(sec / 3600))
    mins  = format('%02.f', floor(sec / 60 - (hours * 60)))
    secs  = format('%02.f', floor(sec - hours * 3600 - mins * 60))
    local out = secs
    if mins ~= '00' then
      out = mins..':'..out
    end
    if hours ~= '00' then
      out = hours..':'..mins..':'..out
    end
    return out
  end

  -- Returns the server offset:
  function mod.getServerOffset()
    local sH, sM = GetGameTime()
    local lH, lM = tonumber(date('%H')), tonumber(date('%M'))
    local sT = sH + sM / 60
    local lT = lH + lM / 60
    local offset = floor((sT - lT) * 2 + 0.5) / 2
    if offset >= 12 then
      offset = offset - 24
    elseif offset < -12 then
      offset = offset + 24
    end
    return offset
  end

  -- Returns the current time:
  function mod.getCurrentTime(server)
    server = (server == false) and false or true
    local t = time()
    if server == true then
      local t2, sOffset = date('*t'), mod.getServerOffset()
      local hour, minute = GetGameTime()
      t = time({year = t2.year, month = t2.month, day = t2.day, hour = hour, min = minute, sec = t2.sec})
      -- Add server offset
      t = t + (sOffset * 3600)
    end
    return mod.applyFilter and mod.applyFilter('CurrentTime', t) or t
  end

  -- Returns formatted datetime:
  function mod.getDate(sec, pattern)
    sec = sec or mod.getCurrentTime()
    pattern = pattern or '%Y/%m/%d %H:%M:%S'
    return date(pattern, sec)
  end
end

--------------------------------------------------------------------------------
--> Raid:
do
  local GetRealNumPartyMembers = _G.GetRealNumPartyMembers
  local GetRealNumRaidMembers = _G.GetRealNumRaidMembers
  local GetNumRaidMembers = _G.GetNumRaidMembers
  local UnitInBattleground = _G.UnitInBattleground

  -- Returns the current group type
  function mod.getGroupType()
    if UnitInBattleground('player') then
      return 'BATTLEGROUND'
    elseif GetRealNumRaidMembers() > 0 then
      return 'RAID'
    elseif GetNumRaidMembers() > 0 then
      return 'BATTLEGROUND'
    elseif GetRealNumPartyMembers() > 0 then
      return 'PARTY'
    else
      return 'SOLO'
    end
  end
end

--------------------------------------------------------------------------------
--> Units:
do
  local GetNumPartyMembers = _G.GetNumPartyMembers
  local GetNumRaidMembers = _G.GetNumRaidMembers
  local GetRaidRosterInfo = _G.GetRaidRosterInfo
  local UnitName, UnitGUID = _G.UnitName, _G.UnitGUID

  -- Checks if the player is in a party group:
  -- Checks if the player is in a party group:
  function mod.isInParty()
    return (GetNumPartyMembers() > 0)
  end

  -- Checks if the player is in a party group:
  function mod.isInRaid()
    return (GetNumRaidMembers() > 0)
  end

  -- Returns true if the selected player is in the raid
  function mod.playerInRaid(name)
    local numRaid = GetNumRaidMembers()
    for i = 1, numRaid do
      local n = GetRaidRosterInfo(i)
      if n == name then
        return true
      end
    end
    return false
  end

  -- Returns the player's UnitID
  function mod.getPlayerUnitId(playerName)
    playerName = playerName or UnitName('player')
    local unitId = 'none'
    local uId = mod.isInRaid() and 'raid' or 'party'
    local count = math.max(GetNumRaidMembers(), GetNumPartyMembers())
    for i = 0, count do
      local id = (i == 0 and 'player') or uId..i
      if playerName == UnitName(id) then
        unitId = id
        break
      end
    end
    return unitId
  end

  -- Retrieves the selected player rank
  function mod.getPlayerRank(playerName)
    local playerRank = 0
    if not mod.isInRaid() then return playerRank end
    playerName = playerName or UnitName('player')
    local numRaid = GetNumRaidMembers()
    for i = 1, numRaid do
      local name, rank = GetRaidRosterInfo(i)
      if name == playerName then
        playerRank = rank
        break
      end
    end
    return playerRank
  end

  -- Returns unitId from GUID
  function mod.GUID2UnitId(guid)
    local prefix, min, max = 'raid', 1, GetNumRaidMembers()
    if max == 0 then
      prefix, min, max = 'party', 0, GetNumPartyMembers()
    end

    for i = min, max do
      local unit = (i == 0) and 'player' or prefix..i
      if UnitGUID(unit) == guid then
        return unit
      end
    end

    if UnitGUID('target') == guid then
      return 'target'
    elseif UnitGUID('focus') == guid then
      return 'focus'
    elseif UnitGUID('mouseover') == guid then
      return mouseover
    end

    for i = min, max + 3 do
      local unit
      if i == 0 then
        unit = 'player'
      elseif i == max + 1 then
        unit = 'target'
      elseif i == max + 2 then
        unit = 'focus'
      elseif i == max + 3 then
        unit = 'mouseover'
      else
        unit = prefix..i
      end
      if UnitGUID(unit..'target') == guid then
        return unit..'target'
      elseif i <= max and UnitGUID(unit..'pettarget') == guid then
        return unit..'pettarget'
      end
    end
    return nil
  end

  do
    -- Cache colors:
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

    -- RGB2Hex Conversion:
    function mod.RGB2HEX(r, g, b)
      return format('%02x%02x%02x', r * 255, g * 255, b * 255)
    end

    -- Returns R, G, B on the given class:
    function mod.classColor(name)
      name = (name == 'DEATH KNIGHT') and 'DEATHKNIGHT' or name
      if not colors[name] then return 1, 1, 1 end
      return colors[name].r, colors[name].g, colors[name].b
    end

    -- Returns HEX class color:
    function mod.classColorHex(name)
      local r, g, b = mod.classColor(name)
      return mod.RGB2HEX(r, g, b)
    end
  end
end

--------------------------------------------------------------------------------
--> AddOn Sync:
do
  local IsInInstance = _G.IsInInstance
  local SendAddonMessage = _G.SendAddonMessage
  local GetRealNumRaidMembers = _G.GetRealNumRaidMembers
  local GetRealNumPartyMembers = _G.GetRealNumPartyMembers

  -- Sends an addOn message to the appropriate channel:
  function mod.sync(prefix, msg, channel, target)
    if not channel then
      local zone = select(2, IsInInstance())
      if zone == 'pvp' or zone == 'arena' then
        channel = 'BATTLEGROUND'
      elseif GetRealNumRaidMembers() > 0 then
        channel = 'RAID'
      elseif GetRealNumPartyMembers() > 0 then
        channel = 'PARTY'
      end
    end
    if channel then SendAddonMessage(prefix, msg, channel, target) end
  end
end

--------------------------------------------------------------------------------
--> Chat Frame:
do
  local CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
  local SendChatMessage = _G.SendChatMessage
  local tconcat = _G.table.concat

  local temp = {}

  local function print_output(frame, ...)
    local n = 1
    if not temp[n] then temp[n] = '|cffff7d0aElvinCDs|r:' end
    for i = 1, select('#', ...) do
      n = n + 1
      temp[n] = tostring(select(i, ...))
    end
    frame:AddMessage(tconcat(temp, ' ', 1, n))
  end

  function mod.print(...)
    local frame = ...
    if type(frame) == 'table' and frame.AddMessage then
      return print_output(frame, select(1, ...))
    else
      return print_output(CHAT_FRAME, ...)
    end
  end

  function mod.printf(...)
    local frame = ...
    if type(frame) == 'table' and frame.AddMessage then
      return print_output(frame, format(select(1, ...)))
    else
      return print_output(CHAT_FRAME, format(...))
    end
  end

  -- Prints a blue info message.
  function mod.printInfo(text)
    text = '|cff2af4e5'..tostring(text)..'|r'
    return mod.print(text)
  end

  -- Prints a green success message.
  function mod.printSuccess(text)
    text = '|cff95dd93'..tostring(text)..'|r'
    return mod.print(text)
  end

  -- Prints an orange warning message.
  function mod.printWarning(text)
    text = '|cffff8a00'..tostring(text)..'|r'
    return mod.print(text)
  end

  -- Prints a red error message.
  function mod.printError(text)
    text = '|cffff3c00'..tostring(text)..'|r'
    return mod.print(text)
  end

  -- Display a message to both chat frame and raid warnings
  -- frame but the player only.
  function mod.announceSelf(text)
    local output = '|cffff7d0aElvinCDs|r: '..tostring(text)
    RaidNotice_AddMessage(RaidWarningFrame, output, {r=1, g=1, b=1})
    CHAT_FRAME:AddMessage(output)
    PlaySoundFile('Sound\\Interface\\KeyRingOpen.wav')
  end

  -- This function automatically announces messages to channels.
  function mod.announce(text, channel)
    if not channel then
      channel = 'SAY'
      if mod.isInParty() then channel = 'PARTY' end
      if mod.isInRaid() then
        channel = 'RAID'
        if mod.getPlayerRank() >= 1 then
          channel = 'RAID_WARNING'
        end
      end
    end
    SendChatMessage(tostring(text), channel)
  end

  local BNIsSelf = _G.BNIsSelf
  local BNSendWhisper = _G.BNSendWhisper

  -- Send a whisper to a player by his/her character name or BNet ID
  -- Returns true if the message was sent, nil otherwise
  function mod.whisper(target, msg)
    if type(target) == 'number' then
      if not BNIsSelf(target) then
        BNSendWhisper(target, msg)
        return true
      end
    elseif type(target) == 'string' then
      SendChatMessage(msg, 'WHISPER', nil, target)
      return true
    end
  end
  local BNSendWhisper = mod.whisper
end

--------------------------------------------------------------------------------
--> Tooltips:
do
  local color = _G.HIGHLIGHT_FONT_COLOR
  local GameTooltip_SetDefaultAnchor = _G.GameTooltip_SetDefaultAnchor

  -- Show the tooltip
  -- @param   obj   the frame data
  local function showTooltip(frame)
    -- Is the anchor manually set?
    if not frame.tooltip_anchor then
      GameTooltip_SetDefaultAnchor(ElvinCDs_Tooltip, frame)
    else
      ElvinCDs_Tooltip:SetOwner(frame, frame.tooltip_anchor)
    end

    ElvinCDs_Tooltip:ClearLines()

    if frame.tooltip_title then
      ElvinCDs_Tooltip:SetText(frame.tooltip_title)
    end

    if frame.tooltip_text then
      if type(frame.tooltip_text) == 'string' then
        ElvinCDs_Tooltip:AddLine(frame.tooltip_text, color.r, color.g, color.b, true)
      elseif type(frame.tooltip_text) == 'table' then
        for _, l in ipairs(frame.tooltip_text) do
          ElvinCDs_Tooltip:AddLine(l, color.r, color.g, color.b, true)
        end
      end
    end

    if frame.tooltip_item then
      ElvinCDs_Tooltip:SetHyperlink(frame.tooltip_item)
    end

    ElvinCDs_Tooltip:Show()
  end

  -- Hides the tooltip:
  local function hideTooltip()
    ElvinCDs_Tooltip:Hide()
  end

  -- Sets frame OnEnter and OnLeave scripts.
  -- @param   frame the frame to attach tooltip to
  -- @param   text  the text to display (string or table)
  -- @param   anchor  where to display the tooltip
  -- @param   title   whether to give the tooltip a title
  function mod.setTooltip(frame, text, anchor, title)
    if frame then
      -- Prepare the text
      frame.tooltip_text = text and text or frame.tooltip_text
      frame.tooltip_anchor = anchor and anchor or frame.tooltip_anchor
      frame.tooltip_title = title and title or frame.tooltip_title
      -- No title or text? nothing to do...
      if frame.tooltip_title or frame.tooltip_text or frame.tooltip_item then
        frame:SetScript('OnEnter', showTooltip)
        frame:SetScript('OnLeave', hideTooltip)
      end
    end
  end

  -- Remove all previously register tooltip script.
  function mod.unsetTooltip(frame)
    if frame then
      frame:SetScript('OnEnter', nil)
      frame:SetScript('OnLeave', nil)
    end
  end
end

addon.utils = mod
