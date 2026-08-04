---
name: tenant-scoped-entity
description: Exact template for creating new tenant-owned tables, Prisma models, repositories, and isolation tests.
---
# Skill â€” Tenant-Scoped Entity (exact template)

Use this exact pattern for every new tenant-owned table. Do not deviate in field order, naming, or structure.

## 1. Migration Template

```sql
CREATE TABLE {table_name} (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  -- domain-specific columns here
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ  -- soft delete, nullable
);

CREATE INDEX idx_{table_name}_tenant ON {table_name} (tenant_id);
-- any additional composite index MUST lead with tenant_id:
CREATE INDEX idx_{table_name}_tenant_status ON {table_name} (tenant_id, status);
```

## 2. Prisma Schema Template

```prisma
model {EntityName} {
  id        String    @id @default(uuid())
  tenantId  String    @map("tenant_id")
  tenant    Tenant    @relation(fields: [tenantId], references: [id])
  // domain fields
  createdAt DateTime  @default(now()) @map("created_at")
  updatedAt DateTime  @updatedAt @map("updated_at")
  deletedAt DateTime? @map("deleted_at")

  @@index([tenantId])
  @@map("{table_name}")
}
```

## 3. TenantScopedRepository Base (implement once, reuse everywhere)

```ts
@Injectable()
export abstract class TenantScopedRepository<T> {
  constructor(
    protected readonly prisma: PrismaService,
    protected readonly modelName: string,
  ) {}

  private scope(ctx: TenantContext, where: object = {}) {
    return { ...where, tenantId: ctx.tenantId };
  }

  async findMany(ctx: TenantContext, where: object = {}): Promise<T[]> {
    return this.prisma[this.modelName].findMany({ where: this.scope(ctx, where) });
  }

  async findUnique(ctx: TenantContext, id: string): Promise<T | null> {
    const record = await this.prisma[this.modelName].findUnique({ where: { id } });
    if (record && record.tenantId !== ctx.tenantId) return null; // defense in depth
    return record;
  }

  async create(ctx: TenantContext, data: object): Promise<T> {
    return this.prisma[this.modelName].create({ data: { ...data, tenantId: ctx.tenantId } });
  }

  async update(ctx: TenantContext, id: string, data: object): Promise<T> {
    return this.prisma[this.modelName].update({
      where: { id_tenantId: { id, tenantId: ctx.tenantId } }, // compound guard where supported
      data,
    });
  }

  async softDelete(ctx: TenantContext, id: string): Promise<T> {
    return this.update(ctx, id, { deletedAt: new Date() });
  }
}
```

## 4. Concrete Example â€” ProductsRepository

```ts
@Injectable()
export class ProductsRepository extends TenantScopedRepository<Product> {
  constructor(prisma: PrismaService) { super(prisma, 'product'); }

  async findBySku(ctx: TenantContext, sku: string): Promise<Product | null> {
    return this.prisma.product.findFirst({ where: { tenantId: ctx.tenantId, sku } });
  }
}
```

## 5. Isolation Test â€” Copy This Exactly, Change Only the Repo/Entity Name

```ts
describe('ProductsRepository isolation', () => {
  it('never returns another tenant\'s rows', async () => {
    const tenantA = await testUtils.seedTenant();
    const tenantB = await testUtils.seedTenant();
    await repo.create(tenantA, { sku: 'A-1', name: 'Widget' });

    const resultsAsB = await repo.findMany(tenantB, {});
    expect(resultsAsB).toHaveLength(0);
  });
});
```

