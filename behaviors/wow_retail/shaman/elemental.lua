local common = require('behaviors.wow_retail.shaman.common')

local options = {
    -- The sub menu name
    Name = "Shaman (Elemental)",
    -- widgets
    Widgets = {
        {
            type = "slider",
            uid = "ShamanAstralShift",
            text = "Use Astral Shift below HP%",
            default = 25,
            min = 0,
            max = 100
        }, -- MOVE ME TO COMMON
        {
            type = "checkbox",
            uid = "ShamanUseCooldowns",
            text = "Allow the usage of Big Cooldowns",
            default = true
        },
    }
}

for k, v in pairs(common.widgets) do
    table.insert(options.Widgets, v)
end

local flag = false;

local function IsSurgeOfPower()
    return Me:HasVisibleAura("Surge of Power")
end

local function IsMasterOfTheElements()
    return Me:HasVisibleAura("Master of the Elements")
end

local function IsStormkeeper()
    return Me:HasVisibleAura("Stormkeeper")
end

local function IsPrimordialWave()
    return Me:HasVisibleAura("Primordial Wave")
end

local function IsPowerOfTheMaelstrom()
    return Me:HasVisibleAura("Power of the Maelstrom")
end

local function FireElemental()
    if Spell.FireElemental:CastEx(Me) then return end
end

local function TotemicRecall()
    if Spell.LiquidMagmaTotem:CooldownRemaining() > 3000 and Spell.TotemicRecall:CastEx(Me) then return end
end

local function LiquidMagmaTotem()
    if Spell.LiquidMagmaTotem:CastEx(Me) then return end
end

local function StormkeeperNoAscendance()
    if (not Me:HasVisibleAura("Ascendance")) and Spell.Stormkeeper:CastEx(Me) then return end
end

local function LavaBurstWithStormkeeper(target)
    if IsStormkeeper() and not (IsMasterOfTheElements() or IsSurgeOfPower()) and Spell.LavaBurst:CastEx(target) then return end
end

local function LavaBurstWithPrimordialWave(target)
    if IsPrimordialWave() and Spell.LavaBurst:CastEx(target) then return end
end

local function LavaBurstWithFlameShock(target)
    if (target:GetAuraByMe("Flame Shock") or #target:GetUnitsAround(20) > 2) and Spell.LavaBurst:CastEx(target) then return end
    for _, u in pairs(Combat.Targets) do
        local flameShockAura = u:GetAuraByMe("Flame Shock")
        if (flameShockAura) and Spell.LavaBurst:CastEx(u) then return end
    end
end

local function LightningBoltWithSurgeOfPower(target) 
    if IsSurgeOfPower() and Spell.LightningBolt:CastEx(target) then return end
end

local function ElementalBlast(target)
    if Spell.ElementalBlast:CastEx(target) then return end
end

local function LavaBurst(target)
    if Spell.LavaBurst:CastEx(target) then return end
end

local function LightningBolt(target)
    if Spell.LightningBolt:CastEx(target) then return end
end

local function Earthquake(target)
    if Spell.Earthquake:CastEx(target) then return end
end

local function FlameOrFrostShockMoving(target)
    if Me:IsMoving() then
        if Spell.FlameShock:CastEx(target) or Spell.FrostShock:CastEx(target)  then return end
    end
end

local function Stormkeeper()
    if Spell.Stormkeeper:CastEx(Me) then return end
end

local function LavaBeamOrChainLightning(target)
    if (Spell.LavaBeam:CastEx(target) or Spell.ChainLightning:CastEx(target)) then return end
end

local function ChainLightningMulti(target)
    if IsStormkeeper() or IsPowerOfTheMaelstrom() or IsSurgeOfPower() then
        LavaBeamOrChainLightning(target)
    end
end

-- Loop through all units find one without flame shock or lowest duration to cast Primordial Wave
local function PrimordialWave()
    local lowestDuration = nil
    local unitToCastAt = nil
    for _, u in pairs(Combat.Targets) do
        local flameShockAura = u:GetAuraByMe("Flame Shock")
        if (not flameShockAura) and Spell.PrimordialWave:CastEx(u) then return end
        if flameShockAura and ((not lowestDuration) or lowestDuration > flameShockAura.Remaining) then
            lowestDuration = flameShockAura.Remaining
            unitToCastAt = u
        end
    end
    if (unitToCastAt) and Spell.PrimordialWave:CastEx(unitToCastAt) then return end
end

-- Loop through all units find one without flame shock or lowest duration to cast Flame Shock
local function FlameShock()
    for _, u in pairs(Combat.Targets) do
        local flameShockAura = u:GetAuraByMe("Flame Shock")
        if (not flameShockAura or flameShockAura.Remaining < 5400) and Spell.FlameShock:CastEx(u) then return end
    end
end


local function EarthShield()
    if not Me:HasVisibleAura("Earth Shield") and Spell.EarthShield:CastEx(Me) then return end
end

local function AstralShift()
    if Settings.ShamanAstralShift > Me.HealthPct and Spell.AstralShift:CastEx(Me) then return end
end


local function ShamanElementalCombat()
    if wector.SpellBook.GCD:CooldownRemaining() > 0 then return end
    local target = Combat.BestTarget
    if not target then return end
    if Me.IsCastingOrChanneling then return end

    AstralShift()

    EarthShield()

    common:DoInterrupt()

    FireElemental()

    if #target:GetUnitsAround(20) > 2 then
        --MULTI TARGET
        Stormkeeper()
        PrimordialWave()
        FlameShock()
        LiquidMagmaTotem()
        LavaBurstWithPrimordialWave()
        if #target:GetUnitsAround(20) > 3 then
            Earthquake(target)
        else
            ElementalBlast(target)
        end
        ChainLightningMulti(target)
        LavaBurstWithFlameShock(target)
        LavaBeamOrChainLightning(target)
        FlameOrFrostShockMoving(target)
    else 
        -- SINGLE TARGET
        TotemicRecall()
        LiquidMagmaTotem()
        PrimordialWave()
        FlameShock()
        StormkeeperNoAscendance()
        LavaBurstWithStormkeeper(target)
        LightningBoltWithSurgeOfPower(target)
        ElementalBlast(target)
        LavaBurst(target)
        LightningBolt(target)
        FlameOrFrostShockMoving(target)
    end

end

local behaviors = {
    [BehaviorType.Combat] = ShamanElementalCombat
}

return { Options = options, Behaviors = behaviors }
