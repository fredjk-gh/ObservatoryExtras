-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which compares a scanned ELW against the details
-- of Earth (in-game) to derive a score measuring similarity. 0 is an exact match, higher is more different.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- Inspiration forum thread:    https://forums.frontier.co.uk/threads/how-close-to-earth-is-your-elw-a-scoring-method.354719/#post-10491979
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Global

-- For Similarity Score
---@class ReferenceBody
---@field Name string
---@field GravityG number
---@field TempK number
---@field PressureAtm number
---@field AtmoNitrogenPct number
---@field AtmoOxygenPct number
---@field AtmoArgonPct number
---@field AtmoWaterPct number
---@field OrbitalPeriodDays number
---@field RotationalPeriodDays number
---@field AxialTiltDegrees number
---@field Eccentricity number
---@field TidalLock boolean
---@field StarCount number
---@field MoonCount number
ReferenceBody = {}
function ReferenceBody:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

---@type ReferenceBody
Earth = ReferenceBody:new()
Earth.Name = "Earth"
Earth.GravityG =  gravityAsG(9.797759)
Earth.TempK = 288.0
Earth.PressureAtm = pressureAsAtm(101231.656250)
Earth.AtmoNitrogenPct = 77.886406
Earth.AtmoOxygenPct = 20.892998
Earth.AtmoArgonPct = 0.931637
Earth.AtmoWaterPct = 0.0
Earth.OrbitalPeriodDays = periodAsDay(31558150.649071)
Earth.RotationalPeriodDays = periodAsDay(86164.106590)
Earth.AxialTiltDegrees = 0.401426 * 180 / math.pi
Earth.Eccentricity = 0.016700
Earth.TidalLock = false
Earth.StarCount = 1
Earth.MoonCount = 1

---@type ReferenceBody
Mars = ReferenceBody:new()
Mars.Name = "Mars"
Mars.GravityG =  gravityAsG(3.697488)
Mars.TempK = 260.811890
Mars.PressureAtm = pressureAsAtm(233391.062500)
Mars.AtmoNitrogenPct = 91.169930
Mars.AtmoOxygenPct = 8.682851
Mars.AtmoArgonPct = 0.0
Mars.AtmoWaterPct = 0.095125
Mars.OrbitalPeriodDays = periodAsDay(59354294.538498)
Mars.RotationalPeriodDays = periodAsDay(88642.690263)
Mars.AxialTiltDegrees = 0.439648 * 180 / math.pi
Mars.Eccentricity = 0.093400
Mars.TidalLock = false
Mars.StarCount = 1
Mars.MoonCount = 0

---@param label string
---@param targetVal number
---@param referenceVal number
---@param posWeight number
---@param negWeight number
---@return number
function WeightedScore(label, targetVal, referenceVal, posWeight, negWeight)
    local factor = (targetVal - referenceVal) / referenceVal
    if factor >= 0 then
        return factor * posWeight
    else
        return factor * negWeight * -1
    end
end

-- Set to -1 to notify any score. Must be > 0 (zero is best score; ie. Earth).
MAXIMIUM_SIMILARITY_SCORE_FOR_NOTIFICATION=500

---@param scan scan
---@param ref ReferenceBody
function ComputeSimilarityScore(scan, ref)
    if isPlanet(scan) and scan.PlanetClass == "Earthlike body" then
        local starCount = 0 -- this is a naive count, not strictly parent stars.
        for body in bodies(system) do
            if isStar(body) then
                starCount = starCount + 1
            end
        end

        -- Failsafe: there needs to be at least 1 star. Nav beacon scans may send bodies out of order.
        if (starCount == 0) then starCount = 1 end
        local surfPressureAtm = pressureAsAtm(scan.SurfacePressure)

        local score = 0
        score = score + WeightedScore("g", gravityAsG(scan.SurfaceGravity), ref.GravityG, 25, 20)
        score = score + WeightedScore("st", scan.SurfaceTemperature, ref.TempK, 2, 1)
        score = score + WeightedScore("sp", surfPressureAtm, ref.PressureAtm, 1, 2)
        score = score + WeightedScore("ecc", scan.Eccentricity, ref.Eccentricity, 20, 0)
        score = score + WeightedScore("tl", (scan.TidalLock and 2 or 1), (ref.TidalLock and 2 or 1), 5, 1)

        -- TODO: Factor in absent materials? Arguably, if a material in the reference is not present on the comparable, then
        -- the comparable will have another material not present on the reference, so it's a wash.
        for atmoMat in materials(scan.AtmosphereComposition) do
            if atmoMat.name == "Nitrogen" and ref.AtmoNitrogenPct > 0 then
                score = score + WeightedScore("Np", surfPressureAtm * atmoMat.percent, ref.PressureAtm * ref.AtmoNitrogenPct, 1, 1)
            elseif atmoMat.name == "Oxygen" and ref.AtmoOxygenPct > 0 then
                score = score + WeightedScore("Oxp", surfPressureAtm * atmoMat.percent, ref.PressureAtm * ref.AtmoOxygenPct, 3, 5)
            elseif atmoMat.name == "Argon" and ref.AtmoArgonPct > 0 then
                score = score + WeightedScore("Ap", surfPressureAtm * atmoMat.percent, ref.PressureAtm * ref.AtmoArgonPct, 1, 1)
            elseif atmoMat.name == "Water" and ref.AtmoWaterPct > 0 then
                score = score + WeightedScore("Wp", surfPressureAtm * atmoMat.percent, ref.PressureAtm * ref.AtmoWaterPct, 1, 1)
            else
                score = score + 1 -- Non-existant material in the reference body's atmosphere.
            end
        end

        --- The next three can have negative values to begin with. We really only want to look at absolute differences.
        score = score + WeightedScore("op", math.abs(periodAsDay(scan.OrbitalPeriod)), ref.OrbitalPeriodDays, 1, 1)
        score = score + WeightedScore("rp", math.abs(periodAsDay(scan.RotationPeriod)), ref.RotationalPeriodDays, 10, 15)
        score = score + WeightedScore("at", math.abs(scan.AxialTilt * 180 / math.pi), ref.AxialTiltDegrees, 1, 1)

        -- mind the divide-by-zero for moonless reference bodies, so offset everything by 1. 0 moons = 1; 1 moon == 2. We're only considering relative difference.
        -- TODO: Counting moons is hard to do in custom criteria.
        --score = score + WeightedScore(moonCount + 1, ref.MoonCount + 1, 5, 20)
        score = score + WeightedScore("sc", starCount, ref.StarCount, 5, 0)
        return score
    end
    return -1
end
---@End

---@Complex Earth Similarity Score
local score = ComputeSimilarityScore(scan, Earth)
if score >= 0 and (MAXIMIUM_SIMILARITY_SCORE_FOR_NOTIFICATION < 0 or score > MAXIMIUM_SIMILARITY_SCORE_FOR_NOTIFICATION) then
    return true, string.format("Similarity Score: %s", Earth.Name), string.format("Score: %.2f", score)
end
---@End

---@Complex Mars Similarity Score
local score = ComputeSimilarityScore(scan, Mars)
if score >= 0 and (MAXIMIUM_SIMILARITY_SCORE_FOR_NOTIFICATION < 0 or score > MAXIMIUM_SIMILARITY_SCORE_FOR_NOTIFICATION) then
    return true, string.format("Similarity Score: %s", Mars.Name), string.format("Score: %.2f", score)
end
---@End
