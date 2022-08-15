local options = {
  -- The sub menu name
  Name = "Warlock (Affli)",

  -- widgets
  Widgets = {
    {
      type = "checkbox",
      uid = "WarlockAfflWandFinish",
      text = "Wand Finisher",
      default = false
    },
    {
      type = "slider",
      uid = "WarlockAfflLifeTapPercent",
      text = "Life Tap hp%",
      default = 90,
    },
    {
      type = "slider",
      uid = "WarlockAfflWandExecutePercent",
      text = "Wand Finish hp%",
      default = 30,
      max = 60
    },
    {
      type = "slider",
      uid = "WarlockAfflDrainSoulPct",
      text = "Drain Soul hp% (0 to disable)",
      default = 0,
      max = 100
    },
  }
}

local spells = {
  DemonArmor = WoWSpell("Demon Armor"),
  DemonSkin = WoWSpell("Demon Skin"),
  LifeTap = WoWSpell("Life Tap"),
  CurseOfAgony = WoWSpell("Curse of Agony"),
  Corruption = WoWSpell("Corruption"),
  DrainLife = WoWSpell("Drain Life"),
  DrainSoul = WoWSpell("Drain Soul"),
  ShadowBolt = WoWSpell("Shadow Bolt"),
  Shoot = WoWSpell("Shoot")
}

WarlockAfflListener = wector.FrameScript:CreateListener()
WarlockAfflListener:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')

-- This fixes the problem of double casting corruption
local corruptionFix = 0
function WarlockAfflListener:UNIT_SPELLCAST_SUCCEEDED(unitTarget, _, spellID)
  if unitTarget == Me and spellID == spells.Corruption.Id then
    corruptionFix = wector.Game.Time + 100
  end
end

local function LifetapValue()
  local spellid = spells.LifeTap.Id

  if spellid == 1454 then
    return 30
  elseif spellid == 1455 then
    return 90
  elseif spellid == 1456 then
    return 168
  elseif spellid == 11678 then
    return 264
  elseif spellid == 11688 then
    return 372
  elseif spellid == 11689 then
    return 516
  elseif spellid == 27222 then
    return 698
  end

  -- why tho?
  return 0
end

local function WarlockAfflictionCombat()
  -- Threshold % on me for LifeTap
  local HPThresh = Settings.WarlockAfflLifeTapPercent
  -- Threshold % on enemy for using spells
  local SpellThresh = Settings.WarlockAfflWandExecutePercent

  -- buff up
  local spellDemonBuff = spells.DemonArmor.Slot >= 0 and spells.DemonArmor or spells.DemonSkin

  -- Always make sure we are out of combat for buffs and summons and shit
  if not Me.InCombat then
    -- Demon Armor/Skin
    if not Me:HasVisibleAura(spellDemonBuff.Id) and spellDemonBuff:CastEx(Me) then return end
  end

  -- Lifetap anytime to gain value outside of combat also
  -- Life Tap if our health is more than what we choose and our mana deficit is more than what lifetap will return
  if Me.HealthPct >= HPThresh and not Me.IsCastingOrChanneling and (Me.PowerMax - Me.Power >= LifetapValue()) and
      spells.LifeTap:CastEx(Me) then return end

  -- Make sure we have a target before continuing
  local target = Combat.BestTarget
  if not target then return end

  -- Only do this when pet is active
  if Me.Pet then
    -- Pet Attack my target
    if not Me.Pet.Target or Me.Pet.Target ~= Me.Target then
      Me:PetAttack(target)
    end
  end

  -- Drain Soul
  if target.HealthPct < Settings.WarlockAfflDrainSoulPct then
    local current = Me.CurrentChannel
    if not current and spells.DrainSoul:CastEx(target) then
      return
    elseif current ~= spells.DrainSoul then
      Me:StopCasting()
    end

    return
  end

  if Me:HasBuff("Shadow Trance") and spells.ShadowBolt:CastEx(target) then return end

  -- Wand finisher, convert to percentage when that is implemented
  if target:GetHealthPercent() <= SpellThresh then
    if not spells.Shoot.IsAutoRepeat and spells.Shoot:CastEx(target) then return end

    return
  end

  if Me.IsCastingOrChanneling then return end

  -- Curruption
  local shouldCorruption = (wector.Game.Time - corruptionFix) > 0
  if shouldCorruption and not target:HasDebuffByMe("Corruption") and spells.Corruption:CastEx(target) then return end

  -- Curse of Agony
  if not target:HasDebuffByMe("Curse of Agony") and spells.CurseOfAgony:CastEx(target) then return end

  -- Drain Life if our mana is above a percentage
  if Me.PowerPct > 60 and spells.DrainLife:CastEx(target) then return end

  -- Wand
  -- Only if not fully debuffed
  if not target:HasDebuffByMe("Curse of Agony") or not target:HasDebuffByMe("Corruption") then return end

  -- Use wand if mana below drain life mana threshold
  if not spells.Shoot.IsAutoRepeat and Me.PowerPct <= 60 and spells.Shoot:CastEx(target) then return end
end

local behaviors = {
  [BehaviorType.Combat] = WarlockAfflictionCombat
}

return { Options = options, Behaviors = behaviors }
