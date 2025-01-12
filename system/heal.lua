---@diagnostic disable: param-type-mismatch
Heal = Heal or Targeting:New()

---@type table<WoWUnit[], number>
Heal.PriorityList = {}

---@type table<WoWUnit[], number>
Heal.Tanks = {}

---@type table<WoWUnit[], number>
Heal.DPS = {}

function Heal:Update()
  Targeting.Update(self)
end

function Heal:Reset()
  Heal.PriorityList = {}
  Heal.Tanks = {}
  Heal.DPS = {}
end

function Heal:WantToRun()
  if not Behavior:HasBehavior(BehaviorType.Heal) then return false end
  if not Me then return false end
  if Me.IsMounted then return false end

  if (Me.UnitFlags & UnitFlags.Looting) == UnitFlags.Looting then return false end
  if Me:HasAura("Preparation") then return false end
  return true
end

function Heal:CollectTargets()
  local flags = ObjectTypeFlag.Unit | ObjectTypeFlag.Player | ObjectTypeFlag.ActivePlayer
  local units = wector.Game:GetObjectsByFlag(flags)

  -- copy unit list
  for k, u in pairs(units) do
    self.HealTargets[k] = u.ToUnit
  end
end

function Heal:ExclusionFilter()
  for k, u in pairs(self.HealTargets) do
    if Me:CanAttack(u) then
      self.HealTargets[k] = nil
    elseif u.HealthPct == 100 then
      self.HealTargets[k] = nil
    elseif u.Dead or u.Health <= 1 then
      self.HealTargets[k] = nil
    elseif Me:GetDistance(u) > 40 then
      self.HealTargets[k] = nil
    end
  end
end

function Heal:InclusionFilter()
end

function Heal:WeighFilter()
  local manaMulti = 30
  local group = WoWGroup(GroupType.Auto)

  for _, u in pairs(self.HealTargets) do
    local priority = 0
    local istank = false
    local isdps = false

    -- only heal group members for now
    local member = group:GetMemberByGuid(u.Guid)
    if not member and Me.Guid ~= u.Guid then goto continue end

    if member then
      if member.Role & GroupRole.Tank == GroupRole.Tank then
        priority = priority + 20
        istank = true
      end
      if member.Role & GroupRole.Healer == GroupRole.Healer then priority = priority + 10 end
      if member.Role & GroupRole.Damage == GroupRole.Damage then
        priority = priority + 5
        isdps = true
      end
    end

    priority = priority + (100 - u.HealthPct)
    priority = priority - ((100 - Me.PowerPct) * (manaMulti / 100))

    if priority > 0 or u.InCombat then
      table.insert(self.PriorityList, { Unit = u, Priority = priority })
    end

    if istank then
      table.insert(self.Tanks, { Unit = u, Priority = priority })
    end

    if isdps then
      table.insert(self.DPS, {Unit = u, Priority = priority})
    end

    ::continue::
  end

  table.sort(self.PriorityList, function(a, b)
    return a.Priority > b.Priority
  end)

  table.sort(self.Tanks, function(a, b)
    return a.Priority > b.Priority
  end)
end

---@return WoWUnit
function Heal:GetLowestMember()
  local lowest
  for _, v in pairs(Heal.PriorityList) do
    local u = v.Unit
    if not lowest or lowest.HealthPct > u.HealthPct then
      lowest = u
    end
  end

  return lowest
end

function Heal:GetMembersBelow(pct)
  local count = 0
  local members = {}

  for _, v in pairs(Heal.PriorityList) do
    local u = v.Unit
    if u.HealthPct < pct then
      table.insert(members, u)
      count = count + 1
    end
  end

  return members, count
end

---@param threshold? integer check if unit is below health (Optional)
---@param friend WoWUnit Unit to check around
---@param dist integer Distance from unit to check
function Heal:GetMembersAround(friend, dist, threshold)
  local count = 0
  local members = {}

  for _, v in pairs(self.PriorityList) do
    local f = v.Unit
    if friend:GetDistance(f) <= dist and not threshold or f.HealthPct < threshold then
      count = count + 1
      table.insert(members, f)
    end
  end

  return count, members
end

return Heal
