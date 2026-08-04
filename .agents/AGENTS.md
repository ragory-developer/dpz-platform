# AGENTS.md — CommerceOS

This is the entrypoint file. Any AI coding agent (Claude Code, Cursor, etc.) opening this repo reads this file first, before touching any code. It exists so the agent never has to guess architecture, naming, or scope — every guess is a chance to drift from the spec.

## 0. What This Project Is

Multi-tenant e-commerce SaaS platform ("CommerceOS"). Five engines: Platform, Commerce, Experience, Business, Intelligence (see `02-architecture/01-system-architecture.md`). Currently in Phase 1 build (see `10-roadmap/02-phase1-mvp-spec.md`).

**Foundation: custom build, decided.** No OSS commerce core (Vendure/Medusa) is used — see `13-resources/01-reference-implementations-and-starters.md` Decision Log for why. `14-data-contracts/` is the literal source of truth for the Commerce Engine (REST APIs, Postgres/Prisma schema, `tenant_id`-column isolation). Never introduce GraphQL, Vendure/Medusa entities, or Channel-based tenancy concepts — that decision is closed, not a live option to reconsider mid-task.

## 1. Mandatory Pre-Flight & Brain Activation

**ACTIVATION MANDATE (THE MASTER BRAIN):**
Before analyzing or writing any code, you MUST invoke and apply the `commerce-os-architect` skill. This loads the Master Brain of the project, including the 5-Engine strategy and the Single Coding Convention (SCCE). You must operate under the `commerce-os-architect` persona at all times.

**CRITICAL DIRECTIVE:** You MUST NOT write or modify a single line of code until you have explicitly fetched and read all necessary documentation related to your task. Guessing, assuming, or working from memory is strictly prohibited. ANY agent (Claude Code, Cursor, Aider, etc.) operating in this repository MUST rigorously obey all documented constraints without exception.

1. This file
2. `.agent/rules/` — all four rule files, in order (01 through 04). These are hard constraints, not suggestions.
3. The specific engine doc for your task (`05-experience-engine/*` or `06-commerce-business-engines/*`)
4. `14-data-contracts/01-phase1-entities.md` — exact field names/types. **Never invent a field name.** If a field you need isn't there, add it to the contract doc in the same session, don't silently invent it in code only.
5. `11-build-guide/01-session-by-session-build-guide.md` — which session/milestone this task belongs to

## 2. The Absolute Rules (full detail in `.agent/rules/`)

1. No tenant-owned data is ever queried, cached, stored, or queued without a resolved `TenantContext`.
2. No module imports another module's entities/repositories directly — only its exported service interface.
3. No hardcoded plan/billing checks outside `/modules/platform`.
4. No hardcoded colors/spacing/typography — design tokens only.
5. No field, table, or API shape invented without first checking `14-data-contracts/`.
6. No new architectural pattern (new merge strategy, new isolation mechanism, new engine) without flagging it to the human first — see escalation rules §5 below.

## 3. If You're Uncertain

Uncertainty is not a green light to improvise. In order of preference:
1. Search this docs folder for the answer (`grep -r` across the doc set is legitimate and expected).
2. Check `14-data-contracts/` for the exact shape.
3. If genuinely undocumented, add a minimal, explicit note to the relevant doc proposing the answer, flag it clearly in your response to the human as "assumed X, please confirm," and proceed — don't block on trivial gaps, but never proceed silently on architectural ones (§5).

## 4. Never Hallucinate These

- Table/column names → `14-data-contracts/01-phase1-entities.md` is the only source of truth. Not the vision doc, not memory of "how e-commerce schemas usually look."
- API routes/shapes → `14-data-contracts/02-api-contracts.md`.
- Component prop shapes → `14-data-contracts/03-component-contracts.md`.
- Which package to use for X → `12-tech-stack-and-packages/02-package-catalog.md`. Do not suggest or install a library not listed there without flagging it.

## 5. Escalate, Don't Guess (mandatory stop conditions)

Stop and ask the human before proceeding if the task requires:
- Adding/changing a base design token
- Changing the tenant isolation mechanism (query-scoping, cache-keying, storage-prefixing)
- Changing the theme/template override-merge strategy
- Adding a new top-level engine or module
- Choosing between building a feature custom vs. using an adopted foundation's built-in equivalent (Vendure/Medusa)
- Any change touching auth, payments, or the checkout state machine's core transitions

## 6. Task Pipeline (`.tasks/`)

The project uses a strict task tracking system in the `.tasks/` directory (`backlog/`, `next/`, `in-progress/`, `completed/`). 
**Rule:** Before completing any task in `in-progress/` and marking it done, you MUST ensure that the `next/` folder contains at least one fully prepared task file for the next session. Never leave the pipeline empty.

## 7. Definition of Done for Any Task

- [ ] Tenant-scoping verified for any new tenant-owned data path
- [ ] No cross-module direct table/entity access introduced
- [ ] Data contract doc updated if any new field/endpoint/component prop was introduced
- [ ] Tests added per `.agent/rules/04-testing-requirements.md`
- [ ] Relevant doc updated if a new pattern was introduced (docs-with-code rule)
- [ ] Knowledge Graph updated: Run `npx @sentropic/graphify update ./` to keep the agent brain in sync if code or docs were modified.

## 7. File Map (quick index)

```
# Documentation (CommerceOS-Docs/)
.agent/AGENTS.md                              this file
.agent/rules/                                  hard constraints (read all 4 before coding)
.agent/skills/                                 exact code templates for recurring tasks
14-data-contracts/                             exact schemas — the anti-hallucination layer
11-build-guide/                                session-by-session execution plan
13-resources/                                  build-vs-adopt decision + OSS references
00-README.md                                   full doc index and reading order

# Live Project (root)
apps/api/                                      NestJS backend (REST API, Prisma, tenant resolution)
apps/storefront/                               Next.js storefront (SSR, tenant-facing)
apps/admin/                                    React + Vite admin dashboard (SPA, merchant-facing)
packages/design-tokens/                        light/dark token definitions
packages/components/                           shared UI component registry + cn() utility
packages/theme-engine/                         resolveOverride() merge logic (single implementation)
packages/shared-types/                         Zod schemas → inferred TS types (single source of truth)
packages/ui-config/                            shared Tailwind preset
apps/api/prisma/schema.prisma                  Phase 1 database schema (17 models, all tenant-scoped)
README.md                                      root project README with full structure reference
```



---


# Rule 01 — Tenant Isolation (STRICT)

This is the single most security-critical rule in the project. Violations are treated as sev-1, not style feedback.

## 1. The Mechanism, Exactly

```ts
// TenantContext — constructed ONCE per request, in middleware, never reconstructed downstream
interface TenantContext {
  tenantId: string;          // UUID
  plan: string;               // e.g. "starter" | "growth" | "enterprise"
  effectiveFlags: Set<string>;
  theme: { themeBaseId: string; overrides: Record<string, unknown> };
  locale: string;              // BCP-47, e.g. "en-US"
  currency: string;            // ISO 4217, e.g. "USD"
  permissions: string[];       // resolved permission keys for the current actor
  domain: string;
  storagePrefix: string;       // `tenant-${tenantId}/`
}
```

Resolution order (must happen in exactly this sequence, as NestJS middleware/guards, before any controller executes):

```
1. HostResolverMiddleware   — parse req.hostname → lookup tenant_domains → tenantId (or 404)
2. TenantContextMiddleware  — load tenant row, plan, flags, theme pointer → build TenantContext → attach to req
3. AuthGuard                — verify JWT → compare token.tenant_id === req.tenantContext.tenantId, reject on mismatch
4. PermissionGuard          — check req.tenantContext.permissions against route's required permission
5. (controller executes)
```

If step 1 fails to resolve a tenant: **hard 404, immediately, before any other middleware runs.** No default tenant. No "global" fallback. Ever.

## 2. Database Query Rule

Every tenant-owned entity's repository MUST extend the base scoped repository — never the raw ORM repository.

```ts
// CORRECT
@Injectable()
export class ProductsRepository extends TenantScopedRepository<Product> {
  constructor(prisma: PrismaService) { super(prisma, 'product'); }
}
// Internally, every findMany/findUnique/create/update/delete call
// auto-injects `where: { tenant_id: this.context.tenantId, ...userWhere }`

// WRONG — never do this for a tenant-owned table
const products = await this.prisma.product.findMany({ where: { sku } }); // NO tenant_id filter = LEAK
```

If a task requires querying a tenant table and `TenantScopedRepository` doesn't yet support the query shape needed, **extend the base class's capability — do not drop down to the raw client as a workaround.**

## 3. Cache Key Rule

```ts
// CORRECT
const key = `${ctx.tenantId}:products:featured`;
// WRONG
const key = `products:featured`; // no tenant prefix = cross-tenant cache poisoning
```

Enforce via a `TenantCacheService` wrapper — never call the raw Redis client with a hand-built key string in feature code.

## 4. Storage Path Rule

```ts
// CORRECT
const path = `${ctx.storagePrefix}products/${productId}/image.jpg`; // tenant-{id}/products/...
// WRONG
const path = `products/${productId}/image.jpg`;
```

## 5. Queue Job Rule

Every job payload interface MUST include `tenantId` as a required (not optional) field. Worker entrypoints reject any job missing it before processing:

```ts
interface JobPayload { tenantId: string; /* ...job-specific fields */ }

async function processJob(payload: JobPayload) {
  if (!payload.tenantId) throw new Error('Job rejected: missing tenantId'); // fail closed
  // ...
}
```

## 6. Global/Reference Tables — The Only Exception

Tables explicitly marked `@Global()` in the schema (countries, currencies, tax_rate_defaults, plans) have no `tenant_id` and are the ONLY tables allowed to skip this rule. Any new table defaults to tenant-scoped; marking it `@Global()` requires the same escalation as AGENTS.md §5.

## 7. Mandatory Test Pattern for Every New Tenant Table

```ts
describe('isolation: <table>', () => {
  it('never returns another tenant\'s rows', async () => {
    const tenantA = await seedTenant();
    const tenantB = await seedTenant();
    await seedRowFor(tenantA, /* data */);
    const resultsAsB = await repoAs(tenantB).findMany({});
    expect(resultsAsB).toHaveLength(0);
  });
});
```
This test is not optional. A PR adding a tenant table without this test fails review automatically, regardless of what else it does correctly.

## 8. Cross-Tenant Token Rejection Test (mandatory for every authenticated endpoint)

```ts
it('rejects a token minted for a different tenant', async () => {
  const tokenForTenantA = await login(tenantA);
  const res = await request(app)
    .get('/api/products')
    .set('Host', tenantB.domain)         // resolves TenantContext to B
    .set('Authorization', `Bearer ${tokenForTenantA}`); // token claims A
  expect(res.status).toBe(403);
});
```



---


# Rule 02 — Module Boundaries (STRICT)

## 1. The Five Engines Map to Five Top-Level Folders

```
/apps/api/src/modules/
  platform/       Tenant, Auth, RBAC, Billing, FeatureFlags
  commerce/       Catalog, Inventory, Cart, Checkout, Orders, Shipping, Tax
  experience/     Theme, Template, PageBuilder, ComponentRegistry
  business/       (Phase 3+ — empty scaffold in Phase 1)
  intelligence/   (Phase 4+ — empty scaffold in Phase 1)
```

A file that doesn't obviously belong to one of these five is mis-scoped. Stop and classify it correctly before writing it — do not create a sixth top-level category, do not put it in `common/` if it's actually business logic.

## 2. What "Module Boundary" Means, Exactly

Each module (e.g. `commerce/catalog`) exposes exactly one public surface: its `*.service.ts` files, decorated `@Injectable()`, exported from the module's `index.ts`. Everything else — entities, repositories, internal DTOs — is NOT exported and NOT imported by another module.

```ts
// CORRECT — commerce/orders/orders.service.ts calling into commerce/inventory
import { InventoryService } from '../inventory'; // public service interface
...
await this.inventoryService.reserveStock(variantId, qty, ctx);

// WRONG — reaching into inventory's internals directly
import { InventoryRepository } from '../inventory/inventory.repository'; // NEVER
import { ProductVariant } from '../inventory/entities/product-variant.entity'; // NEVER outside inventory module
```

If `orders` needs data shaped differently than what `inventory.service.ts` currently returns, the fix is to **add or extend a method on `InventoryService`** — not to import its entity and query it directly.

## 3. Cross-Module Communication: Two Patterns Only

**Synchronous need (caller needs a result now):** direct call to the other module's public service method.

**Side-effect / eventual consistency (caller doesn't need to wait):** emit a domain event, consumed by a listener in the other module.

```ts
// commerce/orders/orders.service.ts
async placeOrder(...) {
  const order = await this.ordersRepo.create(...);
  this.eventBus.publish(new OrderCreatedEvent({ tenantId: ctx.tenantId, orderId: order.id }));
  return order;
}

// business/reporting listens, doesn't block order placement, doesn't touch orders table directly
@EventHandler(OrderCreatedEvent)
async onOrderCreated(event: OrderCreatedEvent) { /* ... */ }
```

Never use a shared database transaction spanning two modules. If two writes must be atomic across modules, that's a signal the boundary is wrong — escalate rather than force a cross-module transaction.

## 4. Feature Flags — Platform Module Only

```ts
// CORRECT — anywhere in commerce/experience/business
if (ctx.hasFeature('inventory.advanced')) { ... }

// WRONG — anywhere outside modules/platform
if (ctx.plan === 'enterprise') { ... } // hardcoded plan check, banned outside platform module
```

## 5. Checklist Before Committing Any Cross-Module Code

- [ ] Am I importing anything other than a `*.service.ts` export from another module? If yes, stop.
- [ ] Could this be an event instead of a direct call? If the caller doesn't need the result synchronously, prefer the event.
- [ ] Does this belong in Business/ERP instead of Commerce? (e.g. warehouse transfers, procurement, accounting → Business, not Commerce — see `06-commerce-business-engines/02-business-erp-engine.md` §3 boundary rule)



---


# Rule 03 — Naming Conventions (STRICT — no deviation)

Consistency here is what lets an agent (or a new engineer) predict a name correctly instead of guessing. Deviating from these, even when the deviation "reads better," creates drift that compounds.

## Database

| Item | Convention | Example |
|---|---|---|
| Table names | snake_case, plural | `product_variants`, `order_items` |
| Column names | snake_case | `tenant_id`, `created_at`, `deleted_at` |
| Primary key | always `id`, UUID | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` |
| Foreign key | `{singular_table}_id` | `tenant_id`, `product_id`, `role_id` |
| Timestamps | `created_at`, `updated_at`, `deleted_at` (nullable, soft delete) | always `TIMESTAMPTZ` |
| Boolean columns | `is_` or `has_` prefix | `is_primary`, `has_variants` |
| Junction tables | `{a}_{b}` alphabetical | `product_categories` |

## Backend Code (NestJS)

| Item | Convention | Example |
|---|---|---|
| Entity class | PascalCase, singular | `ProductVariant` |
| Repository class | `{Entity}Repository` | `ProductVariantRepository` |
| Service class | `{Domain}Service` | `CatalogService`, `CheckoutService` |
| Controller class | `{Domain}Controller` | `CatalogController` |
| DTO class | `{Action}{Entity}Dto` | `CreateProductDto`, `UpdateOrderStatusDto` |
| Module folder | kebab-case, matches domain | `modules/commerce/catalog/` |
| Event class | `{Entity}{PastTenseAction}Event` | `OrderCreatedEvent`, `ThemeUpdatedEvent` |
| Guard/Interceptor | `{Purpose}Guard` / `{Purpose}Interceptor` | `TenantAuthGuard`, `AuditLogInterceptor` |

## Frontend Code (React/Next.js)

| Item | Convention | Example |
|---|---|---|
| Component file | PascalCase, matches export | `ProductCard.tsx` exports `ProductCard` |
| Component registry ID | `{kebab-name}.v{n}` | `hero.v1`, `product-grid.v2` |
| Hook | `use{Purpose}` | `useTenantTheme`, `useCartStore` |
| Zustand store | `use{Domain}Store` | `useCartStore` |
| Prop types | `{Component}Props` | `HeroProps` |

## Cache Keys

```
{tenantId}:{module}:{key}[:{subkey}]
```
Examples: `45:products:featured`, `45:theme:resolved`, `45:page:homepage:published`

## Feature Flags

```
{domain}.{capability}
```
Examples: `inventory.advanced`, `builder.dragdrop`, `marketing.campaigns`

## API Routes

```
/api/v1/{module}/{resource}[/{id}][/{sub-resource}]
```
Examples: `/api/v1/catalog/products`, `/api/v1/commerce/orders/:id/refund`

Tenant is NEVER in the URL path (it's resolved from the Host header, not a route param) — `/api/v1/catalog/products` is correct; `/api/v1/tenants/:tenantId/products` is wrong and a signal something bypassed the TenantContext resolution.

## Environment Variables

```
{APP}_{CONCERN}
```
Examples: `API_DATABASE_URL`, `API_REDIS_URL`, `STOREFRONT_CDN_URL`

## Git Branches

```
{type}/{short-description}
```
Types: `feat/`, `fix/`, `chore/`, `refactor/`. Example: `feat/theme-override-merge`

## Commit Messages

Conventional Commits format: `{type}({scope}): {description}`. Example: `feat(commerce): add stock reservation on checkout`



---


# Rule 04 — Testing Requirements (STRICT — PR blocks without these)

No task is "done" without the tests below. This is not aspirational — treat a missing required test as a build error, not a suggestion.

## 1. New Tenant-Owned Table → Mandatory

- Isolation regression test (Rule 01 §7) — non-negotiable, every single tenant table, no exceptions for "small"/"internal" tables.

## 2. New Authenticated Endpoint → Mandatory

- Happy path test (valid request → expected response)
- Cross-tenant token rejection test (Rule 01 §8)
- Permission-denial test (actor without required permission → 403)
- Input validation test (malformed DTO → 400, not a 500 or silent pass-through)

## 3. New Component (Experience Engine) → Mandatory

- Unit test: given props, renders expected output/structure
- One snapshot test per declared variant
- a11y automated check (axe-core) — zero violations required, not "reduced"
- Token-only usage check: no hardcoded color/spacing value present in the component's styles (grep-checkable: no raw hex, no raw px outside the token file)

## 4. New Cross-Module Interaction → Mandatory

- Test asserting the caller only touches the callee's public service (i.e., mocking the callee's service in the caller's unit test — if the caller can't be tested with the callee's internals mocked out, the boundary is violated, per Rule 02)

## 5. New Merge/Override Logic (theme, template, page layout) → Mandatory

- Test: base + empty override → resolves to base unchanged
- Test: base + partial override → override wins only on overlapping keys, base fills the rest
- Test: base version bump with existing override present → override survives unchanged, no data loss
- Test: conflicting keys (base removes a key the override references) → must be flagged/handled explicitly, never silently dropped or silently crash

## 6. New Concurrency-Sensitive Path (stock reservation, checkout) → Mandatory

- Test: N concurrent requests against 1 unit of stock → exactly 1 succeeds, N-1 receive a clear "out of stock" error, no oversell
- Test: reservation TTL expiry releases stock back to available pool

## 7. Test File Location & Naming

```
{module}/
  {feature}.service.ts
  {feature}.service.spec.ts       ← unit tests, co-located
  {feature}.e2e-spec.ts           ← if the module has a dedicated E2E flow, in module's /test folder
```

## 9. What Counts as "Passing"

- All tests green in CI, not just locally.
- No test skipped/marked `.skip()`/`.todo()` merged into main without an explicit tracked reason and owner — an agent should never silently skip a failing test to make a PR look green.

## 9. Minimum Coverage Expectation (Phase 1)

Not a hard percentage gate (avoid coverage theater), but every Phase 1 milestone in `10-roadmap/02-phase1-mvp-spec.md` must have its "Done When" / acceptance criteria backed by an actual automated test, not a manual click-through claimed as verification.



---


# Rule 05 — Single Coding Convention (STRICT)

**All agents must enforce the Single Coding Convention (SCCE).**
- You must always apply the `single-coding-convention` skill when writing or modifying code.
- Preserve the existing architecture, naming, formatting, and patterns. 
- Never introduce new conventions, folder structures, utility styles, or alternative libraries unless explicitly approved. 
- Follow the exact guidelines laid out in the `single-coding-convention` skill without exceptions.



# Rule 06 — AI Documentation Loading (STRICT)

**All agents must strictly adhere to the AI engineering constitution.**
- You must always consult the rules in the `.ai/` directory before proceeding.
- The `.ai/SYSTEM.md` file defines the core mission and absolute rules.
- Review `.ai/CODING_STYLE.md`, `.ai/ARCHITECTURE.md`, `.ai/FOLDER_STRUCTURE.md`, `.ai/UI_GUIDELINES.md`, `.ai/API_CONVENTIONS.md`, `.ai/TESTING_GUIDELINES.md`, and `.ai/SECURITY_RULES.md` depending on the domain of your current task.
- Before completing any task, you must ensure compliance with `.ai/CODE_REVIEW_CHECKLIST.md`.
