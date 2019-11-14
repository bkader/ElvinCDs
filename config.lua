local _, addon = ...
local utils = addon.utils
local L = addon.L
local GAME_LOCALE = GetLocale()
local mod = {General = {}, Spells = {}}

--------------------------------------------------------------------------------
--> Main Frame:
do
  local UIFrame, frameName
  local localized, btnGeneral, btnSpells

  local function localizeUIFrame()
    if localized then return end
    -- if GAME_LOCALE ~= 'enUS' and GAME_LOCALE ~= 'enGB' then
      _G[frameName..'Tab2']:SetText(L['Manage Spells'])
    -- end
    localized = true
  end

  local function updateUIFrame(self, elapsed)
    localizeUIFrame()
    if utils.update(self, frameName, 0.05, elapsed) then
    end
  end

  function mod:onLoad(frame)
    if not frame then return end
    UIFrame = frame
    frameName = frame:GetName()
    frame:RegisterForDrag('LeftButton')
    tinsert(UISpecialFrames, frameName)
    frame:SetScript('OnUpdate', updateUIFrame)

    -- Tab Configuration:
    PanelTemplates_SetNumTabs(frame, 2)
    PanelTemplates_SetTab(frame, 1)
    frame:SetScript('OnShow', function(self)
      PlaySound('UChatScrollButton')
      _G[frameName..'_General']:Show()
      _G[frameName..'_Spells']:Hide()
    end)
    frame:SetScript('OnHide', function(self)
      PlaySound('UChatScrollButton')
      PanelTemplates_SetTab(frame, 1)
    end)
  end

  function mod:toggle()
    utils.toggle(UIFrame)
  end

  function mod:hide()
    utils.hide(UIFrame)
  end
end

--------------------------------------------------------------------------------
--> General Frame:
do
  local submod = mod.General

  local UIFrame, frameName
  local localized = false

  local sliders = {'opacity', 'width', 'height', 'spacing'}

  local function localizeUIFrame()
    if localized then return end
    -- if GAME_LOCALE ~= 'enUS' and GAME_LOCALE ~= 'enGB' then
      _G[frameName..'_EnabledStr']:SetText(L['Enable AddOn'])
      _G[frameName..'_EnabledHelp']:SetText(L['Whether to enable cooldowns tracking'])

      _G[frameName..'_IconsStr']:SetText(L['Display Icons'])
      _G[frameName..'_IconsHelp']:SetText(L['Whether to display spells icons on windows'])

      _G[frameName..'_StrictStr']:SetText(L['Strict Mode'])
      _G[frameName..'_StrictHelp']:SetText(L['Ignore groups 6-8 or 3-8 depending on the raid difficulty'])

      _G[frameName..'_AnnounceStr']:SetText(L['Use Raid Chat/warnings'])
      _G[frameName..'_AnnounceHelp']:SetText(L['Whether to use raid chat/warnings in addition to whispers'])

      _G[frameName..'_ShoutStr']:SetText(L['Announce Spell Casting'])
      _G[frameName..'_ShoutHelp']:SetText(L['Whether to announced tracked spells to raid/party members'])

      _G[frameName..'_VerboseStr']:SetText(L['Verbose Mode'])
      _G[frameName..'_VerboseHelp']:SetText(L['Enables/Disables on-screen and chat window alerts'])

      _G[frameName..'_LockedStr']:SetText(L['Lock Windows'])
      _G[frameName..'_LockedHelp']:SetText(L['Locks/Unlocks spells windows'])

      _G[frameName..'_SyncStr']:SetText(L['AddOn Synchronization'])
      _G[frameName..'_SyncHelp']:SetText(L['Synchronize with other people using the addon'])

      _G[frameName..'_ShowInBGStr']:SetText(L['Show In Battlegrounds'])
      _G[frameName..'_ShowInBGHelp']:SetText(L['Show when you are in a battleground'])

      _G[frameName..'_ShowInRaidStr']:SetText(L['Show In Raid'])
      _G[frameName..'_ShowInRaidHelp']:SetText(L['Show when you are in a raid'])

      _G[frameName..'_ShowInPartyStr']:SetText(L['Show In Party'])
      _G[frameName..'_ShowInPartyHelp']:SetText(L['Show when you are in a party group'])

      _G[frameName..'_ShowWhenSoloStr']:SetText(L['Show when solo'])
      _G[frameName..'_ShowWhenSoloHelp']:SetText(L['Enable this if you want to use the addon when on your own'])
    -- end
    localized = true
  end

  local function updateUIFrame(self, elapsed)
    localizeUIFrame()
    if utils.update(self, frameName, 0.05, elapsed) then
    for k, v in pairs(Elvin_Options) do
      if _G[frameName..'_'..k] then
        if k == 'height' then
          _G[frameName..'_heightText']:SetText(L:F('Bars Height: %s', addon.options.height))
          _G[frameName..'_height']:SetValue(addon.options.height)
        elseif k == 'width' then
          _G[frameName..'_widthText']:SetText(L:F('Bars Width: %s', addon.options.width))
          _G[frameName..'_width']:SetValue(addon.options.width)
        elseif k == 'opacity' then
          _G[frameName..'_opacityText']:SetText(L:F('Bars Opacity: %s', (addon.options.opacity*100)))
          _G[frameName..'_opacity']:SetValue(addon.options.opacity*100)
        elseif k == 'spacing' then
          _G[frameName..'_spacingText']:SetText(L:F('Bars Spacing: %s', addon.options.spacing))
          _G[frameName..'_spacing']:SetValue(addon.options.spacing)
        else
          _G[frameName..'_'..k]:SetChecked(v)
        end
      end
    end
    end
  end

  function submod:onLoad(frame)
    if not frame then return end
    UIFrame = frame
    frameName = frame:GetName()
    frame:SetScript('OnUpdate', updateUIFrame)
  end

  function submod:onClick(btn)
    if not btn then return end
    if not frameName then frameName = btn:GetParent():GetName() end
    local name = btn:GetName()
    local target = name:gsub(frameName..'_', '')
    if Elvin_Options and Elvin_Options[target] ~= nil then
      local value
      if utils.checkEntry(sliders, target) then
        value = btn:GetValue()
        if target == 'opacity' then value = value / 100 end
      else
        value = (btn:GetChecked() == 1)
      end
      Elvin_Options[target] = value
      utils.triggerEvent(target == 'strict' and 'UpdateBars' or 'ResetBars')
    end
  end
end

--------------------------------------------------------------------------------
--> Spells Frame:
do
  local submod = mod.Spells

  local UIFrame, frameName
  local localized = false

  local spells, cached = {}, {}
  local loaded, fetched = false, false
  local selectedId, sortType
  local searchForm

  local ascending = false
  local sortTypes = {
    id = function(a, b)
      if ascending then return (a.spellId < b.spellId) end
      return (a.spellId > b.spellId)
    end,
    name = function(a, b)
      local aName, bName = GetSpellInfo(a.spellId), GetSpellInfo(b.spellId)
      if not aName then return false end
      if not bName then return true end
      if ascending then return aName < bName end
      return aName > bName
    end,
    cooldown = function(a, b)
      local aCD, bCD = a.cooldown or 0, b.cooldown or 0
      if ascending then return aCD < bCD end
      return aCD > bCD
    end
  }

  local _G = _G
  local GetSpellInfo = _G.GetSpellInfo

  local function localizeUIFrame()
    if localized then return end

    if GAME_LOCALE ~= 'enUS' and GAME_LOCALE ~= 'enGB' then
      _G[frameName..'HeaderSpellId']:SetText(L['Spell ID'])
      _G[frameName..'HeaderSpellName']:SetText(L['Spell Name'])
      _G[frameName..'HeaderCooldown']:SetText(L['Cooldown'])
      _G[frameName..'HeaderDisplay']:SetText(L['Show'])
      _G[frameName..'HeaderTrack']:SetText(L['Track'])
      _G[frameName..'HeaderGroup']:SetText(L['Group'])
      _G[frameName..'HeaderShout']:SetText(L['Shout'])
      _G[frameName..'HeaderWhisper']:SetText(L['Whisper'])
      _G[frameName..'HeaderSpecial']:SetText(L['Special'])
    end

    -- Set Headers Tooltips:
    utils.setTooltip(_G[frameName..'HeaderDisplay'], L['Shows/Hides the spell window'], nil, L['Show Window'])
    utils.setTooltip(_G[frameName..'HeaderTrack'], L['Whether to track the spell'], nil, L['Track Spell'])
    utils.setTooltip(_G[frameName..'HeaderGroup'], L['A blind spell has no specific target.'], nil, L['Group Spell'])
    utils.setTooltip(_G[frameName..'HeaderShout'], L['Announce the spell to group. Only works for spells you cast'], nil, L['Announce Spell'])
    utils.setTooltip(_G[frameName..'HeaderWhisper'], L['Whether to whisper the player you casted the spell on'], nil, L['Send Whisper'])
    utils.setTooltip(_G[frameName..'HeaderSpecial'], L['A special spell is either spec or profession specific'], nil, L['Special Spell'])

    searchForm = _G[frameName..'Search']
    searchForm:SetText(SEARCH)
    searchForm:SetScript('OnEditFocusGained', function(self)
      local text = self:GetText():trim()
      if text == SEARCH then self:SetText('') end
    end)

    searchForm:SetScript('OnEditFocusLost', function(self)
      local text = self:GetText():trim()
      if text == '' then self:SetText(SEARCH) end
    end)

    searchForm:SetScript('OnTextChanged', function(self)
      local term = self:GetText():trim()
      if term == '' or term == SEARCH then
        spells = utils.deepCopy(cached)
      else
        spells = submod:search(term)
        fetched = false
      end
    end)

    searchForm:SetScript('OnEscapePressed', function(self)
      self:SetText(SEARCH)
      self:ClearFocus()
      spells = cached
      loaded, fetched = false, false
    end)
    searchForm:SetScript('OnEnterPressed', function(self)
      self:ClearFocus()
      loaded, fetched = false, false
    end)

    localized = true
  end

  local function loadSpells()
    cached = {}
    for k, v in pairs(addon.spellInfo) do
      local spell = utils.deepCopy(v)
      spell.spellId = k
      spell.spellName = select(1, GetSpellInfo(k))
      table.insert(cached, spell)
    end
    if sortType and sortTypes[sortType] then
      table.sort(cached, sortTypes[sortType])
    end
    loaded, fetched = true, false
  end

  local fetchSpells
  do
    local function resetSpellsList()
      local i = 1
      local btn = _G[frameName..'_SpellBtn_'..i]
      while btn do
        btn:Hide()
        i = i + 1
        btn = _G[frameName..'_SpellBtn_'..i]
      end
    end

    function fetchSpells()
      if #spells == 0 then spells = utils.deepCopy(cached) end
      resetSpellsList()

      local scrollFrame = _G[frameName..'ListScrollFrame']
      local scrollChild = _G[frameName..'ListScrollFrameScrollChild']
      scrollChild:SetHeight(scrollFrame:GetHeight())
      scrollChild:SetWidth(scrollFrame:GetWidth())

      local height = 0

      for k, v in ipairs(spells) do
        local btnName = frameName..'_SpellBtn_'..k
        local btn = _G[btnName] or CreateFrame('Button', btnName, scrollChild, 'ElvinCDs_SpellButton')
        btn:SetID(k)
        btn:Show()

        -- Spell Details:
        _G[btnName..'SpellId']:SetText(v.spellId)
        _G[btnName..'Cooldown']:SetText((v.cooldown and v.cooldown > 0) and utils.sec2clock(v.cooldown) or '')
        _G[btnName..'Display']:SetChecked(not v.hidden)
        _G[btnName..'Track']:SetChecked(v.track)
        _G[btnName..'Group']:SetChecked(v.group)
        _G[btnName..'Shout']:SetChecked(v.shout)
        _G[btnName..'Whisper']:SetChecked(v.whisper)
        _G[btnName..'Special']:SetChecked(v.talent)

        local name = _G[btnName..'SpellName']
        name:SetText(v.spellName)
        name:SetScript('OnEnter', function(self)
          local spellLink = GetSpellLink(v.spellId)
          GameTooltip_SetDefaultAnchor(ElvinCDs_Tooltip, btn)
          ElvinCDs_Tooltip:SetHyperlink(spellLink)
          ElvinCDs_Tooltip:Show()
          btn:LockHighlight()
          btn.hovered = true
        end)
        name:SetScript('OnLeave', function(self)
          ElvinCDs_Tooltip:Hide()
          btn:UnlockHighlight()
          btn.hovered = false
        end)
        name:SetScript('OnClick', function(self)
          selectedId = (v.spellId ~= selectedId) and v.spellId or nil
        end)

        btn:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, -height)
        btn:SetPoint('RIGHT', scrollChild, 'RIGHT', 0, 0)
        height = height + btn:GetHeight()
      end

      fetched = true
    end
  end

  function submod:search(term)
    local found = {}
    for i, s in ipairs(cached) do
      for k, v in pairs(s) do
        if (k == 'spellName' and string.find(v:lower(), term:lower())) or (k == 'spellId' and string.find(tostring(v), term)) then
          table.insert(found, s)
          break
        end
      end
    end
    return (#found > 0) and found or utils.deepCopy(cached)
  end

  local function updateUIFrame(self, elapsed)
    localizeUIFrame()
    if utils.update(self, frameName, 0.05, elapsed) then
      if not loaded then loadSpells() end
      if not fetched then fetchSpells() end

      for k, v in ipairs(spells) do
        local btn = _G[frameName..'_SpellBtn_'..k]
        if btn and not btn.hovered then
          utils.highlight(btn, (selectedId and selectedId == v.spellId))
        end
      end

      local tempId, tempCd = _G[frameName..'SpellId']:GetNumber(), _G[frameName..'Cooldown']:GetNumber()
      local isAdd = (tempId ~= 0 or tempCd ~= 0)
      utils.enableDisable(_G[frameName..'Save'], isAdd)
    end
  end

  function submod:onLoad(frame)
    if not frame then return end
    UIFrame = frame
    frameName = frame:GetName()
    frame:SetScript('OnUpdate', updateUIFrame)
  end

  function submod:onClick(btn)
    if not btn then return end
    local id = btn:GetID()
    if not id or not spells[id] then return end
    local spellId = spells[id].spellId
    selectedId = (spellId ~= selectedId) and spellId or nil
  end

  function submod:sort(t)
    if t and sortTypes[t] then
      ascending = not ascending
      sortType = t
      table.sort(spells, sortTypes[sortType])
      fetched = false
    end
  end

  function submod:change(btn, what)
    if not btn or not what then return end
    local id = btn:GetParent():GetID()
    if not id or not spells[id] then return end
    local spellId = spells[id].spellId
    if not spellId or not addon.spellInfo[spellId] then return end

    -- Create new spell info table and add to database:
    local info = addon.spellInfo[spellId]

    local value = (btn:GetChecked() == 1)

    local success

    if what == 'show' then
      info.hidden = not value
      spells[id].hidden = not value
      success = true
    elseif what == 'track' then
      info.track = value
      spells[id].track = value
      success = true
    elseif what == 'group' then
      info.group = value
      spells[id].group = value
      success = true
    elseif what == 'shout' then
      info.shout = value
      spells[id].shout = value
      success = true
    elseif what == 'whisper' then
      info.whisper = value
      spells[id].whisper = value
      success = true
    elseif what == 'talent' then
      info.talent = value
      spells[id].talent = value
      success = true
    end

    if success then
      Elvin_Spells[spellId] = info
      utils.triggerEvent('ResetBars')
      loaded, fetched = false, false
    end
  end

  function submod:reset(ld)
    if ld then loaded = false end
    fetched = false
  end

  function submod:save(btn)
    if not btn then return end

    --------------
    -- Spell ID --
    --------------
    local spellId = _G[frameName..'SpellId']:GetNumber()
    if spellId == 0 then
      utils.printError(L['Please provide a spell ID'])
      return
    end
    local spellLink = GetSpellLink(spellId)
    if not spellLink then
      utils.printError(L:F('Cannot find spell: %s', spellId))
      return
    end

    --------------------
    -- Spell Cooldown --
    --------------------
    local cooldown = _G[frameName..'Cooldown']:GetNumber()

    ------------------
    -- CheckButtons --
    ------------------
    local track   = (_G[frameName..'Track']:GetChecked() == 1)
    local group   = (_G[frameName..'Group']:GetChecked() == 1)
    local shout   = (_G[frameName..'Shout']:GetChecked() == 1)
    local whisper = (_G[frameName..'Whisper']:GetChecked() == 1)
    local talent  = (_G[frameName..'Special']:GetChecked() == 1)

    ---------------------------
    -- Whether to show spell --
    ---------------------------
    local hidden = not (_G[frameName..'Display']:GetChecked() == 1)

    -- Now we add the new spell:
    Elvin_Spells[spellId] = {
      cooldown = cooldown,
      track = track,
      group = group,
      shout = shout,
      whisper = whisper,
      talent = talent
    }

    -- Now we insert the spell into cooldowns table.
    if track and not hidden then
      Elvin_Cooldowns[spellId] = {players = {}}
    end

    -- Clear all data:
    _G[frameName..'SpellId']:SetText('')
    _G[frameName..'SpellId']:ClearFocus()
    _G[frameName..'Cooldown']:SetText('')
    _G[frameName..'Cooldown']:ClearFocus()
    _G[frameName..'Display']:SetChecked(false)
    _G[frameName..'Track']:SetChecked(false)
    _G[frameName..'Group']:SetChecked(false)
    _G[frameName..'Shout']:SetChecked(false)
    _G[frameName..'Special']:SetChecked(false)
    _G[frameName..'Display']:SetChecked(false)

    utils.printSuccess(L:F('New spell added: %s', spellLink))
    utils.triggerEvent('UpdateBars')
    loaded, fetched = false, false
  end
end


addon.Config = mod
