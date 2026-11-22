-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for systems with at least one ELW, WW and AW.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- Contributions from: Maxsson
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras
-- 
-- Version History:
-- version 2026-11-22.1 - Renamed functions and global variables to avoid collisions with other scripts.
-- version 2026-09-20.1 - Initial revision

---@Global - Trifecta
_Trifecta_Reported = {}

---@param allBodies allBodies
---@param system system
---@param parentsTable table<number, parents>
function Trifecta_Check(allBodies, system, parentsTable)
  local key = tostring(allBodies.SystemAddress)
  if _Trifecta_Reported[key] then return end

  local bodyCount = 0
  local ELWCount = 0
  local WWCount = 0
  local AWCount = 0

  for s in bodies(system) do
    if isPlanet(s) then
      if s.PlanetClass == "Earthlike body" and s.TerraformState == '' then
        ELWCount = ELWCount + 1
      elseif s.PlanetClass == "Water world" then
        WWCount = WWCount + 1
      elseif s.PlanetClass == "Ammonia world" then
        AWCount = AWCount + 1
      end
      bodyCount = bodyCount + 1
    elseif isStar(s) then
      bodyCount = bodyCount + 1
    end
  end

  if bodyCount == allBodies.Count and ELWCount > 0 and WWCount > 0 and AWCount > 0 then
    _Trifecta_Reported[key] = true -- suppress duplicate notifications.
    notify("Trifecta system",
        "System contains at least one earth-like, water and ammonia world",
        string.format("%d ELWs, %d WWs, %d AWs", ELWCount, WWCount, AWCount))
  end
end
---@End Global - Trifecta

---@AllBodies Trifecta check.
Trifecta_Check(allBodies, system, parentsTable)
---@End
