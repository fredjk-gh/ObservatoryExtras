-- A custom criteria that calls out bodies with high moon count
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras
-- 
-- Version History:
-- version 2026-11-23.1 - Initial Revision

---@Global - High Moon Count
HighMoonCount_LastNotifiedSystemId64 = -1

-- The number of direct moons are required to trigger the notification.
HighMoonCount_Threshold = 13 -- 'm'

-- Also yoinked from the internet.
---@param t table
function HighMoonCount_GetTableSize(t)
  local count = 0
  if t == nil then return count end
  for _ in pairs(t) do
      count = count + 1
  end
  return count
end

---@param scan scan
---@return number
function HighMoonCount_GetBodyKey(scan)
  return scan.BodyID -- string.format("%i", scan.BodyID)
end

---@param system system
---@param parentsTable table<number, parents>
---@return number, table<number, table<scan>>
function HighMoonCount_CountBodiesAndBuildChildrenTable(system, parentsTable)
  ---@type table<number, table<scan>>
  local childrenTable = {}
  local bodyCount = 0

  for body in bodies(system) do
    local lastChildScan = body
    if isStar(body) or isPlanet(body) then -- ignore barycentres.
      bodyCount = bodyCount + 1
      if body.BodyID > 0 then -- BodyID=0 is never in the parentsTable
        for p in allparents(parentsTable[HighMoonCount_GetBodyKey(body)]) do
          if p.parenttype ~= 'Null' then -- squash barycentres so that the barycentre children appear as direct children of the parent.
            if childrenTable[p.body] == nil then
              childrenTable[p.body] = {}
            end

            if lastChildScan ~= nil then
              childrenTable[p.body][lastChildScan.BodyID] = lastChildScan
            end
            lastChildScan = p.scan
          end
        end
      end
    end
  end

  return bodyCount, childrenTable
end

---@param count number
function HighMoonCount_MoonLetter(count)
  return string.char(string.byte("a") + count - 1)
end

---@param allBodies allBodies
---@param system system
---@param parentsTable table<number, parents>
function HighMoonCount_Check(allBodies, system, parentsTable)
  if HighMoonCount_LastNotifiedSystemId64 == allBodies.SystemAddress then
    return false
  end

  local bodyCount, childrenTable = HighMoonCount_CountBodiesAndBuildChildrenTable(system, parentsTable)


  if bodyCount ~= allBodies.Count then
    return false
  end

  for s in bodies(system) do
    if isPlanet(s) then
      local moons = childrenTable[s.BodyID]
      local moonCount = HighMoonCount_GetTableSize(moons)
      if moonCount >= HighMoonCount_Threshold then -- we only consider planets as parents.
        notifyForBody(s.BodyName, "High Moon Count",
            string.format("Body has %d moons; last moon: %s %s", moonCount, s.BodyName, HighMoonCount_MoonLetter(moonCount)), s.BodyID)
      end
    end
  end

  HighMoonCount_LastNotifiedSystemId64 = allBodies.SystemAddress
end
---@End Global - High Moon Count

---@AllBodies High Moon Count
HighMoonCount_Check(allBodies, system, parentsTable)
---@End
