-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which compares a scanned ELW against the details
-- of Earth (in-game) to derive a score measuring similarity. 100 is an exact match, lower is less similar.
-- This is NOT DW3 organizer approved nor official in any way. It's a reverse-engineering of the official website
-- and may not be 100% accurate. It's mostly for a quick result while you wait for the data to sync to Spansh so you
-- can upload it officially.
--
-- Note that this will generate a result for any ELWs found after fully completing the FSS systems scan.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- Inspiration:                 https://justbearli.short.gy/DW3Earth2Submission
-- 
-- Author: Cmdr Coddiwompler / fredjk-gh, based on work by Pseudo6606 [Foxtrot]; see the #search-for-earth-2 channel in the FleetComm HQ discord.
-- version 2026-05-08.1 -- Checked against version 3 of the official app.
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras
-- ** Requires Observatory Core >= 1.5 **

---@Global DW3

-- For DW3 Earth Similarity Index
DW3Elw_DebugEnable = false
DW3Elw_VerboseEnable = true

---@class ComponentScore
---@field Label string
---@field Score number
---@field Value number
---@field FormatStr string
---@field ValueAdj number
ComponentScore = {}
function ComponentScore:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Provide value with abs() applied if needed.
---@param min number
---@param max number
---@param ideal number
---@param value number
function GaussianScore(min, max, ideal, value)
  if value <= min or value >= max then return 0 end

  local half = 0
  local sigma = 0
  if value < ideal then
    half = ideal - min
  else
    half = max - ideal
  end
  sigma = half / 2
  local z = (value - ideal) / sigma
  return math.exp(-0.5 * (z ^ 2))
end

---@param label string
---@param value number
function DebugValue(label, value)
  if DW3Elw_DebugEnable then
    notify("Debug", label, string.format("%s", value))
  end
  return value
end

---@param label string
---@param value number
---@param bodyId number
function DebugValueForBody(label, value, bodyId)
  if DW3Elw_DebugEnable then
    notifyForBody("Debug", label, string.format("%s", value), bodyId)
  end
  return value
end

---@param scan scan
---@return number
function GetBodyKey(scan)
  return scan.BodyID -- string.format("%i", scan.BodyID)
end

---@param scan scan
function ComputeNonO2Fraction(scan)
  local nonO2fraction = 1
  for atmoMat in materials(scan.AtmosphereComposition) do
    if atmoMat.name == "Oxygen" then
      nonO2fraction = nonO2fraction - (atmoMat.percent / 100)
      break
    end
  end
  return nonO2fraction
end


---@param system system
---@param parentsTable table<number, parents>
---@return table<number, table<scan>>
function BuildChildrenTable(system, parentsTable)
  ---@type table<number, table<scan>>
  local childrenTable = {}

  for body in bodies(system) do
    local lastChildScan = body
    if body.BodyID > 0 then -- BodyID is never in the parentsTable
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

---@param elwScan scan
---@param system system
---@param parentsTable table<number, parents>
---@param childrenTable table<number, table<scan>>
function ComputeOrbitalPeriod(elwScan, system, parentsTable, childrenTable)
  ---@type parents
  local parents = parentsTable[GetBodyKey(elwScan)]
  local localOrbitalPeriodDays = periodAsDay(elwScan.OrbitalPeriod)
  if not parents then return DebugValue("Using local orbitalPeriod (from elw)", localOrbitalPeriodDays) end

  -- First look for any direct stars in parents, use the orbital period from the next level lower.
  local lastScan = elwScan
  for parent in allparents(parents) do
    if parent.parenttype == "Star" then
      -- use the lastScan's orbital period, if not nil
      if lastScan ~= nil then
        return DebugValue(string.format("Direct pass: Using orbitalPeriod from "..lastScan.BodyID), periodAsDay(lastScan.OrbitalPeriod))
      end
      break;
    end
    lastScan = parent.scan
  end

  -- For each layer of bary centre -- check if there's a star as a sibling of the barycenter and treat that as the parent star
  -- (could do a flux check, but), and then use the  barycentre's orbital period... Otherwise, use topmost barycentre's orbital
  -- period before a direct star parent.
  local bestOrbitalPeriodDays = localOrbitalPeriodDays
  local lastChildScan = elwScan
  for parent in allparents(parents) do
    if parent.parenttype ~= 'Null' or not parent.scan then return DebugValue("Using orbitalPeriod from "..lastChildScan.BodyID, bestOrbitalPeriodDays) end

    local children = childrenTable[parent.body]
    for _, c in pairs(children) do
      ---@type scan
      local child = c

      if child.BodyID ~= lastChildScan.BodyID then
        if isStar(child) then -- and not (child.StarType == "Y" or child.StarType == "T" or child.StarType == "L") then
          -- Consider this the parent star -- use this parent's orbital period.
          return DebugValue("Using orbitalPeriod from "..lastChildScan.BodyID, bestOrbitalPeriodDays)
        end
      end
    end
    bestOrbitalPeriodDays = periodAsDay(parent.scan.OrbitalPeriod)
    lastChildScan = parent.scan
  end

  return DebugValue("Using orbitalPeriod from last available scan "..lastChildScan.BodyID, bestOrbitalPeriodDays)
end

RE_m   = 6.371e6
ME_kg  = 5.972e24
A_EM_m = 384400e3
P_EM_s = 27.321661 * 86400
N_EM   = 2 * math.pi / P_EM_s
E_EM   = 0.0549;
MMRATIO_EM = 0.0123000371
EARTH_OBL_RAD = 23.439281 * math.pi / 180;
X_EM_HEATED   = math.cos(EARTH_OBL_RAD)
P_EM_DAYS     = 27.321661
EARTH_ROT_D   = 1.0
P_EM_REF      = P_EM_DAYS / EARTH_ROT_D
K_TW   = 3.2;

---@param elwScan scan
---@param system system
---@param parentsTable table<number, parents>
---@return number, number
function ComputeTidalHeatingScore(elwScan, system, parentsTable)
  local moons = FindPerturbers(elwScan, system, parentsTable)
  DebugValue("Found Moon Count", #moons)
  local orbitalParent = FindOrbitalParent(elwScan, parentsTable)

  local heatedObj = elwScan
  ---@type table<scan>
  local perturbers = {}
  if orbitalParent ~= nil then -- ie. elwIsMoon -- the ELW is the perturber
    DebugValueForBody(string.format("ELW has Orbital Parent %s", orbitalParent.BodyName), orbitalParent.BodyID, elwScan.BodyID)
    heatedObj = orbitalParent
    table.insert(perturbers, elwScan)
  else
    perturbers = moons
  end

  local tidalHeating = 0
  local overlapPenalty = 0

  if (#perturbers > 0) then
    local moonaRp = {}

    for _, v in ipairs(perturbers) do
      ---@type scan
      local perturber = v
      local Pert_Sma = perturber.SemiMajorAxis -- a_m
      local Pert_MassKg = perturber.MassEM * ME_kg -- mPert
      local Pert_OrbPer = math.abs(perturber.OrbitalPeriod) -- Pm_s
      local Pert_Ecc = perturber.Eccentricity -- e

      local n = DebugValueForBody(string.format("%s: n", perturber.BodyName), 2 * math.pi / Pert_OrbPer, perturber.BodyID)
      local q = DebugValueForBody(string.format("%s: q", perturber.BodyName), Pert_MassKg / (heatedObj.MassEM * ME_kg), perturber.BodyID)
      local q_ratio = DebugValueForBody(string.format("%s: q_ratio", perturber.BodyName), q / MMRATIO_EM, perturber.BodyID)
      local r_ratio = DebugValueForBody(string.format("%s: r_ratio", perturber.BodyName), RE_m / heatedObj.Radius, perturber.BodyID)
      local a_ratio = DebugValueForBody(string.format("%s: a_ratio", perturber.BodyName), A_EM_m / Pert_Sma, perturber.BodyID)
      local n_ratio = DebugValueForBody(string.format("%s: n_ratio", perturber.BodyName), n / N_EM, perturber.BodyID)

      local shape = 0
      if heatedObj.TidalLock then
        if E_EM > 0 then
          shape = (Pert_Ecc / E_EM) ^ 2
        end
      else
        local orbDays = periodAsDay(Pert_OrbPer)
        local p = orbDays / periodAsDay(math.abs(heatedObj.RotationPeriod))
        local x_heated = math.cos(math.clamp(math.abs(heatedObj.AxialTilt), 0, math.pi))
        local phi = Phi_ctl(Pert_Ecc, x_heated, p)
        if phi >= math.huge or phi < 0 then phi = 0 end
        shape = phi / Phi_ref()
      end

      local factor = (q_ratio * q_ratio) * (r_ratio ^ 5) * (a_ratio ^ 6) * n_ratio * shape
      DebugValueForBody(string.format("%s factors: %s, %s, %s, %s, %s", perturber.BodyName, (q_ratio * q_ratio), (r_ratio ^ 5), (a_ratio ^ 6), n_ratio, shape), factor, perturber.BodyID)
      local H_TW = DebugValueForBody("H_TW for "..perturber.BodyName, K_TW * factor, perturber.BodyID)
      if H_TW > 0 then tidalHeating = tidalHeating + H_TW end

      local arp = DebugValueForBody(string.format("%s: aRp", perturber.BodyName), perturber.SemiMajorAxis / heatedObj.Radius, perturber.BodyID)
      table.insert(moonaRp, arp)
    end

    if orbitalParent == nil and #moonaRp > 0 then -- ie. !elwIsMoon
      table.sort(moonaRp) -- original sorts by (a - b) -- which is effectively ascending.

      local pairs = 0
      local overlaps = 0
      for i = 1, #moonaRp do
        for j = i + 1, #moonaRp do
          pairs = pairs + 1
          if math.abs(moonaRp[i] - moonaRp[j]) < 0.05 * moonaRp[i] then
            overlaps = overlaps + 1
          end
        end
      end
      if pairs > 0 then
        overlapPenalty = DebugValue(string.format("Overlap penalty (overlaps: %d, pairs: %d)", overlaps, pairs), math.clamp(overlaps / pairs, 0, 1))
      end
    end
  end

  return tidalHeating, overlapPenalty
end

function ClampE(e)
  return math.clamp(e, 0, 0.999999)
end

function Phi_ref()
  local v = Phi_ctl(E_EM, X_EM_HEATED, P_EM_REF)
  if v > 0 then return v else return 1 end
end

function Phi_ctl(e, x, p)
  local e_c = ClampE(e)
  local x_c = math.clamp(x, -1, 1)
  local p_c = p
  if p <= 0 then p_c = 1 end

  return Na_e(e_c) + 0.5 * (1+ (x_c * x_c)) * Omega_e(e_c) * (p_c * p_c) - 2 * x_c * N_e(e_c) * p_c
end

function Omega_e(e)
  local e2 = e*e
  local e4 = e2*e2
  local num = 1 + 3 * e2 + 0.375 * e4
  local den = (1 - e2) ^ 4.5
  if den > 0 then
    return (num / den)
  else
    return math.huge
  end
end

function N_e(e)
  local e2 = e*e
  local e4 = e2*e2
  local e6 = e4*e2
  local num = 1 + 7.5 * e2 + 5.625 * e4 + 0.3125 * e6
  local den = (1 - e2) ^ 6
  if den > 0 then
    return (num / den)
  else
    return math.huge
  end
end

function Na_e(e)
  local e2 = e*e
  local e4 = e2*e2
  local e6 = e4*e2
  local e8 = e4*e4
  local num = 1 + 15.5 * e2 + 31.875 * e4 + 11.5625 * e6 + 0.390625 * e8
  local den = (1 - e2) ^ 7.5
  if den > 0 then
    return (num / den)
  else
    return math.huge
  end
end

---@param label string
---@param formatStr string
---@param value number
---@param min number
---@param max number
---@param ideal number
---@param valueAdjForDisplay number
---@return ComponentScore
function GetComponentResult(label, formatStr, value, min, max, ideal, valueAdjForDisplay)
  ---@type ComponentScore
  local result = ComponentScore:new()
  result.Label = label
  result.FormatStr = formatStr
  result.Value = value
  result.ValueAdj = valueAdjForDisplay
  result.Score = DebugValue(label, GaussianScore(min, max, ideal, value))
  return result
end

VALUE_ADJUST_NONE = 1
VALUE_ADJUST_PERCENT = 100

-- This is an approximation of the DW3 Similarity Index https://justbearli.short.gy/DW3Earth2Submission.
-- It's pretty close. Caveats wrt to moons:
-- * It only considers direct child moons. No binary or nested moons.
-- * It has a bug somewhere resulting in the Moon not being correctly calculated.
-- It was later adjusted based on the (lengthy) discussion here: https://discord.com/channels/125106523037761536/1472013693536571447
---@param scan scan
---@param system system
---@param parentsTable table<number, parents>
---@param childrenTable table<number, table<scan>>
function ComputeSimilarityIndex(scan, system, parentsTable, childrenTable)
  local starScan = FindStarScan(system)
  local starAgeGY = starScan.Age_MY / 1000
  local nonO2fraction = ComputeNonO2Fraction(scan)
  local tidalHeating, overlapPenalty = ComputeTidalHeatingScore(scan, system, parentsTable)
  local orbitalPeriodAsDay = ComputeOrbitalPeriod(scan, system, parentsTable, childrenTable)
  local axialTilt = math.abs(scan.AxialTilt)
  local spinDir = " (forward spin)"
  -- If axial tilt > +/- 90, Consider using 180 - math.abs(axialtilt) -- which is similar but reverse spin? -- To be added in update 4.
  if axialTilt > math.pi / 2 then
    spinDir = " (reverse spin)"
    axialTilt = math.abs(axialTilt - math.pi)
  end

  ---@type table<ComponentScore>
  local subscores = {}
  table.insert(subscores, GetComponentResult("Gravity", "%.2f g", gravityAsG(scan.SurfaceGravity), 0.7, 1.3, 1, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Non O2 fraction", "%.1f%%", nonO2fraction, 0.6, 0.95, 0.79, VALUE_ADJUST_PERCENT))
  table.insert(subscores, GetComponentResult("Surface Pressure", "%.2f atm", pressureAsAtm(scan.SurfacePressure), 0.5, 2, 1, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Surface Temperature", "%.0f K", scan.SurfaceTemperature, 250, 320, 288, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Rotational Period", "%.1f d", math.abs(periodAsDay(scan.RotationPeriod)), 0.3, 4, 1, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Orbital Period", "%.1f d", math.abs(orbitalPeriodAsDay), 200, 700, 365, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Axial Tilt"..spinDir, "%.2f rad", axialTilt, 0.05, 0.7, 0.41, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Radius", "%.0f km", distanceAsKm(scan.Radius), 4500, 8000, 6371, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Metal fraction", "%.1f%%", scan.Composition.Metal * 100, 10, 70, 30, VALUE_ADJUST_NONE))
  table.insert(subscores, GetComponentResult("Star age", "%.1f Gyr", starAgeGY, 1, 9, 4.6, VALUE_ADJUST_NONE))
  local heatingSubScore = GetComponentResult("Tidal Heating", "%.2f TW", tidalHeating, 0.001, 20, 3.2, VALUE_ADJUST_NONE)
  heatingSubScore.Score = heatingSubScore.Score * (1 - (math.clamp(overlapPenalty, 0, 1) ^ 1.5))
  table.insert(subscores, heatingSubScore)

  local subscoreSum = 0
  local componentExtDetail = ""
  if DW3Elw_VerboseEnable then
    componentExtDetail = "\n\nComponent scores:"
  end
  ---@param scoreObj ComponentScore
  for i, scoreObj in ipairs(subscores) do
    subscoreSum = subscoreSum + scoreObj.Score

    if DW3Elw_VerboseEnable then
      componentExtDetail = componentExtDetail .. string.format("\n- %s: %s (%.0f%%)", scoreObj.Label, string.format(scoreObj.FormatStr, scoreObj.Value * scoreObj.ValueAdj), scoreObj.Score * VALUE_ADJUST_PERCENT)
    end
  end

  local score = math.clamp((subscoreSum / GetTableSize(subscores)) * 100, 0, 100);
  if score >= 0 then
    local firstDiscovery = scan.ScanType ~= 'NavBeaconDetail' and not scan.WasDiscovered and not scan.WasMapped
    notifyForBody(
      scan.BodyName,
      "DW3 Earth Similarity index",
      string.format("Score: %.1f; first discovery? %s%s", score, firstDiscovery, componentExtDetail),
      scan.BodyID)
  end
end

---@param elwScan scan
---@param parentsTable table<number, parents>
---@return scan|nil
function FindOrbitalParent(elwScan, parentsTable)
  ---@type parents
  local elwParents = parentsTable[GetBodyKey(elwScan)]

  if not elwParents or elwParents[0].ParentType ~= 'Planet' or not elwParents[0].Scan then return nil end

  -- Only interested in Planet parents. Official site looks for non-star parents but I found Barycentres caused issues
  -- resulting in the ELW to be used as the perturber instead of the actual moons resulting in infinite values, etc.
  -- That said, maybe the binary sibling should be the heated body???
  return elwParents[0].Scan
end

---@param elwBody scan
---@param system system
---@param parentsTable table<number, parents>
---@return table<scan>
function FindPerturbers(elwBody, system, parentsTable)
  local moons = {}

  local elwBodyParentBarycentreBodyId = -1
  ---@type parents
  local elwBodyParents = parentsTable[GetBodyKey(elwBody)]
  if elwBodyParents ~= nil and elwBodyParents[0].ParentType == "Null" then
    elwBodyParentBarycentreBodyId = elwBodyParents[0].Body
  end

  for bodyScan in bodies(system) do
    local bodyKey = GetBodyKey(bodyScan)
    if bodyKey == 0 then goto continue_loop end
    ---@type parents
    local p = parentsTable[bodyKey]

    if not isPlanet(bodyScan) or p == nil then goto continue_loop end

    -- Simple case: Parent is the ELW.
    if p[0] and p[0].Body == elwBody.BodyID then
      table.insert(moons, bodyScan)
    -- Nested or binary Moon -- p[0] is a barycentre or another planet, p[1] is ELW
    elseif p[0] and p[0].Scan and (isPlanet(p[0].Scan) or p[0].ParentType == "Null")
        and p[1] and p[1].Body == elwBody.BodyID then
      -- Use some data from the immediate parent body or barycentre and effectively "flatten" the moon structure to simplify it:
      -- - sma 
      -- - orbital period
      -- - eccentricity

      local pScan = p[0].Scan;
      ---@type scan
      local mScan = ShallowCopy(bodyScan)
      mScan.SemiMajorAxis = pScan.SemiMajorAxis
      mScan.OrbitalPeriod = pScan.OrbitalPeriod
      mScan.Eccentricity = pScan.Eccentricity

      table.insert(moons, mScan)
    elseif elwBodyParentBarycentreBodyId > -1 and bodyScan.BodyID ~= elwBody.BodyID
        and p[0] and p[0].ParentType == "Null" and p[0].Body == elwBodyParentBarycentreBodyId then
      -- This body has the same parent barycentre as our ELW. This is our perturber.
      table.insert(moons, bodyScan)
    end

    ::continue_loop::
  end

  return moons
end

---@param system system
---@return scan
function FindStarScan(system)
  local lowestBodyID = math.huge
  local starScan

  for bodyScan in bodies(system) do
    if isStar(bodyScan) and bodyScan.BodyID < lowestBodyID then
      lowestBodyID = bodyScan.BodyID
      starScan = bodyScan
      if bodyScan.BodyID == 0 then break end
    end
  end

  return starScan
end

---@param allBodies allBodies
---@param system system
---@param parentsTable table<number, parents>
function CheckSimilarityIndices(allBodies, system, parentsTable)
  local childrenTable = BuildChildrenTable(system, parentsTable)
  for s in bodies(system) do
    if isPlanet(s) and s.PlanetClass == "Earthlike body" and s.TerraformState == '' then
      ComputeSimilarityIndex(s, system, parentsTable, childrenTable)
    end
  end
end
-- End DW3 Earth Similarity Index.

---@End Global - DW3

---@AllBodies DW3 Similarity Index.
CheckSimilarityIndices(allBodies, system, parentsTable)
---@End
