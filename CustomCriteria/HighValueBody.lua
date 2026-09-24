-- A custom criteria that calls out any ELW, WW and AW. This is identical to the built-in High Value Body except
-- that you can disable it for already mapped bodies by setting `HighValueBody_ExcludeAlreadyMapped` to true in
-- the global section below.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-09-24.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Global - High Value Body
-- If set to false, this behaves identically to the built-in High Value Body criteria.
HighValueBody_ExcludeAlreadyMapped = true
---@End - High Value Body

---@Complex High Value Body
if HighValueBody_ExcludeAlreadyMapped and scan.WasMapped then
  return false
end

if scan.PlanetClass == "Ammonia world" or scan.PlanetClass == "Earthlike body" or scan.PlanetClass == "Water world" or (scan.TerraformState and #scan.TerraformState > 0) then
  local detail = scan.PlanetClass
  if (scan.TerraformState and #scan.TerraformState > 0) then
    detail = scan.TerraformState .. " " .. detail
  end
  if not scan.WasMapped then
    if not scan.WasDiscovered then
      detail = "Undiscovered " .. detail
    else
      detail = "Unmapped " .. detail
    end
  end
  return true, 'High-Value Body', detail
end
---@End High Value Body
