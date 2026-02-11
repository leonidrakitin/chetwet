# Chatwoot Contribution Guidelines for Claude

## Before Writing Any Code

- Always read surrounding code first (same folder, parent classes, concerns, similar services/controllers).
- Follow existing patterns over “best practice” from outside. **Chatwoot conventions > generic Rails/Vue patterns**.
- Prefer consistency with nearby code over architectural perfection.
- If a similar feature already exists — mirror its structure.

## 🔁 Change Strategy

- Default to **surgical changes**, not rewrites.
- Do not refactor unrelated code while implementing a feature.
- Avoid renaming methods, variables, or files unless absolutely required.
- Preserve public APIs, params, and response shapes unless explicitly told otherwise.
- If a change might affect other flows — leave a short `TODO:` comment instead of expanding scope.

## 🧩 Rails Architecture Rules

### Controllers
- Keep controllers thin.
- Business logic → Services (`app/services/`)
- Param sanitization → private strong params methods
- Rendering → Use existing serializers / jbuilder / patterns already in that controller namespace.

### Services
- One public method: `call`
- Initialize with dependencies, not raw params hashes when possible.
- No controller-specific logic in services (no render, no params, no session).
- Side effects (jobs, events, notifications) should be obvious and near the bottom of `call`.

### Models
- Prefer scopes over class methods for queries.
- Avoid fat models; complex workflows belong in services.
- Always consider:
  - indexes
  - null constraints
   - foreign keys
- If adding a column used in queries → mention index in migration.

### Background Jobs
- Use jobs for:
  - external API calls
  - emails
  - heavy processing
- Jobs must be idempotent when possible.

## 🧪 Specs Philosophy (Important)

Claude should **not add tests unless asked**, but when editing code:
- Do not break existing specs
- Read failing spec expectations before changing logic
- When fixing a spec, prefer adjusting implementation over rewriting the test (tests describe intended behavior)

## 🌍 API & Serialization Rules

- Never change response JSON shape without clear instruction
- Use existing serializers if present
- Maintain:
  - key casing style
  - nesting structure
  - pagination format
- Backward compatibility is more important than elegance.

## 🎨 Vue Frontend Rules (Chatwoot-specific)

- Match existing component structure in the same directory.
- Do not introduce new state libraries or patterns.
- Reuse:
  - existing composables
  - store modules
  - UI components
- API calls must go through existing request helpers / API layers, not raw fetch.

### Component Changes
- Prefer adding props/events over rewriting component internals.
- Do not move business logic into components if it already lives in stores/composables.

## 🧱 Migrations & Data Safety

When generating migrations:
- Always assume production data exists
- Avoid destructive changes
- For defaults on large tables: prefer backfill + constraint instead of single-step default with lock
- Never drop columns/tables unless explicitly asked

## 🚫 Things Claude Must Avoid

- ❌ Large refactors
- ❌ Introducing new gems or npm packages
- ❌ Reformatting entire files
- ❌ Changing unrelated tests
- ❌ Converting code style (e.g., hash rockets ↔ symbols) just for style
- ❌ Adding premature abstractions
- ❌ Adding comments that explain obvious Ruby/Vue syntax

## ✅ What Good Changes Look Like

A good change in this repo:
- Touches as few files as possible
- Looks like it was written by the original Chatwoot authors
- Doesn’t introduce new patterns
- Is easy to revert
- Solves only the requested problem

## 💬 How Claude Should Explain Code

When generating explanations:
- Be concise
- Reference file paths
- Explain **why** a change is done, not what Ruby/Vue syntax means
- Call out side effects (jobs, callbacks, broadcasts, emails)

## 🏁 Definition of Done (Claude Internal Checklist)

Before suggesting code, Claude should internally verify:
- Matches local project patterns
- No accidental N+1 queries introduced
- No breaking API response shapes
- No business logic added to controllers
- No styling outside Tailwind
- No new dependencies
- Enterprise compatibility considered

## Feature Flags & Conditional Behavior

Chatwoot часто включает функциональность постепенно или только для части инсталляций.

- Prefer feature flags over hardcoded conditionals.
- Check existing patterns before adding new flags:
  - `Flipper.enabled?(:feature_name, account)`
  - `Current.account.feature_enabled?(:feature_name)` (if account-scoped)
- Feature flags should:
  - Be checked in policies, services, or controllers, not deep inside views/components
  - Default to safe/off behavior
  - Not scatter flag checks everywhere — gate at entry points of flows.

## Account-Scoped Settings

Most behavior in Chatwoot is account-driven.

When adding configurable behavior:
- Prefer:
  - `account.settings[:your_setting]`
  - or existing typed accessors if present
- Add defaults in a way that:
  - Existing accounts don’t break
  - Nil values fall back gracefully
- UI setting → API → persisted in `account.settings`
- Avoid:
  - Global constants for account-level behavior
  - Environment variables for per-account logic

## Inbox-Level Customization

Inbox is a common extension point.

When behavior differs per inbox:
- Store config on Inbox model (`inbox.settings` or dedicated column)
- Scope logic like: `return unless inbox.setting_enabled?`
- Avoid checking `channel_type` unless feature is truly channel-specific.

## Channel-Specific Logic

Channels (WhatsApp, WebWidget, API, etc.) extend behavior.

- Prefer polymorphism and existing channel services over `case channel_type`
- Look for:
  - `Channel::Base`
  - Channel-specific service objects
- If branching is unavoidable, isolate it in:
  - a service
  - or a channel concern
- Not scattered across controllers.

## Policies & Permissions

Authorization is policy-driven.

- Add permissions in Pundit policies, not inline in controllers.
- Reuse existing roles: `agent`, `administrator`, `owner`
- UI should reflect policy, not redefine it.
- Backend is source of truth for permissions.

## Events, Callbacks & Broadcasting

Chatwoot relies heavily on events.

When something important happens:
- Check for existing patterns:
  - `after_commit` callbacks
  - `Rails.configuration.dispatcher.dispatch`
  - `broadcast_replace_to` / `broadcast_append_to`
- Avoid putting broadcast logic in controllers.
- Prefer model callbacks or services triggering events.

## Background Processing Pattern

Use jobs when:
- Sending emails
- Calling external APIs
- Heavy calculations

Pattern:
- Service determines action
- Enqueue job
- Job performs external/heavy work

Avoid:
- External API calls directly inside controllers or models

## API Pattern

New endpoints should follow existing namespace and structure:
- `/api/v1/accounts/:account_id/...`

Use:
- `before_action :set_account`
- Pundit authorization
- Serializers for responses

Never:
- Return raw ActiveRecord objects
- Introduce a new version namespace casually

## Frontend Data Flow Pattern

Frontend usually flows like:
- API → Store/Composable → Component

Claude should:
- Put API calls in:
  - `api/` helpers or
  - Vuex/Pinia store actions (depending on area)
- Keep components focused on:
  - rendering
  - emitting events
- Avoid:
  - Fetching directly inside deeply nested UI components if similar logic exists elsewhere.

## UI Pattern for Settings & Toggles

For new toggles in UI:
- Backend:
  - Add setting to model (account or inbox)
  - API: Permit param, return in serializer
- Frontend:
  - Add toggle in settings page
  - Bind to store state
  - Persist via existing update action
- Do not invent a new settings storage flow.

## Adding New Services

Service naming pattern: `Namespace::ActionTargetService`

Examples:
- `Conversations::AutoAssignmentService`
- `Messages::ProcessAttachmentService`

Rules:
- One responsibility
- One public method: `call`
- No hidden side effects outside what the name implies

## Safe Schema Change Pattern

When Claude suggests DB changes:
- Safe:
  - Add column with null allowed
  - Backfill in background
  - Add constraint later (if needed)
- Risky (avoid unless asked):
  - Dropping columns
  - Renaming columns used widely
  - Changing column types on large tables

## How Claude Should Handle Uncertainty

If multiple implementation strategies exist:
- Choose the one most consistent with nearby code
- Avoid introducing new architectural patterns
- Mention assumptions briefly in explanation

**Consistency > theoretical purity.**