local _, addon = ...

local _G = _G
local UnitFactionGroup = _G.UnitFactionGroup
local unitFaction = addon.unitFaction
if not unitFaction then
  unitFaction = (UnitFactionGroup('player') == 'Alliance') and 1 or 2
  addon.unitFaction = unitFaction
end

local hero = (unitFaction == 1) and 32182 or 2825

local spells = {
  ----------------------------------------------------------------
  DEATHKNIGHT = {
    [48707] = {cooldown = 45, blind = true}, -- Anti-Magic Shell
    [48982] = {cooldown = 60, talent = true, blind = true}, -- Rune Tap
    [49005] = {cooldown = 180, talent = true}, -- Mark of Blood
    [49016] = {cooldown = 180, talent = true, track = true, hidden = true, whisper = true}, -- Hysteria
    [49222] = {cooldown = 60, talent = true, blind = true}, -- Bone Shield
    [51052] = {cooldown = 120, talent = true, blind = true}, -- Anti-Magic Zone
    [51271] = {cooldown = 60, talent = true, blind = true}, -- Unbreakable Armor
    [55233] = {cooldown = 60, blind = true} -- Vampiric Blood
  },

  ----------------------------------------------------------------
  DRUID = {
    [22812] = {cooldown = 60, blind = true}, -- Barkskin
    [22842] = {cooldown = 180, blind = true}, -- Frenzied Regeneration
    [27009] = {cooldown = 60, blind = true}, -- Nature's Grasp
    [29166] = {cooldown = 180, track = true, whisper = true}, -- Innervate
    [48447] = {cooldown = 480, track = true, hidden = true, blind = true}, -- Tranquility
    [48477] = {cooldown = 600, blind = true}, -- Frenzied Regeneration
    [50334] = {cooldown = 180, talent = true, blind = true}, -- Berserk
    [5209]  = {cooldown = 180, blind = true}, -- Challenging Roar
    [5229]  = {cooldown = 60, blind = true}, -- Enrage
    [61336] = {cooldown = 180, talent = true, blind = true}, -- Survival Instincts
    [8983]  = {cooldown = 60}, -- Bash
    [48477] = {cooldown = 600, track = true, shout = true}, -- Rebirth
    [50763] = {cooldown = 0, shout = true} -- Revive
  },

  ----------------------------------------------------------------
  HUNTER = {
    [19263] = {cooldown = 60}, -- Deterrence
    [23989] = {cooldown = 180}, -- Readiness
    [3045]  = {cooldown = 300}, -- Rapid Fire
    [34477] = {cooldown = 30, track = true, whisper = true}, -- Misdirection
    [53271] = {cooldown = 60}-- Master's Call
  },

  ----------------------------------------------------------------
  MAGE = {
    [12051] = {cooldown = 240, blind = true}, -- Evocation
    [130]   = {cooldown = 0, whisper = true}, -- Slow fall
    [43015] = {cooldown = 0, shout = true}, -- Dampen Magic
    [43017] = {cooldown = 0, shout = true}, -- Amplify Magic
    [45438] = {cooldown = 300, blind = true}, -- Ice Block
    [54646] = {cooldown = 0, talent = true, whisper = true}, -- Focus Magic
    [66]    = {cooldown = 180, blind = true} -- Invisibility
  },

  ----------------------------------------------------------------
  PALADIN = {
    [10278] = {cooldown = 300, track = true, hidden = true, shout = true}, -- Hand of Protection
    [10308] = {cooldown = 60, track = true, hidden = true, shout = true}, -- Hammer of Justice
    [1038]  = {cooldown = 120, track = true, hidden = true, shout = true}, -- Hand of Salvation
    [1044]  = {cooldown = 25, track = true, hidden = true, shout = true}, -- Hand of Freedom
    [20066] = {cooldown = 60, talent = true, track = true, hidden = true, shout = true}, -- Repentence
    [31821] = {cooldown = 120, talent = true, shout = true, blind = true}, -- Aura Mastery
    [31884] = {cooldown = 180, blind = true}, -- Avenging Wrath
    [48788] = {cooldown = 1200, track = true, hidden = true, shout = true}, -- Lay of Hands
    [48817] = {cooldown = 30, track = true, hidden = true, blind = true}, -- Holy Wrath
    [48950] = {cooldown = 0, shout = true}, -- Redemption
    [498]   = {cooldown = 180, track = true, hidden = true, blind = true}, -- Divine Protection
    [53563] = {cooldown = 0, talent = true}, -- Beacon of Light
    [54428] = {cooldown = 60, shout = true, blind = true}, -- Divine Plea
    [64205] = {cooldown = 120, talent = true, track = true, shout = true, blind = true}, -- Divine Sacrifice
    [642]   = {cooldown = 300, track = true, hidden = true, blind = true}, -- Divine Shield
    [6940]  = {cooldown = 120, track = true, hidden = true, shout = true} -- Hand of Sacrifice
  },

  ----------------------------------------------------------------
  PRIEST = {
    [10060] = {cooldown = 120, talent = true, track = true, hidden = true, whisper = true}, -- Power Infusion
    [10890] = {cooldown = 30, blind = true}, -- Psychic Scream
    [14751] = {cooldown = 180, track = true, hidden = true, blind = true}, -- Inner Focus
    [15487] = {cooldown = 45, talent = true, shout = true, blind = true}, -- Psychic Scream
    [1706]  = {cooldown = 0, whisper = true}, -- Levitate
    [33206] = {cooldown = 180, talent = true, track = true, hidden = true, shout = true}, -- Pain Suppression
    [47788] = {cooldown = 180, talent = true, track = true, hidden = true, shout = true}, -- Guardian Spirit
    [48171] = {cooldown = 0, shout = true}, -- Resurrection
    [586]   = {cooldown = 30, blind = true}, -- Fade
    [6346]  = {cooldown = 180, track = true, hidden = true, shout = true}, -- Fear Ward
    [64044] = {cooldown = 120, talent = true, blind = true}, -- Psychic Horror
    [64843] = {cooldown = 480, track = true, hidden = true, blind = true}, -- Divine Hymn
    [64901] = {cooldown = 360, track = true, hidden = true, shout = true, blind = true} -- Hymn of Hope
  },

  ----------------------------------------------------------------
  ROGUE = {
    [13877] = {cooldown = 120, talent = true, blind = true}, -- Blade Furry
    [1766]  = {cooldown = 10, shout = true}, -- Kick
    [1833]  = {cooldown = 0}, -- Cheap Shot
    [2094]  = {cooldown = 180, shout = true}, -- Blind
    [26889] = {cooldown = 180, track = true, hidden = true, blind = true}, -- Vanish
    [51690] = {cooldown = 120, talent = true, blind = true}, -- Killing Spree
    [51722] = {cooldown = 60, shout = true}, -- Dismantle
    [51724] = {cooldown = 0, shout = true}, -- Sap
    [57934] = {cooldown = 30, track = true, whisper = true}, -- Tricks of the Trade
    [8643]  = {cooldown = 20} -- Kidney Shot
  },

  ----------------------------------------------------------------
  SHAMAN = {
    [16190] = {cooldown = 300, talent =true, track = true, hidden = true, shout = true, blind = true}, -- Mana Tides Totem
    [20608] = {cooldown = 1800, track = true, hidden = true, blind = true}, -- Reincarnation
    [2894]  = {cooldown = 600, blind = true}, -- Fire ELemental Totem
    [30823] = {cooldown = 60, talent = true, blind = true}, -- Shamanistic Rage
    [49277] = {cooldown = 0, shout = true}, -- Ancestral Spirit
    [51514] = {cooldown = 45, shout = true}, -- HEX
    [51533] = {cooldown = 180, talent = true, blind = true}, -- Feral Spirit
    [546]   = {cooldown = 0, whisper = true}, -- Water Walking
    [55198] = {cooldown = 300, talent = true, blind = true}, -- Tidal Force
    [57994] = {cooldown = 6, shout = true}, -- Wind Shear
    [hero]  = {cooldown = 300, track = true, hidden = false, shout = true, blind = true} -- Heroism/Bloodlust
  },

  ----------------------------------------------------------------
  WARLOCK = {
    [126]   = {cooldown = 0, blind = true}, -- Eye of Kilrogg
    [17928] = {cooldown = 0, blind = true}, -- Howl of Terror
    [18647] = {cooldown = 0, shout = true}, -- Banish
    [29858] = {cooldown = 180, shout = true, blind = true}, -- Soulshatter
    [47241] = {cooldown = 180, talent = true, blind = true}, -- Metamorphosis
    [47883] = {cooldown = 900, track = true, hidden = true, whisper = true}, -- Soulstone Resurrection
    [5697]  = {cooldown = 0, whisper = true}, -- Unending Breath
    [58887] = {cooldown = 300, shout = true, blind = true}, -- Ritual of Souls
    [6215]  = {cooldown = 0, shout = true}, -- Fear
    [698]   = {cooldown = 120, shout = true, blind = true} -- Ritual of Summoning
  },

  ----------------------------------------------------------------
  WARRIOR = {
    [1161]  = {cooldown = 180, blind = true}, -- Challenging Shout
    [12292] = {cooldown = 180, talent = true, track = true, hidden = true, blind = true}, -- Death Wish
    [12323] = {cooldown = 0, talent = true, blind = true}, -- Piercing Howl
    [1715]  = {cooldown = 0}, -- Hamstring
    [18499] = {cooldown = 30, blind = true}, -- Berserker Rage
    [20230] = {cooldown = 300, track = true, hidden = true, blind = true}, -- Retaliation
    [2687]  = {cooldown = 60, blind = true}, -- Bloodrage
    [46924] = {cooldown = 60, talent = true, blind = true}, -- Berserker Rage
    [50720] = {cooldown = 0, talent = true, track = true, hidden = true, shout = true, whisper = true}, -- Vigilance
    [55694] = {cooldown = 180}, -- Enraged Regeneration
    [60970] = {cooldown = 45, talent = true}, -- Heroic Fury
    [676]   = {cooldown = 60, track = true, hidden = true, shout = true}, -- Death Wish
    [871]   = {cooldown = 300, track = true, hidden = true} -- Shield Wall
  }

}


addon.spells = spells
