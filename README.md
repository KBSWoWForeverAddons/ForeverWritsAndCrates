# Forever Writs and Crates (`v1.2.0`)

A World of Warcraft: Forever addon for **Waylaid Crates** and **Craftsman's Writs** (Azeroth Commerce Authority / Durotar Supply and Logistics).

## Features

- **Auction House Side Panel & One-Click Purchasing**
  - Attaches next to the Auction House with **Writs** and **Crates** tabs.
  - **Writs tab** cycles between **Sort: Fast** (fastest travel time), **Sort: Bags** (closest in travel time to writs already in your bags/quest log), and **Sort: Cost** (cheapest gold / 100 rep).
  - Clicking any Crate or Writ opens the crate/writ **and all of its fill items together** in Blizzard's AH Browse list, highlights the cheapest fill material (or required writ item), and **automatically pre-fills the exact quantity needed**.
  - Built-in quick & exact AH scanner plus seamless **Auctionator** price integration.
- **Auto-Populated Reputation Goal & Unified Planner (`/fwc`)**
  - Automatically detects your current supply faction standing and sets the **next standing** as your goal (e.g., Friendly → Honored) with no manual number entry.
  - Compares **Fastest Route** vs. **Cheapest Plan** side-by-side (supporting 1 of each unique writ per day, stacking multiple different writs at the same NPC, and counting writs/items already in your bags).
  - Includes **Merchant's Favor** crate calculator, **By Zone** writ browser, and a **Quests** tab to selectively include open-world completed quest turn-ins (Dungeon & Raid quests excluded by default).
- **Zero-Setup Travel Routing & Guided Turn-in Arrow**
  - Assumes **all faction flight paths, boats, and zeppelins** are available out of the box—no visiting flight masters first.
  - Supports **Hearthstone**, **Druid Teleport: Moonglade**, **Shaman Astral Recall**, and all level-appropriate **Mage City Teleports**.
  - Includes approach waypoints for tricky mountain paths, tunnels, and cliff teleporters, plus an automatic **Check Mailbox** Step 1 reminder when you have uncollected AH purchases.
  - Integrates seamlessly with **TomTom** (hiding the built-in arrow when TomTom is installed so you only see one arrow) and Blizzard's native User Waypoint.
- **Tooltips & Minimap Button**
  - Enriches crate and writ tooltips with cost per favor / cost per 100 rep, travel time, fill options, and daily turn-in status.

## Slash Commands

| Command | Description |
|---|---|
| `/fwc` | Open or close the Planner & Calculator |
| `/fwc route` | Create a turn-in route for writs in your bags (plus selected completed quests) |
| `/fwc guide` | Toggle the Route Guide window |
| `/fwc panel` | Toggle the Auction House side panel |
| `/fwc scan [writs\|crates\|bagcrates\|all]` | Scan the Auction House |
| `/fwc quests` | Toggle including completed quest turn-ins in routes |
| `/fwc auto` | Toggle auto-accept & auto-turn-in for Craftsman's Writs |
| `/fwc minimap` | Show or hide the minimap button |
| `/fwc reset` | Clear scanned prices for this realm |
