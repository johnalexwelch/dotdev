# Graph Report - dotfiles  (2026-06-04)

## Corpus Check
- 14 files · ~3,727 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 256 nodes · 246 edges · 22 communities (16 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `aeeb2b59`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]

## God Nodes (most connected - your core abstractions)
1. `search_categories` - 19 edges
2. `shortcuts` - 9 edges
3. `window` - 7 edges
4. `github.copilot.enable` - 5 edges
5. `plugin_settings` - 5 edges
6. `features` - 5 edges
7. `search` - 5 edges
8. `boosts` - 5 edges
9. `extensions` - 5 edges
10. `files.associations` - 4 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (22 total, 6 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.03
Nodes (77): breadcrumbs.enabled, cursor.ai.contextLength, cursor.ai.enabled, cursor.ai.provider, cursor.ai.temperature, cursor.cpp.disabledLanguages, dbt.dbtIntegration, dbt.enableModelDiagrams (+69 more)

### Community 1 - "Community 1"
Cohesion: 0.07
Nodes (29): accent, background, text, extensions, allowPermissions, autoUpdate, enabled, installed (+21 more)

### Community 2 - "Community 2"
Cohesion: 0.08
Nodes (24): excluded_locations, keyboard_shortcuts, finder_search, spotlight_search, priority_folders, search_categories, APPLICATIONS, BOOKMARKS (+16 more)

### Community 3 - "Community 3"
Cohesion: 0.14
Nodes (13): default, whenDimmed, devices, afterMinutes, enabled, enabled, haptic, sound (+5 more)

### Community 4 - "Community 4"
Cohesion: 0.14
Nodes (13): default, whenDimmed, devices, afterMinutes, enabled, enabled, haptic, sound (+5 more)

### Community 5 - "Community 5"
Cohesion: 0.14
Nodes (13): auto_dim, default_brightness, show_artwork, show_progress, show_percentage, auto_connect, show_meeting_info, installed_plugins (+5 more)

### Community 6 - "Community 6"
Cohesion: 0.15
Nodes (13): enabled, shortcut, defaultBackground, enabled, features, commandBar, easel, littleArcs (+5 more)

### Community 8 - "Community 8"
Cohesion: 0.29
Nodes (7): boosts, defaultDuration, enabled, notifications, showTimer, enabled, sound

### Community 9 - "Community 9"
Cohesion: 0.29
Nodes (7): cache, cookies, history, privacy, blockThirdPartyCookies, clearDataOnQuit, doNotTrack

### Community 10 - "Community 10"
Cohesion: 0.29
Nodes (7): window, closeTabPosition, newTabPosition, showFavicons, showTabBar, startupPage, tabBarPosition

### Community 11 - "Community 11"
Cohesion: 0.43
Nodes (4): is_conventional(), replace_subject(), warn_length(), commit-normalize.sh script

### Community 12 - "Community 12"
Cohesion: 0.40
Nodes (4): Default Profile, Development Profile, Required Plugins, StreamDeck Layout

### Community 13 - "Community 13"
Cohesion: 0.40
Nodes (5): github.copilot.enable, markdown, plaintext, scminput, yaml

### Community 14 - "Community 14"
Cohesion: 0.40
Nodes (5): source.organizeImports, [python], editor.codeActionsOnSave, editor.defaultFormatter, editor.formatOnSave

### Community 15 - "Community 15"
Cohesion: 0.50
Nodes (4): files.associations, *.html, *.sql, *.yml

### Community 16 - "Community 16"
Cohesion: 0.67
Nodes (3): notebook.cellToolbarLocation, default, jupyter-notebook

## Knowledge Gaps
- **193 isolated node(s):** `APPLICATIONS`, `SYSTEM_PREFS`, `DIRECTORIES`, `PDF`, `DOCUMENTS` (+188 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `features` connect `Community 6` to `Community 1`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Why does `github.copilot.enable` connect `Community 13` to `Community 0`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `APPLICATIONS`, `SYSTEM_PREFS`, `DIRECTORIES` to the rest of the system?**
  _193 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.02564102564102564 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06666666666666667 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._