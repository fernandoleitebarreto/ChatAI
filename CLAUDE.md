# ChatAI

## Project Overview

ChatAI is a standalone AI-powered chat assistant for the WolfePak ERP system. It is a Delphi project group (`ChatAI.groupproj`) with two sub-projects:

1. **Client** (`Client/ERP.dproj`) — FMX (FireMonkey) desktop app that provides a chat UI
2. **Server** (`Server/Server.dpr`) — VCL HTTP server (Horse framework) that proxies AI requests

The client sends user prompts to the server's REST endpoint, the server forwards them to an LLM (Claude or ChatGPT), and returns structured JSON responses rendered as text or a grid/table.

## Architecture

### Client (`Client/`)

- **Framework**: FMX (FireMonkey) — cross-platform UI
- **Entry point**: `ERP.dpr` → creates `TFrmAI` (chat form) and `TForm1` (main form with AI button)
- **Chat form** (`UnitAI.pas`): Tab-based UI with prompt input (Tab 1), text result (Tab 2), and grid/table result (Tab 3)
- **Loading overlay** (`Utils/uLoading.pas`): Reusable `TLoading` class providing a spinner overlay with background thread execution
- **HTTP client**: Uses `RESTRequest4D` to POST prompts to `http://localhost:3001/prompts`
- **Response routing**: Parses `{ "type": "text"|"array", "data": ... }` — text goes to a label, arrays populate a `TStringGrid` with dynamic columns

### Server (`Server/`)

- **Framework**: Horse (lightweight Delphi HTTP framework) with CORS and Jhonson (JSON) middleware
- **Listens on**: `localhost:3001`
- **Single endpoint**: `POST /prompts` — receives `{ "prompt": "..." }`, returns `{ "type": "text"|"array", "data": ... }`
- **Data module** (`Dm.Main.pas`): Creates a `TDm` per request, connects to a local SQLite database (`data.db`), reads AI provider config from `ChatAI.ini`
- **Database**: SQLite via FireDAC (`Conn: TFDConnection`), database file at `<exe-dir>/data.db`

### AI Provider System (`Server/Utils/`)

Uses a Strategy + Factory pattern with interface-based polymorphism:

| Unit | Purpose |
|---|---|
| `uAIProviderIntf.pas` | `IAIProvider` interface — `Send()`, Model, MaxTokens, SystemPrompt |
| `uAIProvider.pas` | `TAIProviderBase` abstract class + `TAIProviderFactory` |
| `uAIModels.pas` | Enums and helpers: `TAIProviderType`, `TChatGPTModel`, `TClaudeModel` |
| `uChatGPTProvider.pas` | `TChatGPTProvider` — OpenAI Chat Completions API |
| `uClaudeProvider.pas` | `TClaudeProvider` — Anthropic Messages API |
| `uChatGPT.pas` | Legacy standalone `TChatGPT` class (direct OpenAI integration) |
| `uClaude.pas` | Legacy standalone `TClaude` class (direct Anthropic integration, Portuguese prompts) |

**Provider selection** is configured via `ChatAI.ini` (next to the server exe):

```ini
[AI]
Provider=Claude       ; or ChatGPT
ApiKey=sk-...         ; API key for the selected provider
```

**Supported models**:
- Claude: Opus 4.6, Sonnet 4.6 (default), Haiku 4.5
- ChatGPT: GPT-4o (default), GPT-4o Mini, GPT-4 Turbo, o3-mini

### System Prompt

The shared system prompt (in `uAIProvider.pas`) instructs the LLM to always return JSON with `"type"` and `"data"` keys, matching the client's expected response format.

## Request Flow

```
User types prompt in FrmAI
  → Client POSTs { "prompt": "..." } to localhost:3001/prompts
    → Server creates TDm, reads ChatAI.ini for provider + API key
      → TAIProviderFactory creates TChatGPTProvider or TClaudeProvider
        → Provider builds request body, calls LLM API
          → Response text is parsed into { "type": "text"|"array", "data": ... }
    → Server returns JSON to client
  → Client routes to text label (Tab 2) or TStringGrid (Tab 3)
```

## Key Dependencies

- **Horse** — HTTP server framework
- **Horse.Jhonson** — JSON middleware for Horse
- **Horse.CORS** — CORS middleware
- **RESTRequest4D** — HTTP client library (used by both client and server provider layer)
- **FireDAC + SQLite** — Local database