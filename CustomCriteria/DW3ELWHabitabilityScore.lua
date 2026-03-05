-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which compares a scanned ELW against the details
-- of Earth (in-game) to derive a score measuring habitability. 100 is an exact match, lower is less similar.
-- This is NOT DW3 organizer approved nor official in any way. It's a reverse-engineering of the official website
-- and may not be 100% accurate. It's mostly for a quick result while you wait for the data to sync to Spansh so you
-- can upload it officially.
--
-- Notes:
-- * this will generate a result for any ELWs found after fully completing the FSS systems scan.
-- * The moon score is based on the original implementation that has changed, so consider it wrong. I'm working on an update.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- Inspiration:                 https://justbearli.short.gy/DW3Earth2Submission
-- 
-- Author: Cmdr Coddiwompler / fredjk-gh, based on work by Pseudo6606 [Foxtrot]; see the #search-for-earth-2 channel in the FleetComm HQ discord.
-- version 2026-03-04.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras
-- ** Requires Observatory Core >= 1.4.x **

---@Global DW3 Earthlike Habitability score
DW3ElwId64 = 0
DW3ElwStarScans = {}
DW3ElwScans = {}
DW3ElwMoons = {}
DW3DebugEnable = false

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
  if DW3DebugEnable then
    notify("Debug", label, string.format("%s", value))
  end
  return value
end

---@param val number
---@param min number
---@param max number
function math.clamp(val, min, max)
    return math.max(min, math.min(max, val))
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

---@param scan scan
---@param moons table<number, scan>
function ComputeMoonsTeff(scan, moons)
  local moonsTeff = 0
  local overlapPenalty = 0

  local elwRadius_m = scan.Radius
  local sum = 0
  local moonaRp = {}
  if moons ~= nil then
    ---@param m scan
    for i,m in ipairs(moons) do
      local aRp = m.SemiMajorAxis / elwRadius_m
      table.insert(moonaRp, aRp)
      DebugValue(string.format("aRp for %s", m.BodyName), aRp)
      sum = sum + (60 / math.sqrt(math.max(3, aRp)))
    end
  end
  DebugValue("aRp sum", sum)

  if #moonaRp >= 1 then
    moonsTeff = DebugValue("Moons Teff (base)", math.clamp(80 + (sum * 20), 174, 314)) -- 60, 220
    table.sort(moonaRp, function(a, b)
      return a - b
    end)

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

  return moonsTeff, overlapPenalty
end

---@param starAgeGY number
---@param scan scan
---@param moons table<number, scan>
-- This is an approximation of the DW3 Habitability Scorecard https://justbearli.short.gy/DW3Earth2Submission.
-- It's pretty close. Caveats wrt to moons:
-- * It only considers direct child moons. No binary or nested moons.
-- * It has a bug somewhere resulting in the Moon not being correctly calculated.
-- It was later adjusted based on the (lengthy) discussion here: https://discord.com/channels/125106523037761536/1472013693536571447
-- TODO: Handle binary moons (ie those behind a barycenter) and nested moons?
-- TODO: Handle ELMoons
function ComputeHabitableScore(starAgeGY, scan, moons)
  local nonO2fraction = ComputeNonO2Fraction(scan)
  local moonsTeff, overlapPenalty = ComputeMoonsTeff(scan, moons)

  local subscores = DebugValue("Gravity", GaussianScore(0.7, 1.3, 1, gravityAsG(scan.SurfaceGravity)))
  subscores = subscores + DebugValue("O2 %", GaussianScore(0.6, 0.95, 0.79, nonO2fraction))
  subscores = subscores + DebugValue("Surf Pressure", GaussianScore(0.5, 2, 1, pressureAsAtm(scan.SurfacePressure)))
  subscores = subscores + DebugValue("Surf Temperature", GaussianScore(250, 320, 288, scan.SurfaceTemperature))
  subscores = subscores + DebugValue("Rotational period", GaussianScore(0.3, 4, 1, math.abs(periodAsDay(scan.RotationPeriod))))
  subscores = subscores + DebugValue("Orbital period", GaussianScore(200, 700, 365, math.abs(periodAsDay(scan.OrbitalPeriod))))
  subscores = subscores + DebugValue("Axial tilt", GaussianScore(0.05, 0.7, 0.41, math.abs(scan.AxialTilt)))
  subscores = subscores + DebugValue("Radius", GaussianScore(4500, 8000, 6371, distanceAsKm(scan.Radius)))
  subscores = subscores + DebugValue("Metal %", GaussianScore(10, 70, 32, scan.Composition.Metal * 100))
  subscores = subscores + DebugValue("Star age", GaussianScore(1, 9, 4.6, starAgeGY))
  subscores = subscores + DebugValue("Moons Teff", (GaussianScore(174, 314, 234, moonsTeff) * (1 - (math.clamp(overlapPenalty, 0, 1) ^ 1.5)))) -- 60, 200, 120

  local total = math.clamp((subscores / 11) * 100, 0, 100);
  if total >= 0 then
    local bodyShortName = scan.BodyName
    if string.startsWith(scan.BodyName, scan.StarSystem) then
      bodyShortName = scan.BodyName:gsub(scan.StarSystem:gsub("(%W)", "%%%1") .. ' ', '')
    end
    notifyForBody(
      string.format("Body %s", bodyShortName),
      "DW3 Earthlike habitability score",
      string.format("Score: %.1f; first discovery? %s", total, scan.ScanType ~= 'NavBeaconDetail' and not scan.WasDiscovered and not scan.WasMapped),
      scan.BodyID)
  end
end

---@param allBodies allBodies
function CheckHabitableScores(allBodies)
  local lowestBodyID = allBodies.Count
  local starAgeGY = 0

  for i,s in ipairs(DW3ElwStarScans) do
    if s.BodyID < lowestBodyID then
      lowestBodyID = s.BodyID
      starAgeGY = s.Age_MY / 1000
      if s.BodyID == 0 then break end
    end
  end

  for i, v in ipairs(DW3ElwScans) do
    ComputeHabitableScore(starAgeGY, v, DW3ElwMoons[v.BodyID])
  end
end
---@End

---@AllBodies
CheckHabitableScores(allBodies)
---@End

---@Complex DW3 Earth-like Habitability Score (collector)
  -- To accomplish this, maybe I need to collect all scans, barycentres and capture the parent lists here (since they're not available elsewise)
  if DW3ElwId64 ~= scan.SystemAddress then
    DW3ElwStarScans = {}
    DW3ElwScans = {}
    DW3ElwMoons = {}
    DW3ElwId64 = scan.SystemAddress
  end

  if isStar(scan) then
    table.insert(DW3ElwStarScans, scan)
  end
  if isPlanet(scan) and scan.PlanetClass == "Earthlike body" and scan.TerraformState == '' then
    table.insert(DW3ElwScans, scan)
  end
  if isPlanet(scan) and parents and parents[0].ParentType == "Planet" then
    if DW3ElwMoons[parents[0].Body] == nil then DW3ElwMoons[parents[0].Body] = {} end
    table.insert(DW3ElwMoons[parents[0].Body], scan)
  end
---@End
