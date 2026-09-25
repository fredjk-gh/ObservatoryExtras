-- A custom criteria that calls out bodies which are orbiting closely to a ring on a parent body.
-- This is a more advanced version of the built-in Close Ring Proximity criteria.
--
-- Differences from built-in:
-- - Handles only rings, not belts.
-- - Supports barycentres/binary bodies (nested, too), which means it may fire for multiple bodies if both binaries are close to the ring.
-- - Uses a customizeable absolute threshold (default 500 km) vs. a body-relative threshold (10% of moon radius)
-- - Identifies the ring to which the body is close to in extended details.
-- - This is an AllBodies criteria rather than a Scan-based criteria. (ie. it fires when the system is fully scanned.)
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-09-25.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Global Advanced Close Ring Proximity check

-- User adjustable knobs:
-- The threshold in kms for alerting about a close ring proximity body. Unlike the built-in, this is absolute, not relative to the body size.
AdvCloseRingProx_AlertThresholdKm = 500

-- Internal stuff.

-- duplicate suppression
_ReportedCloseRingProx = {}

---@param scan scan
---@return number
function GetBodyKey(scan)
  return scan.BodyID -- string.format("%i", scan.BodyID)
end

-- Adapted from https://stackoverflow.com/questions/10989788/format-integer-in-lua
function Thousands(n)
  return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,"):gsub(",(%-?)$","%1"):reverse()
end

---@param system system
---@param parentsTable table<number, parents>
---@return table<number, table<scan>>
function BuildChildrenTable(system, parentsTable)
  ---@type table<number, table<scan>>
  local childrenTable = {}

  for body in bodies(system) do
    local lastChildScan = body
    if body.BodyID > 0 then -- BodyID=0 is never in the parentsTable
      for p in allparents(parentsTable[GetBodyKey(body)]) do
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

  return childrenTable
end

---@param ringName string
---@param bodyScan scan
---@param separation number
---@param depth number
function NotifyCloseRingProximity(ringName, bodyScan, separation, depth)
  local extra = ""
  local landableStr = ""
  local distQualifier = "Distance"
  if depth > 0 then
    extra = string.format(", binary body with depth %d", depth)
    distQualifier = "Minimum distance"
  end
  if bodyScan.Landable then
    landableStr = ", Landable"
  end

  notifyForBody(
    bodyScan.BodyName,
    "Close Ring Proximity",
    string.format(
        "(CC) Orbit: %s km, Radius: %s km, %s from ring: %.0f km%s, Ring: %s%s",
        Thousands(distanceAsKm(bodyScan.SemiMajorAxis)),
        Thousands(distanceAsKm(bodyScan.Radius)),
        distQualifier,
        distanceAsKm(separation),
        landableStr,
        ringName,
        extra),
    bodyScan.BodyID)
end

---@param ringName string
---@param remainingSeparation number
---@param childScan scan
---@param childrenTable table<number, table<scan>>
---@param depth number
function CheckBarycentreChildDistance(ringName, remainingSeparation, childScan, childrenTable, depth)
  local childSep = remainingSeparation - childScan.SemiMajorAxis

  if isPlanet(childScan) or isStar(childScan) then -- Terminal case.
    childSep = childSep - childScan.Radius

    if distanceAsKm(childSep) < AdvCloseRingProx_AlertThresholdKm then
      NotifyCloseRingProximity(ringName, childScan, childSep, depth)
    end

  elseif isBarycentre(childScan) and childrenTable[childScan.BodyID] ~= nil then -- Recursive case.
    remainingSeparation = remainingSeparation - childScan.SemiMajorAxis

    for _, baryChild in pairs(childrenTable[childScan.BodyID]) do
      CheckBarycentreChildDistance(ringName, remainingSeparation, baryChild, childrenTable, depth + 1)
    end
  end
end

---@param allBodies allBodies
---@param system system
---@param parentsTable table<number, parents>
function CheckCloseRingProximity(allBodies, system, parentsTable)
  local key = tostring(allBodies.SystemAddress)
  if _ReportedCloseRingProx[key] then return end

  local childrenTable = BuildChildrenTable(system, parentsTable);

  for scan in bodies(system) do
    if (isStar(scan) or isPlanet(scan)) and hasRings(scan.Rings) and childrenTable[scan.BodyID] ~= nil then
      -- a body with rings and children. Time for a closer look.
      local children = childrenTable[scan.BodyID]
      for _, childScan in pairs(children) do
        if isBarycentre(childScan) and childrenTable[childScan.BodyID] ~= nil then
          local baryChildren = childrenTable[childScan.BodyID]

          for r in ringsOnly(scan.Rings) do
            local bsep = math.min(
                math.abs(childScan.SemiMajorAxis - r.outerrad),
                math.abs(r.innerrad - childScan.SemiMajorAxis)
              );

            for _, baryChild in pairs(childrenTable[childScan.BodyID]) do
              CheckBarycentreChildDistance(r.name, bsep, baryChild, childrenTable, 1)
            end
          end
        elseif isPlanet(childScan) or isStar(childScan) then

          for r in ringsOnly(scan.Rings) do
            local sep = math.min(
                math.abs(childScan.SemiMajorAxis - r.outerrad),
                math.abs(r.innerrad - childScan.SemiMajorAxis)
              ) - childScan.Radius

            if distanceAsKm(sep) < AdvCloseRingProx_AlertThresholdKm then
              NotifyCloseRingProximity(r.name, childScan, sep, 0)
            end
          end
        end
      end
    end
  end

  _ReportedCloseRingProx[key] = true
end
---@End

---@AllBodies Advanced Close Ring Proximity check
CheckCloseRingProximity(allBodies, system, parentsTable)
---@End
