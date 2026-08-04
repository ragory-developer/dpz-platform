---
name: stock-reservation-algorithm
description: The mandatory implementation algorithm for stock reservations.
---
# Skill â€” Stock Reservation (exact concurrency-safe algorithm)

Oversell prevention is a hard requirement (vision doc Â§5). This is the one correct implementation â€” do not write an alternate version using naive read-then-write.

## 1. Schema Requirement

```sql
ALTER TABLE product_variants ADD COLUMN stock_available INT NOT NULL DEFAULT 0;
ALTER TABLE product_variants ADD COLUMN stock_reserved INT NOT NULL DEFAULT 0;

CREATE TABLE stock_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  variant_id UUID NOT NULL REFERENCES product_variants(id),
  order_id UUID REFERENCES orders(id),  -- null until order confirmed
  quantity INT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_stock_reservations_tenant ON stock_reservations (tenant_id);
CREATE INDEX idx_stock_reservations_expiry ON stock_reservations (expires_at) WHERE order_id IS NULL;
```

## 2. Reservation â€” Atomic Conditional Update (never read-then-write)

```ts
// WRONG â€” race condition between read and write
const variant = await repo.findUnique(ctx, variantId);
if (variant.stockAvailable >= qty) {
  await repo.update(ctx, variantId, { stockAvailable: variant.stockAvailable - qty }); // TWO requests can both pass the check
}

// CORRECT â€” single atomic conditional UPDATE, database enforces the guard
async function reserveStock(ctx: TenantContext, variantId: string, qty: number): Promise<boolean> {
  const result = await prisma.$executeRaw`
    UPDATE product_variants
    SET stock_available = stock_available - ${qty},
        stock_reserved = stock_reserved + ${qty}
    WHERE id = ${variantId}
      AND tenant_id = ${ctx.tenantId}
      AND stock_available >= ${qty}
  `;
  // result = number of rows affected; 0 means insufficient stock, someone else won the race
  if (result === 0) return false;

  await prisma.stockReservation.create({
    data: {
      tenantId: ctx.tenantId,
      variantId,
      quantity: qty,
      expiresAt: new Date(Date.now() + RESERVATION_TTL_MS),
    },
  });
  return true;
}
```

The `WHERE ... AND stock_available >= qty` clause is what makes this atomic and race-safe â€” Postgres guarantees only one concurrent transaction can satisfy the condition and decrement past zero. This replaces any need for explicit row locking in the application layer.

## 3. Release on Expiry (scheduled job, BullMQ)

```ts
// runs every minute
async function releaseExpiredReservations() {
  const expired = await prisma.stockReservation.findMany({
    where: { orderId: null, expiresAt: { lt: new Date() } },
  });
  for (const res of expired) {
    await prisma.$transaction([
      prisma.productVariant.update({
        where: { id: res.variantId },
        data: { stockAvailable: { increment: res.quantity }, stockReserved: { decrement: res.quantity } },
      }),
      prisma.stockReservation.delete({ where: { id: res.id } }),
    ]);
  }
}
```

## 4. Confirm on Order Placement

```ts
async function confirmReservation(ctx: TenantContext, reservationId: string, orderId: string) {
  await prisma.stockReservation.update({
    where: { id: reservationId },
    data: { orderId }, // no longer eligible for expiry release (see WHERE clause on the query above)
  });
}
```

## 5. Mandatory Test (see `.agent/rules/04-testing-requirements.md` Â§6)

```ts
it('allows exactly one of N concurrent reservations to succeed on last unit', async () => {
  await seedVariant({ stockAvailable: 1 });
  const attempts = Array.from({ length: 10 }, () => reserveStock(ctx, variantId, 1));
  const results = await Promise.all(attempts);
  expect(results.filter(Boolean)).toHaveLength(1);
});
```

## 6. Constant

```ts
const RESERVATION_TTL_MS = 15 * 60 * 1000; // 15 minutes â€” matches checkout session timeout, keep these two in sync
```

