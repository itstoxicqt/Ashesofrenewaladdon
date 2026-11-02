ASHES OF RENEWAL - Guild Hub addon
==================================

INSTALL
  Copy the "AshesOfRenewal" folder to:
  World of Warcraft/_retail_/Interface/AddOns/
  Then /reload or restart the game.

USE
  /aor            open or close the hub (also the minimap flame button)
  /aor toasts     toggle "guildmate is online" and new-post alerts
  /aor minimap    show or hide the minimap button
  /aor rank       show your guild rank and whether you can post

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
  maxReserves   soft reserves per member (Ember Reserve)
  lockMinutes   minutes before a Conclave event that reserves lock
  tagline       headline on the Hearth
  links         Discord and website URLs shown on Home
  Theme colors  AOR.colors table in Core.lua

EVERYONE in the guild needs the addon installed to see the Board.

If WoW says the addon is out of date, bump the "## Interface:" number in
AshesOfRenewal.toc to the current client version (shown in the AddOns list
tooltip, or run /dump (select(4, GetBuildInfo()))).
