# Changelog

## [v1.2.0] - 2026-11-21

### Added
- **Show: Bags** mode on the Auction House **Crates** tab — filters to unfilled crates currently in your bags, ranks them by best fill gold per Merchant's Favor, and displays `[In Bag]` / `[In Bag xN]` along with owned fill-material counts.
- Targeted bag-crate scanning: clicking **Scan** while in **Show: Bags** mode (or running `/fwc scan bagcrates`) scans only the unfilled crates in your bags and their fill items.
- **Merchant's Favor** tooltip line on **Sealed** / completed Waylaid Crates (e.g., `Sealed Journeyman Crate`, `Sealed Expert Crate`) showing how much Merchant's Favor they reward upon turn-in.

## [v1.1.0] - 2026-11-21

### Added
- **Sort: Bags** mode in the Auction House Writs tab — ranks buyable writs by shortest hop time from writs already in your bags or quest log, displaying the detour time (e.g., `+18s`) on each row.
- Automatic dynamic re-optimization of remaining stops after every writ or quest turn-in so nearby turn-ins in your current zone are always completed before leaving.
- Clear chat messages explaining why any writ in your bags was skipped when building a bag route.

### Changed
- Updated daily writ tracking to **1 of each unique writ per day** (per quest ID), allowing multiple different writs at the same NPC to stack together in a single stop for faster rep per minute.
- Cleaned up flight point labels by removing redundant zone names from capital cities and major towns (e.g., `Stormwind`, `Ironforge`, `Booty Bay`, `Ratchet`, `Gadgetzan`), while keeping zone names on outpost flight points.
- Increased zone-border crossing weighting in the travel optimizer to avoid unnecessary zone hopping.

### Fixed
- Prevented stray TomTom / map waypoints from popping up when the Route Guide window is closed or inactive; closing the Route Guide now immediately clears its active waypoint.
- Audited and corrected 8 Azeroth zone road-crossing coordinates (Thoradin's Wall between Hillsbrad and Arathi, Ashenvale↔Darkshore, Great Lift, Stormwind Gate, Redridge↔Burning Steppes, Searing Gorge↔Badlands, Hillsbrad↔Hinterlands, and Chillwind Pass), and removed an invalid land-road edge to Riverglades.

## [v1.0.0] - 2026-11-20

### Added
- Auction House side panel with **Writs** (sortable by Fastest Travel Time or Cheapest Gold/100 Rep) and **Crates** (sorted by Gold/Favor) tabs.
- One-click AH Browse list integration that displays crates/writs alongside their required items, highlights materials, and auto-fills commodity quantities.
- Built-in AH quick & exact price scanner with automatic **Auctionator** price overlay.
- Unified Planner (`/fwc`) with auto-populated reputation goals (automatically targets your next standing), Fastest Route vs. Cheapest Plan comparison, Merchant's Favor calculator, and By Zone view.
- Travel route engine assuming all faction flight paths, boats, zeppelins, and zone roads are available immediately, plus **Hearthstone**, **Druid Teleport: Moonglade**, **Shaman Astral Recall**, and **Mage City Teleports**.
- Selective completed quest turn-in integration (**Quests** tab) with Dungeon & Raid quests excluded by default.
- Approach waypoints for tricky mountain trails, tunnels, and teleporters, plus automatic mailbox reminder when uncollected AH purchases are waiting.
- Guided Route window with **TomTom** and native WoW waypoint integration, optional auto-accept/auto-turn-in for writs, item tooltips, and draggable minimap button.
