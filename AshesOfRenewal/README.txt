ASHES OF RENEWAL - Guild Hub addon
==================================

INSTALL
  Copy the "AshesOfRenewal" folder to:
  World of Warcraft/_retail_/Interface/AddOns/
  Then /reload or restart the game.

USE
  /aor            open or close the hub (also the minimap flame button)
  /aor toasts     turn all alerts on or off
  /aor online     turn just the "guildmate is online" alerts on or off
  Gear button     in the window header: the same options plus the minimap button
  /aor minimap    show or hide the minimap button
  /aor rank       show your guild rank and whether you can post
  /aor names      print how this client writes character names (for troubleshooting)

FEATURES
  The window uses a sidebar (Guild / Raid / Officers). Officer sections only show for
  ranks allowed to post. Sections marked as planned are placeholders for now.

  Hearth (Home)    headline tagline, online/events/news stats, next event with countdown,
                   server timers (server time, daily and weekly reset), MOTD, guild info,
                   latest announcement, copyable links. Officers also get a Needs Attention
                   strip: no upcoming event, online members without the addon or on an
                   older version, members inactive 30+ days.
  Ember Reserve    Reserves: officers build the item pool by shift-clicking item links into
                   the box, members reserve (max set by maxReserves). Hard Reserves: public
                   registry, officers lock an item to a player or BANK; those items skip
                   rolls, soft reserves and +1. Standings: lowest +1 wins, per season, with
                   an award history. Award button resolves a drop (hard reserve, then lowest
                   +1, then open roll). Reserves auto-lock lockMinutes before the next
                   Conclave event; officers can lock/unlock manually and use New Session
                   after each raid to clear soft reserves.
  The Forge        Guild crafting ledger. Open each profession window once; your learned
                   recipes are catalogued by profession and tier and shared with guildmates
                   running the addon (they cache what they receive). Find a recipe, see which
                   crafters have it (online ones first), click to whisper one. Recipes linked
                   in guild/officer chat are also noted, marked "linked in chat".
                   Crafters tab: click a profession chip to open that guildmate's profession
                   window (retail: main professions only). Retail scans skip recipe categories
                   named in forgeIgnore (default: Appendix, which only holds explanations).
  Commission       Craft request board. Anyone can pin a request (type a recipe name, or
                   shift-click a recipe/item link), with a processing fee and flags (mats
                   provided, urgent, for raid). Crafters are found through the Forge ledger;
                   cards show which crafters are online, and the side panel lists online
                   crafters with how many open requests they can fill. Crafters Claim and
                   mark Done; the requester or an officer can cancel. Max 5 open requests
                   per member; requests expire after 14 days.
  Ember Watch      Raid attendance history. An officer in a raid group during a Conclave event
                   (30 min before to 6 h after the start) is recorded automatically: a roster
                   snapshot every 5 minutes, guild members only. Press Start Tracking for an
                   unscheduled raid. Members tab: raids attended, percentage bar, current
                   streak and last raid, over 30 days / last 10 raids / all time. Raids tab:
                   each recorded raid with its attendee list (officers can add someone who
                   was missed, or delete a session). Someone counts as present after
                   vaultDefaultMin low-stock threshold for newly tracked items (Ash Vault)
  attendMinSeen snapshots (default 2).
  Cinder           Raid prep check. Lists everyone in your raid or party with the consumables
                   they have active (flask/phial/elixir, food, augment rune) and the time
                   left; red = missing, orange = under 10 minutes. Summary boxes show how
                   many have each one, click PLAYER or GRP to sort, "Only show missing"
                   filters, and officers get Announce Missing (posts to raid/party chat).
                   Offline players are skipped; if the game hides someone's buffs it shows ?.
                   What counts as a consumable is the cinder table in Core.lua.
  Ash Vault        Officers only. Guild bank stock ledger: shift-click flasks, potions and
                   stones into the box to track them, each with a low-stock threshold (edit it
                   in the LOW AT column). Whenever an officer opens the guild bank, every tab
                   they can view is scanned and saved as a snapshot, shared with other officers
                   over the officer addon channel, so stock can be checked in a raid without
                   opening the bank. Shows count, change since the previous snapshot and
                   OK / LOW STOCK / OUT OF STOCK. The Hearth flags items running low.
  Kindred (Roster) search, sort, online-only filter, class colors, last seen, notes,
          left-click = whisper, right-click = invite
  Conclave (Board) officer-posted events and announcements, synced between members
          through the guild addon channel. Members who log in later catch up
          automatically from whoever is online.
  Alerts  themed toasts when guildmates log in and when new posts arrive

CUSTOMISE (top of Core.lua)
  postRankNames rank names allowed to post and see officer sections, e.g. { "Council" }
  postRankMax   highest rank index also allowed (0 = GM, 1 = next rank, ...)
                Type /aor rank in game to see your own rank name and index.
  season        header chip text ("" to hide)
  vaultDefaultMin low-stock threshold for newly tracked items (Ash Vault)
  attendMinSeen snapshots needed to count as present at a raid (Ember Watch)
  forgeIgnore   recipe category words The Forge skips on retail (default "appendix")
  maxReserves   soft reserves per member (Ember Reserve)
  lockMinutes   minutes before a Conclave event that reserves lock
  tagline       headline on the Hearth
  links         Discord and website URLs shown on Home
  Theme colors  AOR.colors table in Core.lua

EVERYONE in the guild needs the addon installed to see the Board.

If WoW says the addon is out of date, bump the "## Interface:" number in
AshesOfRenewal.toc to the current client version (shown in the AddOns list
tooltip, or run /dump (select(4, GetBuildInfo()))).
