# Ashes of Renewal: Guild Hub

**One window for everything your guild does.** Ashes of Renewal is a guild management and raid-prep addon with a clean sidebar interface: roster, events, loot reserves, crafting, raid attendance, consumable checks and an officer-only bank ledger, all shared automatically between members who have it installed.

Open it with `/aor` or the flame button on your minimap.

> **Everyone in the guild needs the addon installed** to see shared data such as events, reserves and recipes.

---

## Features

### The Hearth: your guild at a glance
- Guild headline, members online, events this week and new announcements
- Next event with a live countdown (days, hours, minutes)
- Server timers: server time, daily reset and weekly reset
- Message of the Day, guild info, latest announcement and your guild links
- **Officers get a Needs Attention strip:** no event scheduled, online members without the addon or on an old version, members inactive 30+ days, unclaimed craft requests, low vault stock and more

### Kindred: roster
- Search by name, class, rank, zone or note, and sort any column
- Class colors, AFK/DND tags and last-seen times
- Left-click to whisper, right-click to invite

### Conclave: events and announcements
- Officers post raid events and announcements; everyone sees them in their own local time
- Synced between members automatically; people who log in later catch up

### Ember Reserve: loot priority
- Officers build the reservable item pool by **shift-clicking item links**
- Members reserve items (limit set by your guild)
- **Public hard reserves:** lock an item to a player or the guild bank; it skips rolls and +1 completely
- **Lowest +1 wins** standings with seasons and an award history
- One-click award resolver: hard reserve first, then lowest +1, with ties flagged for a roll-off
- **Reserves lock automatically** shortly before the next event starts, so nothing changes mid-raid

### The Forge: guild crafting ledger
- Open your profession windows once and your recipes are catalogued by profession and tier, then shared with the guild
- Search every recipe and see which crafters have it, online ones first; click to whisper them
- Recipes linked in guild chat are noted too
- Click a crafter's profession to open their profession window
- Retail: skips the explanation-only "Appendix" sections

### Commission: craft requests
- Pin a request (type a recipe name or shift-click a link) with a processing fee and flags: mats provided, urgent, for raid
- Cards show which crafters are online and able to make it; a side panel lists online crafters and how many open requests each can fill
- Crafters claim and complete requests; toasts tell crafters about requests they can fill and requesters when theirs is claimed

### Ember Watch: raid attendance
- An officer's addon records attendance automatically during scheduled events, or on demand for impromptu raids
- Per-member attendance percentage, current streak and last raid, over 30 days, the last 10 raids or all time
- A history of every raid with who was there

### Cinder: raid prep
- Everyone in your raid or party with their active **flask, food and rune**, and the time left on each
- Summary counts, sorting, "only show missing", and an officer button to announce who's missing what

### Ash Vault: officers only
- Track flasks, potions and stones with low-stock thresholds
- Scans the guild bank when an officer opens it and shares the snapshot over the officer channel, so stock can be checked mid-raid
- Shows count, change since the last snapshot and OK / LOW STOCK / OUT OF STOCK

### Alerts
- Themed toasts for new posts, loot awards and craft requests, plus guildmates coming online
- Turn alerts, or just the online ones, off from the gear button in the window header

---

## Commands

| Command | What it does |
|---|---|
| `/aor` | Open or close the hub |
| `/aor toasts` | Turn all alerts on or off |
| `/aor online` | Turn only the "guildmate is online" alerts on or off |
| `/aor minimap` | Show or hide the minimap button |
| `/aor rank` | Show your guild rank and whether you have officer access |

## Setup for your guild

Open `Core.lua` and edit the block at the top: which ranks count as officers, your Discord and website links, the headline text, reserve limits, how long before an event reserves lock, and which buffs count as consumables.

## Coming soon
Herald (officer news), Kindling (recruitment), Embers (kudos), and event RSVPs with role composition tracking.

## Compatibility
Retail and WoW Forever.

## Credits
Ember Reserve's feature set was inspired by the LootReserve addon.
