# Changelog

## 0.1.0

Initial release.

### Features

- Board and list views with drag-and-drop reordering (Sortable.js)
- Realtime file watching — edit TODO.md in your editor and the board updates instantly
- Two-way sync: changes in the UI write back to TODO.md
- Dynamic statuses derived from `## Heading` sections
- Task metadata: assignees (`@user`), PR links (`#pr:N`), attachments (`^path`)
- Inline task descriptions (indented lines under tasks)
- Task CRUD via modal dialogs
- Right-click context menus on board cards and list rows
- Auto-incrementing IDs with configurable prefix (e.g., `DEV-1`)
- GitHub integration (links to PRs and assignee profiles)
- Dark/light/system theme toggle
- Mobile responsive layout
- Parse warnings for malformed lines (resilient to bad edits)
- Ships as a mountable route (like LiveDashboard) — no asset config needed
- Dev mode (`dev: true`) for runtime asset serving during library development
- `mix dev_todo.init` setup task for quick project integration
