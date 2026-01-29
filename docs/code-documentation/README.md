# YouTube Video Chat App - Code Documentation

Welcome to the comprehensive code documentation for the YouTube Video Chat App.

## What is this?

This documentation provides **line-by-line explanations** of the entire codebase, designed to help developers understand:

- How the application works
- Why certain design decisions were made
- How different components interact
- Best practices demonstrated in the code

## Quick Start

1. **New to the project?** Start with [00-OVERVIEW.md](./00-OVERVIEW.md)
2. **Looking for something specific?** Check [INDEX.md](./INDEX.md)
3. **Want to understand the architecture?** Read in numerical order

## Documentation Files

| # | File | Description |
|---|------|-------------|
| 00 | [OVERVIEW.md](./00-OVERVIEW.md) | Architecture and technology stack |
| 01 | [MIX-PROJECT.md](./01-MIX-PROJECT.md) | mix.exs configuration |
| 02 | [APPLICATION.md](./02-APPLICATION.md) | OTP application and supervision |
| 03 | [REPO.md](./03-REPO.md) | Database repository |
| 04 | [ROOMS-CONTEXT.md](./04-ROOMS-CONTEXT.md) | Business logic |
| 05 | [ROOM-SCHEMA.md](./05-ROOM-SCHEMA.md) | Database schema |
| 06 | [ROOM-SERVER.md](./06-ROOM-SERVER.md) | GenServer state management |
| 07 | [ACCOUNTS.md](./07-ACCOUNTS.md) | User management |
| 08 | [ENDPOINT.md](./08-ENDPOINT.md) | HTTP/WebSocket configuration |
| 09 | [ROUTER.md](./09-ROUTER.md) | URL routing |
| 10 | [ROOM-LIVE-SHOW.md](./10-ROOM-LIVE-SHOW.md) | Main LiveView |
| 11 | [ROOM-LIVE-TEMPLATE.md](./11-ROOM-LIVE-TEMPLATE.md) | HEEx template |
| 12 | [PRESENCE.md](./12-PRESENCE.md) | User presence tracking |
| 14 | [APP-JS.md](./14-APP-JS.md) | JavaScript player logic |

## Key Concepts

### Elixir/Phoenix Patterns
- **GenServer** - Process-based state management
- **PubSub** - Real-time event broadcasting
- **LiveView** - Server-rendered reactive UI
- **Contexts** - Business logic organization

### Frontend
- **YouTube IFrame API** - Video playback control
- **SoundCloud Widget API** - Audio playback
- **LiveView Hooks** - JS/Elixir integration

## Technology Stack

- **Backend**: Elixir, Phoenix 1.7, Ecto
- **Frontend**: Phoenix LiveView, TailwindCSS, JavaScript
- **Database**: PostgreSQL
- **Real-time**: Phoenix PubSub, Presence

## Contributing to Documentation

When adding new documentation:
1. Follow the existing format
2. Include line-by-line explanations
3. Add diagrams for complex flows
4. Cross-reference related files
5. Update INDEX.md

---

*Last updated: January 2025*
