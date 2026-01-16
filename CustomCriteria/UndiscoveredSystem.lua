-- A custom criteria for the Explorer plugin for Xjph/ObservatoryCore which watches for undiscovered systems.
--
-- More about Observatory Core: https://observatory.xjph.net/
-- More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
-- More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria
-- 
-- Author: Cmdr Coddiwompler
-- version 2026-01-15.1
-- More Observatory Extras: https://github.com/fredjk-gh/ObservatoryExtras

---@Simple Undiscovered System
scan.ScanType ~= 'NavBeaconDetail' and not isBarycentre(scan) and not scan.WasDiscovered and scan.DistanceFromArrivalLS == 0
