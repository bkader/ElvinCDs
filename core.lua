local addonName, addon = ...
local utils = addon.utils
local L = addon.L
local classSpells = addon.spells
_G.ElvinCDs = addon

-- SavedVariables:
Elvin_Options = {}
Elvin_Spells = {}
Elvin_Cooldowns = {}

local unitName, unitRank

-- AddOn's Event Frame:
local fname = 'ElvinCDs_EventFrame'
local mainFrame = CreateFrame('Frame', fname)
local updateInterval = 0.5
mainFrame:RegisterEvent('ADDON_LOADED')

local options
local updateRoster, groupType = false
local members, composition = {}, {}
local cooldowns, cooldownsNames

local spellInfo = {}
local tracked, announced, whispered = {}, {}, {}


local currentTime, onUpdateBar, onClickBar
local loaded, fetched = false, false, false
local windows = {}

-- Table of tracked food!
local food = {
  [GetSpellInfo(57426)]=57426, -- Cooking: Fish Feast
  [GetSpellInfo(58465)]=58465, -- Cooking: Gigantic Feast
  [GetSpellInfo(58659)]=58659, -- Mages: Ritual of Refreshment
  [GetSpellInfo(58887)]=58887, -- Warlock: Ritual of Souls
}

local syncHandlers, whisperSyncHandlers = {}, {}

local function removeWindows()
  for name, _ in pairs(windows) do
    utils.hide(_G[name])
  end
end

local function initializeCooldowns()
  removeWindows()
  -- We add spells info:
  if options.default then
    for _, spells in pairs(classSpells) do
      for k, v in pairs(spells) do
        spellInfo[k] = v
      end
    end
  else
    spellInfo = table.wipe(spellInfo or {})
  end
  for k, v in pairs(Elvin_Spells) do
    spellInfo[k] = spellInfo[k] or {}
    spellInfo[k] = table.merge(spellInfo[k], v)
  end
  addon.spellInfo = spellInfo

  -- Add the list of spells to track and/or announce
  tracked = table.wipe(tracked or {})
  announced = table.wipe(announced or {})
  whispered = table.wipe(whispered or {})
  for k, v in pairs(spellInfo) do
    local spellName = select(1, GetSpellInfo(k))
    if v.track then tracked[spellName] = k end
    if v.shout then announced[spellName] = k end
    if v.whisper then whispered[spellName] = k end
  end

  -- Prepare our cooldowns table:
  cooldowns, cooldownsNames = Elvin_Cooldowns, {}
  for k, _ in pairs(cooldowns) do
    local name = select(1, GetSpellInfo(k))
    if name then cooldownsNames[name] = k end
  end

  updateRoster = true
end

local function addSpellCooldown(spellId)
  if not cooldowns[spellId] then
    cooldowns[spellId] = {players = {}}
  end
end

local function addPlayerCooldown(name, class, talent)
  if not name or not class then return end
  local spells = classSpells[class]
  if spells and cooldowns then
    for k, v in pairs(spells) do
      local spellName = select(1, GetSpellInfo(k))
      if spellName and tracked[spellName] then
        if ((talent and v.talent) or (not talent and not v.talent)) then
          if v.track then
            addSpellCooldown(k)
            if not cooldowns[k].players[name] then
              cooldowns[k].players[name] = {castTime = 0, logs = {}}
            end
          else
            cooldowns[k] = nil -- Remove it if not tracked anymore.
          end
        end
      end
    end
  end
end

local function removePlayerCooldown(name)
  if cooldowns then
    for k, v in pairs(cooldowns) do
      v.players[name] = nil
      utils.hide(_G['ElvinCDs_'..tostring(k)..'_'..name])
    end
  end
end

local function checkGroupStatus()
  if UnitAffectingCombat('player') then
    updateRoster = true
    return
  end

  utils.triggerEvent('UpdateBars')

  groupType = utils.getGroupType()

  -- In case of a raid:
  if groupType == 'RAID' then
    local num, size = GetRealNumRaidMembers(), GetRaidDifficulty()
    size = (size % 2 == 0) and 25 or 10

    for i = 1, num do
      local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
      composition[subgroup] = composition[subgroup] or {}
      if name then
        addPlayerCooldown(name, class)
        table.insertUnique(members, name)
        composition[subgroup][name] = {name = name, class = class}
      end
    end

    if options.strict then
      for i = 1, num do
        local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
        if name and ((size == 25 and subgroup > 5) or (size == 10 and subgroup > 2)) then
          removePlayerCooldown(name)
          utils.removeEntry(members, name)
          if composition[subgroup] then composition[subgroup] = nil end
        end
      end
    end

  -- Battleground
  elseif groupType == 'BATTLEGROUND' then
    local i, num = 1, GetNumRaidMembers()
    for i = 1, num do
      local name, _, _, _, _, class = GetRaidRosterInfo(i)
      if name then
        addPlayerCooldown(name, class)
        table.insertUnique(members, name)
      end
    end

  -- Party:
  elseif groupType == 'PARTY' then
    local i, num = 1, GetNumPartyMembers()
    for i = 1, num do
      local unitId = 'party'..tostring(i)
      local name = UnitName(unitId)
      local _, class = UnitClass(unitId)
      if UnitIsConnected(unitId) then
        addPlayerCooldown(name, class)
        table.insertUnique(members, name)
      end
    end

  -- Solo:
  elseif groupType == 'SOLO' then
    local _, class = UnitClass('player')
    addPlayerCooldown(unitName, class)
  end

  updateRoster = false
end

local function createWindow(spellId, wName)
  if not spellId or not cooldowns[spellId] then return end

  local spell = spellInfo[spellId]
  if not spell then return end

  local cooldown = cooldowns[spellId]

  local spellName, _, spellIcon = GetSpellInfo(spellId)

  wName = wName or 'ElvinCDs_'..tostring(spellId)
  local window = utils.deepCopy(spell)
  window.name = wName
  window.spellId = spellId

  -- Create window frame:
  local wFrame = window.frame
  if not wFrame then
    wFrame = _G[wName] or CreateFrame('Frame', wName, UIParent, 'ElvinCDs_WindowTemplate')
    window.frame = wFrame
  end

  -- Window position & size:
  local xOfs, yOfs = cooldown.xOffset, cooldown.yOffset
  if xOfs and yOfs then
    wFrame:ClearAllPoints()
    wFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', xOfs or 0, yOfs or 0)
  end
  wFrame:SetWidth(options.width or 150)

  -- Set window icon:
  local icon = _G[wName..'Icon']
  icon:SetTexture(spellIcon)
  icon:SetSize(options.height, options.height)
  utils.showHide(icon, options.icons)

  -- Set window title & assign actions:
  local title = _G[wName..'Title']
  title:SetText(spellName)
  title:SetHeight(options.height)
  _G[wName..'TitleText']:SetFont('Fonts\\ARIALN.ttf', options.height*0.55)
  title:SetPoint('TOPLEFT', wFrame, 'TOPLEFT', 0, 0)
  if options.icons then
    title:SetPoint('RIGHT', icon, 'LEFT', 0, 0)
  else
    title:SetPoint('RIGHT', wFrame, 'RIGHT', 0, 0)
  end
  title:SetScript('OnMouseDown', function(self, button)
    wFrame.mouseDown = true
    if button == 'LeftButton' then
      if not options.locked and not cooldown.locked then
        wFrame:StartMoving()
      end
    end
  end)
  title:SetScript('OnMouseUp', function(self, button)
    wFrame.mouseDown = false
    if button == 'LeftButton' then
      local _, _, _, xOfs, yOfs=wFrame:GetPoint()
      cooldown.xOffset=xOfs
      cooldown.yOffset=yOfs
      wFrame:StopMovingOrSizing()
    end
  end)
  title:SetScript('OnClick', function(self, button)
    -- Ignore if we are moving the wFrame
    if wFrame.mouseDown then
      return
    -- Middle Click Locking:
    elseif button == 'MiddleButton' then
      local status, msg
      options.locked = not options.locked
      if options.locked then
        utils.print(L['Windows |cff00ff00locked|r'])
      else
        utils.print(L['Windows |cffff0000unlocked|r'])
      end
      loaded, fetched = false, false

    -- RightButton hide function:
    elseif button == 'RightButton' then
      if StaticPopup_Show('ELVINCDS_CONFIRM_HIDE') then
        selectedWindow = name
      end
    elseif button == 'LeftButton' and IsAltKeyDown() then
      if addon.Logs then addon.Logs:view(spellId) end
    end
  end)

  utils.setTooltip(title, {
    L['Left-click to move (in unlocked)'],
    L['Middle-Click to lock/unlock windows'],
    L['Right-Click to hide window'],
    L['Alt+Left-click to access spell log']
  }, nil, L['Tips'])

  window.bars = {}
  for n, p in pairs(cooldown.players) do
    local unitId = utils.getPlayerUnitId(n)
    if unitId ~= 'none' and UnitIsConnected(unitId) then
      local bName = wName..'_'..n
      local bar = {
        name     = bName,
        castTime = p.castTime,
        player   = n,
        target   = p.target
      }
      table.insert(window.bars, {
        name     = bName,
        castTime = p.castTime,
        player   = n,
        target   = p.target
      })
    end
  end

  return #window.bars > 0 and window or nil
end

local function loadCooldowns()
  removeWindows()
  windows = {}
  -- Hidden by user:
  if (groupType == 'BATTLEGROUND' and not options.showInBG)
    or (groupType == 'RAID' and not options.showInRaid)
    or (groupType == 'PARTY' and not options.showInParty)
    or (groupType == 'SOLO' and not options.showWhenSolo) then
    loaded, fetched = true, false
    return
  end

  for k, v in pairs(cooldowns) do
    local wName = 'ElvinCDs_'..tostring(k)
    local window = windows[wName] or createWindow(k, 'ElvinCDs_'..tostring(k))
    if window then
      windows[wName] = window
      utils.showHide(window.frame, (not window.hidden and #window.bars > 0))
    end
  end
  loaded, fetched = true, false
end

local function fetchCooldowns()

  for n, w in pairs(windows) do
    -- Create the window if it doesn't exist!
    local window = w.frame
    if window then
      local bars = #w.bars
      if bars > 0 then
        local height = 0

        local anchor = _G[n..'Bars']

        for k, b in ipairs(w.bars) do
          local bar = _G[b.name]
          if not bar then
            bar = CreateFrame('StatusBar', b.name, window, 'ElvinCDs_BarTemplate')
          end
          bar:SetID(k)
          utils.showHide(bar, not b.hidden)
          bar:SetMinMaxValues(0, w.cooldown)

          bar:SetPoint('TOPLEFT', anchor, 'TOPLEFT', 0, -height)
          bar:SetPoint('RIGHT', anchor, 'RIGHT', 0, 0)
          bar:SetHeight(options.height)

          local name, timer = _G[b.name..'Name'], _G[b.name..'Timer']

          name:SetFont('Fonts\\ARIALN.ttf', options.height*0.7)
          timer:SetFont('Fonts\\ARIALN.ttf', options.height*0.6)
          name:SetTextColor(1.0, 1.0, 1.0, options.opacity*1.5)
          timer:SetTextColor(1.0, 1.0, 1.0, options.opacity*1.5)
          _G[b.name..'Icon']:SetSize(options.height*0.67, options.height*0.67)

          -- Add the update function:
          bar:SetScript('OnUpdate', function(self, elapsed)
            onUpdateBar(w.spellId, b.player, elapsed)
          end)
          bar:SetScript('OnMouseUp', function(self, button)
            onClickBar(b, w.spellId)
          end)
          height = height + bar:GetHeight()
          if k > 0 and k < bars then height = height + options.spacing end
        end

        -- Change window height:
        window:SetHeight(height + options.height)
      end
    end
  end

  fetched = true
end

function onUpdateBar(spellId, player, elapsed)
  -- We make sure the spell is tracked and the player is provided!
  if not spellId or not cooldowns[spellId] or not player then return end

  local spell = cooldowns[spellId].players[player]
  local info  = spellInfo[spellId]
  if not spell or not info then return end

  -- Check the player first:
  local unitId = utils.getPlayerUnitId(player)
  if unitId == 'none' then return end

  -- Make sure the bar exists!
  local barName = 'ElvinCDs_'..tostring(spellId)..'_'..player
  local bar = _G[barName]
  if not bar then return end

  -- Name & Timer :
  local name, timer = _G[barName..'Name'], _G[barName..'Timer']
  local timeDiff = currentTime - (spell.castTime or 0)
  local timeTick = info.cooldown - timeDiff
  if timeTick < 0 then timeTick = 0 end

  -- Is the player dead?
  local isDead = UnitIsDeadOrGhost(unitId)
  local r, g, b
  if isDead then r, g, b = 0.12, 0.12, 0.12 end

  local icon = GetRaidTargetIndex(unitId)
  if icon and not isDead then
    _G[barName..'Icon']:SetTexture('Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_'..icon)
    _G[barName..'Icon']:Show()
  else
    _G[barName..'Icon']:SetTexture('Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8')
    utils.showHide(_G[barName..'Icon'], isDead)
  end

  if utils.update(bar, barName, 1, elapsed) then

    -- Bar Color & Timer:
    if timeTick == 0 then
      bar.ticking = false
      spell.castTime = 0
      spell.target = nil
      _G[barName]:SetValue(info.cooldown)
      timer:SetText(L['Ready'])
      _G[barName]:SetStatusBarColor(r or 0.0, g or 1.0, b or 0.0, options.opacity)
    else
      bar.ticking = true
      _G[barName]:SetValue(timeDiff)
      timer:SetText(utils.sec2clock(timeTick))
      _G[barName]:SetStatusBarColor(r or 1.0, g or 0.0, b or 0.0, options.opacity)
    end

    -- Bar Text:
    if not spell.target
      or spell.target == ''
      or spell.target == player then
      name:SetText(player)
    else
      name:SetText(format('%s (%s)', player, spell.target or RAID))
    end
  end
end

do
  local menuFrame

  local function openMenu(self, spellId, group)
    -- Make sure we have a bar & a spell id;
    if not self or not spellId then return end

    -- Validate the spell:
    local spellName = GetSpellLink(spellId) or GetSpellInfo(spellId)
    if not spellName then return end

    local bar = _G[self.name]
    if not bar then return end

    -- Create the menu frame:
    if not menuFrame then
      menuFrame = CreateFrame('Frame', 'ElvinCDs_CooldownMenu', UIParent, 'UIDropDownMenuTemplate')
    end

    -- Holds all menu elements:
    local menuItems = {}

    -- Insert first menu element:
    table.insert(menuItems, {
      text = group and L['Use Now'] or L['Use on Me'],
      notCheckable = true,
      func = function()
        if group then
          addon:shout(L:F('%s use %s now!', self.player, spellName))
          addon:whisper(self.player, L:F('Please use %s now', spellName))
        else
          addon:shout(L:F('%s use %s on me!', self.player, spellName))
          addon:whisper(self.player, L:F('Please use %s on me', spellName))
        end
      end
    })

    if not group and utils.tableLen(composition) > 0 then
      for g, ps in pairs(composition) do
        local item = {
          text = GROUP..' '..g,
          notCheckable = true,
          hasArrow = true,
          menuList = {}
        }

        for k, v in pairs(ps) do
          local hex = utils.classColorHex(v.class)
          table.insert(item.menuList, {
            text = '|cff'..hex..v.name..'|r',
            notCheckable = true,
            func = function()
              if v.name == unitName then
                addon:shout(L:F('%s use %s on me!', self.player, spellName))
                addon:whisper(self.player, L:F('Please use %s on me', spellName))
              else
                addon:shout(L:F('%s use %s on %s!', self.player, spellName, v.name))
                addon:whisper(self.player, L:F('Please use %s on %s', spellName, v.name))
              end
            end
          })
        end
        table.insert(menuItems, item)
      end
    end

    EasyMenu(menuItems, menuFrame, 'cursor', 0, 0, 'MENU')
  end

  function onClickBar(self, spellId)
    if not self or not spellId then return end
    local cooldown = cooldowns[spellId]
    if not cooldown then return end

    local spell = spellInfo[spellId]
    if not spell then return end

    -- Make sure the bar isn't on cooldown:
    if _G[self.name].ticking then return end

    -- Stop if it's my own:
    if self.player == unitName then return end

    -- Make sure the player is alive
    local isDead
    local unitId = utils.getPlayerUnitId(self.player)
    if unitId ~= 'none' and UnitIsDeadOrGhost(unitId) then
      isDead = true
    end
    if isDead then return end


    if IsControlKeyDown() then
      local spellName = GetSpellLink(spellId) or GetSpellInfo(spellId)
      if spell.blind then
        addon:shout(L:F('%s use %s now!', self.player, spellName))
        addon:whisper(self.player, L:F('Please use %s now', spellName))
      else
        addon:shout(L:F('%s use %s on me!', self.player, spellName))
        addon:whisper(self.player, L:F('Please use %s on me', spellName))
      end
    else
      openMenu(self, spellId, spell.blind)
    end
  end
end

local function startCooldownTimer(player, target, spellId)
  if player and spellId and cooldowns[spellId] then
    cooldowns[spellId].players[player] = cooldowns[spellId].players[player] or {}
    local cd = cooldowns[spellId].players[player]
    cd.castTime = (currentTime - 1) -- simple delay
    if target then cd.target = (player ~= target) and target or nil end
    cd.logs = cd.logs or {}
    cd.logs[currentTime] = target or ''
    addon:unload()
    if addon.Logs then addon.Logs:reset() end
    addon:sync('cooldown\t'..player..'\t'..tostring(target)..'\t'..tostring(spellId))
  end
end

local function combatLogUnfiltered(event, player, target, spellId, spellName)

  if not player or not utils.checkEntry(members, player) then return end

  -- On cast success:
  if event == 'SPELL_CAST_SUCCESS' then
    if not cooldowns[spellName] and tracked[spellName] then
      local spellId = tracked[spellName]
      addSpellCooldown(tracked[spellName])
      startCooldownTimer(player, target, tracked[spellName])
      loaded = false
    end
    if cooldownsNames[spellName] then
      spellId = spellId or cooldownsNames[spellName]
      startCooldownTimer(player, target, spellId)
      local spellLink = GetSpellLink(spellId) or (GetSpellLink(spellName) or spellName)
      if player ~= target and target == unitName then
        addon:print(L:F('%s casted %s on you', player, spellLink))
      end
    end

  -- Resurrection:
  elseif event == 'SPELL_RESURRECT' then
    if cooldownsNames[spellName] then
      spellId = spellId or cooldownsNames[spellName]
      startCooldownTimer(player, target, spellId)
      local spellLink = GetSpellLink(spellId) or (GetSpellLink(spellName) or spellName)
      if player ~= target and target == unitName then
        addon:print(L:F('%s resurrected you using %s', player, spellLink))
      end
    end

  -- Putting down fish:
  elseif event == 'SPELL_CREATE' then
    -- Start the cooldown:
    if cooldowns[spellName] then
      spellId = spellId or cooldowns[spellId]
      startCooldownTimer(player, target, spellId)
    end

    -- Prepare message to send/print:
    local msg, msgSelf = '%s is down, enjoy!', '%s has put down %s'
    local spellLink = GetSpellLink(spellId) or (GetSpellLink(spellName) or spellName)
    if spellId == 58659 or spellId == 58887 then
      msg = 'Casting %s, please click!'
      msgSelf = '%s is casting %s, please click!'
    end
    if player == unitName then
      addon:shout(L:F(msg, spellLink), 'RAID')
    else
      addon:print(L:F(msgSelf, player, spellLink))
    end
  end

end

------------------------------------------------------------------

do
  -- AddOn defaultOptions:
  local defaultOptions = addon.defaultOptions
  if not defaultOptions then
    defaultOptions = {
      enabled=true,
      config=true,
      strict=true,
      icons=true,
      sync=true,
      shout=true,
      announce=true,
      whisper=true,
      verbose=true,
      locked=false,
      scale=1,
      showInBG=false,
      showInRaid=true,
      showInParty=true,
      showWhenSolo=false,
      clickable=true,
      opacity=0.65,
      width=150,
      height=18,
      spacing=0,
      default=true
    }
    addon.defaultOptions = defaultOptions
  end

  -- Loads addon's default options:
  function addon:defaults()
    for k, v in pairs(defaultOptions) do
      if k ~= 'default' then -- Ignore default spells!
        Elvin_Options[k] = v
      end
    end
  end

  -- Loads addons's options on entering world:
  local function loadOptions()
    options = Elvin_Options
    utils.fillTable(options, defaultOptions)
    addon.options = options
  end

  -- Table of events doing the same thing:
  local compactEvents = {
    'PLAYER_ENTERING_BATTLEGROUND',
    'RAID_ROSTER_UPDATE',
    'PARTY_MEMBERS_CHANGED',
    'PLAYER_DIFFICULTY_CHANGED'
  }

  -- Main frame event handler:
  local function eventHandler(self, event, ...)
    ---------------------------
    -- On ADDON_LOADED event --
    ---------------------------
    if event == 'ADDON_LOADED' then
      local name = ...
      if name == addonName then
        -- Unregister the event and load options:
        self:UnregisterEvent('ADDON_LOADED')
        loadOptions()

        -- Proceed only if the addon is enabled:
        if options.enabled then
          self:RegisterEvent('PLAYER_ENTERING_WORLD')
          self:RegisterEvent('PLAYER_ENTERING_BATTLEGROUND')
          self:RegisterEvent('RAID_ROSTER_UPDATE')
          self:RegisterEvent('PARTY_MEMBERS_CHANGED')
          self:RegisterEvent('PLAYER_DIFFICULTY_CHANGED')
          self:RegisterEvent('UNIT_SPELLCAST_SENT')
          self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
          self:RegisterEvent('CHAT_MSG_ADDON')

          -- Register events we need:
          utils.print(L['AddOn Loaded!'])
        end

      end
      return
    end

    if event == 'PLAYER_ENTERING_WORLD' then
      self:UnregisterEvent('PLAYER_ENTERING_WORLD')
      initializeCooldowns()
      return
    end

    if utils.checkEntry(compactEvents, event) then
      updateRoster = true
      return
    end

    if event == 'UNIT_SPELLCAST_SENT' then
      local unitId, spellName, rank, target = ...
      local player = UnitName(unitId)

      -- Get & Validate spell Id:&
      local spellId = whispered[spellName] or (announced[spellName] or tracked[spellName])
      if not spellId and cooldownsNames then
        spellId = cooldownsNames[spellName]
      end
      if not spellId then return end
      local spell = spellInfo[spellId]
      if not spell then return end

      -- Prepare the spell link:
      local spellLink = GetSpellLink(spellName, rank) or spellName
      if not target then return end

      -- Is the spell to be announced?
      if announced[spellName] then
        if spell.blind or (target ~= '' and target == player) then
          addon:shout(L:F('Casting %s', spellLink), 'RAID')
        else
          addon:shout(L:F('Casting %s on %s', spellLink, target), 'RAID')
        end
      end

      -- Whether to whisper the player
      if whispered[spellName] and target ~= player then
        addon:whisper(target, L:F('%s on you', spellLink))
      end

      if cooldowns[spellId] and options.showWhenSolo then
        startCooldownTimer(player, target, spellId)
      end
      return
    end

    if event == 'COMBAT_LOG_EVENT_UNFILTERED' then
      local _, eventName, playerGUID, playerName, _, targetGUID, targetName, _, spellId, spellName = ...
      return combatLogUnfiltered(eventName, playerName, targetName, spellId, spellName)
    end

    if event == 'CHAT_MSG_ADDON' then
      local prefix, msg, channel, sender = ...
      -- Ignore if wrong prefix, no message or sender is me!
      if prefix == 'ElvinCDs' and msg and sender ~= unitName then
        local handler
        if channel ~= 'WHISPER' and channel ~= 'GUILD' then
          handler = syncHandlers[prefix]
        elseif channel == 'WHISPER' and utils.getPlayerUnitId(sender) ~= 'none' then
          handler = whisperSyncHandlers[prefix]
        end

        if handler and type(handler) == 'function' then
          handler(msg, channel, sender)
        end
      end
      return
    end
  end

  mainFrame:SetScript('OnEvent', eventHandler)
end

------------------------------------------------------------------

mainFrame:SetScript('OnUpdate', function(self, elapsed)
  -- In case the addon is disabled
  if not options.enabled then return end
  currentTime = time()

  if not unitName then
    unitName = select(1, UnitName('player'))
    addon.unitName = unitName
  end

  -- Update the frame:
  if utils.update(self, fname, updateInterval, elapsed) then
    -- utils.print(currentTime, time())
    unitRank = utils.getPlayerRank()

    -- Check if the roster needs to be updated!
    if updateRoster then checkGroupStatus() end

    -- Load & Fetch
    if not loaded then loadCooldowns() end
    if not fetched then
      fetchCooldowns()
      updateInterval = 0.5
    end
  end

  utils.run()
end)


function addon:unload()
  loaded = false
end

function addon:unfetch(force)
  if force then loaded = false end
  fetched = true
end


function addon:sync(msg, channel, target)
  if options.sync then
    utils.sync('ElvinCDs', msg, channel, target)
  end
end

function addon:print(msg)
  if options.verbose and msg then
    utils.announceSelf(msg)
  end
end

function addon:whisper(target, msg)
  if options.whisper then
    local unitId = utils.getPlayerUnitId(target)
    if unitId == 'none' then return end
    if unitId ~= 'player' and UnitIsConnected(unitId) and not UnitIsDeadOrGhost(unitId) then
      utils.whisper(target, msg)
    end
  end
end

function addon:shout(msg, channel)
  if options.shout and msg then
    utils.announce(msg, channel)
  end
end


do
  local function syncHandler(msg, channel, sender)
    if not msg then return end
    local command, other = strsplit('\t', msg, 2)

    -- TODO: Fix it!
    if command == 'cooldown' then
      local player, target, spellId = strsplit('\t', other, 3)
      if player and spellId then
        spellId = tonumber(spellId)
        addSpellCooldown(spellId)
        cooldowns[spellId].players[player] = cooldowns[spellId].players[player] or {}
        local cd = cooldowns[spellId].players[player]
        if cd.castTime == 0 then
          cd.castTime = currentTime
          if target then cd.target = (player ~= target) and target or nil end
          cd.logs = cd.logs or {}
          cd.logs[currentTime] = target or ''
          addon:unfetch(true)
        end
      end
    end
  end

  syncHandlers['ElvinCDs'] = syncHandler
end



--------------------------------------------------------------------------------
--> Slash Command Handler:
do
  local match = _G.string.match

  local function handleSlashCmd(msg, editBox)
    local helpString = '|cffffd700%s|r: %s'

    local command, rest = match(msg, "^(%S*)%s*(.-)$")

    -- Enable/Disable
    if command == 'enable' or command == 'on' then
      if not options.enabled then
        options.enabled = true
        ReloadUI()
      end
    elseif command == 'disable' or command == 'off' then
      options.enabled = false
    elseif command == 'icon' or command == 'icons' then
      options.icons = not options.icons
      local status = options.icons and '|cff00ff00ON|r' or '|cffff0000OFF|r'
      utils.print(L['Show Spells Icons'], status)
      utils.triggerEvent('ResetBars')
    elseif command == 'strict' then
      options.strict = not options.strict
      local status = options.strict and '|cff00ff00ON|r' or '|cffff0000OFF|r'
      utils.print(L['Strict Mode'], status)
    elseif command == 'raid' or command == 'rw' then
      local status = options.announce and '|cff00ff00ON|r' or '|cffff0000OFF|r'
      options.announce = not options.announce
      utils.print(L['Use Raid Chat/warnings'], status)
    elseif command == 'shout' or command == 'announce' then
      options.shout = not options.shout
      local status = options.shout and '|cff00ff00ON|r' or '|cffff0000OFF|r'
      utils.print(L['Announce Spell Casting'], status)
    elseif command == 'verbose' or command == 'notify' then
      options.verbose = not options.verbose
      local status = options.verbose and '|cff00ff00ON|r' or '|cffff0000OFF|r'
      utils.print(L['Display Notifications'], status)
    elseif command == 'lock' then
      options.locked = not options.locked
      local status = options.locked and '|cff00ff00ON|r' or '|cffff0000OFF|r'
      utils.print(L['Lock Windows'], status)
    elseif command == 'sync' then
      options.sync = not options.sync
      local status = options.sync and '|cff00ff00ON|r' or '|cffff0000OFF|r'
      utils.print(L['AddOn Synchronization'], status)
    elseif command == 'reset' then
      local cmd, other = match(rest, "^(%S*)%s*(.-)$")
      local passed, msg = false
      if cmd == 'all' then
        Elvin_Cooldowns = table.wipe(Elvin_Cooldowns or {})
        passed = true
        msg = L['Cooldowns successfully reset']
      elseif cmd == 'log' or cmd == 'logs' then
        for k, v in pairs(Elvin_Cooldowns) do
          for n, p in pairs(v.players) do
            p.logs = table.wipe(p.logs or {})
          end
        end
        passed = true
        msg = L['Cooldowns logs successfully reset']
      end
      if passed then utils.triggerEvent('UpdateBars') end
      if msg then utils.print(msg) end
    elseif command == 'help' then
      utils.print(L:F('Acceptable commands for |cff33ff99/elvin|r:'))
      print(L:F(helpString, 'enable', L['Enables cooldown tracking']))
      print(L:F(helpString, 'disable', L['Disables cooldown tracking']))
      print(L:F(helpString, 'icons', L['Shows/Hide spells icons']))
      print(L:F(helpString, 'strict', L['Enables/Disables strict mode']))
      print(L:F(helpString, 'raid', L['Enables/Disables messages to raid chat or raid warnings']))
      print(L:F(helpString, 'shout', L['Enables/Disables spell casting announcements']))
      print(L:F(helpString, 'verbose', L['Enables/Disables on-screen and chat window alerts']))
      print(L:F(helpString, 'lock', L['Locks/Unlocks spells windows']))
      print(L:F(helpString, 'reset all', L['Resets all spells cooldowns']))
      print(L:F(helpString, 'reset logs', L['Resets all spells logs']))
      print(L:F(helpString, 'sync', L['Enables/Disabled addon synchronization']))
    elseif command == 'config' or command == 'options' or command == '' then
      addon.Config:toggle()
    end

  end

  SLASH_ECD1, SLASH_ECD2, SLASH_ECD3 = '/elvincds', '/ecd', '/elvin'
  SlashCmdList['ECD'] = handleSlashCmd
end

utils.registerCallback('UpdateBars', function()
  initializeCooldowns()
  loaded = false
end)

utils.registerCallback('ResetBars', function()
  updateInterval = 0.05
  loaded = false
end)
