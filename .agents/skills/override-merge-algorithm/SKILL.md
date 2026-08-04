---
name: override-merge-algorithm
description: The required approach for merging theme/template overrides.
---
# Skill â€” Theme/Template Override Merge (exact algorithm)

This is the single implementation used by theme engine, template engine, and page layout â€” do not write a second version of this logic anywhere in the codebase. Import from `packages/theme-engine`.

## 1. The Algorithm

```ts
import deepmerge from 'deepmerge';

interface MergeResult<T> {
  resolved: T;
  conflicts: string[]; // dot-paths where base removed a key the override still references
}

export function resolveOverride<T extends Record<string, unknown>>(
  base: T,
  override: Partial<T>,
): MergeResult<T> {
  const conflicts: string[] = [];

  // detect conflicts BEFORE merging: override references a path base no longer has
  detectConflicts(base, override, '', conflicts);

  const resolved = deepmerge(base, override, {
    arrayMerge: (target, source) => source, // override arrays replace, never concatenate
  }) as T;

  return { resolved, conflicts };
}

function detectConflicts(base: any, override: any, path: string, conflicts: string[]) {
  for (const key of Object.keys(override ?? {})) {
    const nextPath = path ? `${path}.${key}` : key;
    if (!(key in (base ?? {}))) {
      conflicts.push(nextPath); // override touches a key base no longer defines
      continue;
    }
    if (typeof override[key] === 'object' && override[key] !== null && !Array.isArray(override[key])) {
      detectConflicts(base[key], override[key], nextPath, conflicts);
    }
  }
}
```

## 2. Required Behavior (test these exactly â€” see `.agent/rules/04-testing-requirements.md` Â§5)

| Scenario | Expected result |
|---|---|
| `base = {a: 1, b: 2}`, `override = {}` | `resolved = {a: 1, b: 2}`, `conflicts = []` |
| `base = {a: 1, b: 2}`, `override = {b: 5}` | `resolved = {a: 1, b: 5}`, `conflicts = []` |
| `base_v2` removes key `c` that `override` still sets | `conflicts = ['c']` â€” surface this to the merchant/admin, never silently drop or crash |
| `override.colors = ['red']`, `base.colors = ['blue','green']` | `resolved.colors = ['red']` (arrays replace, never merge/concat) |

## 3. Usage Pattern â€” Theme

```ts
// packages/theme-engine/resolveTheme.ts
export async function resolveTenantTheme(ctx: TenantContext, cache: TenantCacheService): Promise<ResolvedTheme> {
  const cacheKey = `${ctx.tenantId}:theme:resolved`;
  const cached = await cache.get(cacheKey);
  if (cached) return cached;

  const base = await themeBaseRepo.findById(ctx.theme.themeBaseId);
  const override = await themeOverrideRepo.findByTenant(ctx); // ctx.tenantId scoped
  const { resolved, conflicts } = resolveOverride(base.tokensJson, override?.overridesJson ?? {});

  if (conflicts.length) logger.warn(`Theme conflicts for tenant ${ctx.tenantId}`, conflicts);

  await cache.set(cacheKey, resolved, { ttlSeconds: 3600 });
  return resolved;
}
```

## 4. Cache Invalidation â€” Mandatory on Every Override Write

```ts
async function saveThemeOverride(ctx: TenantContext, overrides: object) {
  await themeOverrideRepo.upsert(ctx, overrides);
  await cache.delete(`${ctx.tenantId}:theme:resolved`); // MUST invalidate, every write, no exceptions
}
```

## 5. Same Pattern for Templates/Page Layouts

`resolveOverride()` is generic â€” reuse it identically for `template_base` + `template_tenant_override`, and for page-section publish/draft resolution. Do not write a parallel merge function for these; if the shape genuinely differs, extend `resolveOverride`'s generics, don't fork it.

