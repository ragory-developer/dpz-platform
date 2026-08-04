# DPZ Platform Migration Guide & Tasklist

This document serves as the master checklist and technical guide for converting the DPZ React template into a production-ready Next.js application powered by the Halalmart backend ecosystem.

---

## Phase 1: Environment & Repository Setup
**Goal:** Initialize the new repositories and ensure the Halalmart engine is running under the DPZ branding.

- [ ] **1.1. Create DPZ Repositories**
  - Create a new root directory (e.g., `dpz-platform`).
  - Copy `halalmart-api` to `dpz-platform/dpz-api`.
  - Copy `halalmart-web` to `dpz-platform/dpz-web`.
- [ ] **1.2. Backend Branding & Configuration**
  - Update `package.json` names and scripts.
  - Modify `.env` variables (Database URL, Redis prefixes, JWT secrets).
  - Update email templates (`src/services/EmailService.ts` equivalent) to use DPZ logos and branding.
- [ ] **1.3. Frontend Branding & Configuration**
  - Update `package.json` and Next.js config.
  - Replace Halalmart logos with DPZ logos in `public/`.
  - Update global SEO metadata (Title, Description) in `src/app/layout.tsx`.

---

## Phase 2: Database & Schema Refactoring
**Goal:** Adjust the data models to fit DPZ's specific product offerings while keeping the core relational logic (Orders, Users, Cart) intact.

- [ ] **2.1. Audit Prisma Schema**
  - Review `Product`, `Category`, and `Order` models in `dpz-api/prisma/schema.prisma`.
  - *If DPZ sells digital products:* Add fields like `downloadUrl`, `fileSize`, `version`. Remove `weight`, `unit`, `shippingCost`.
  - *If DPZ sells physical products:* Keep existing models but adjust attributes/specifications to match DPZ's catalog.
- [ ] **2.2. Database Migration & Seeding**
  - Run `npx prisma db push` or `npx prisma migrate dev` to apply schema changes.
  - Update seed scripts (`seed-roles.ts`, etc.) to generate DPZ-specific mock data for testing.
- [ ] **2.3. Update API Controllers**
  - Adjust `ProductController.ts` and `OrderController.ts` to validate the new schema fields.

---

## Phase 3: Frontend "Reskinning" (Porting DPZ UI)
**Goal:** Rip out the Halalmart storefront UI and replace it with the React components from the DPZ template. Keep the Admin Panel completely intact.

- [ ] **3.1. Clean Slate Storefront**
  - Delete all consumer-facing pages inside `dpz-web/src/app/(store)/`.
  - Retain `layout.tsx` (for providers/auth wrappers).
- [ ] **3.2. Global Styles & Tailwind Configuration**
  - Merge DPZ's `index.css` and `tailwind.config.js` into the Next.js project.
  - Ensure CSS variables and design tokens (fonts, primary colors) match DPZ's brand.
- [ ] **3.3. Component Migration (JSX to TSX)**
  - Copy DPZ components (`Navbar`, `Footer`, `HeroSlider`, etc.) into `dpz-web/src/components/dpz/`.
  - Convert files from `.jsx` to `.tsx`.
  - Define strict TypeScript interfaces for component props.
- [ ] **3.4. Page Reconstruction**
  - Recreate the Next.js routes using the DPZ components:
    - `/` (Home page with sliders and product strips)
    - `/products` (Catalog/Search page)
    - `/product/[slug]` (Product Details)
    - `/cart` & `/checkout`

---

## Phase 4: Data Wiring & Logic Integration
**Goal:** Connect the newly ported DPZ UI components to the Halalmart data-fetching hooks and state management.

- [ ] **4.1. Authentication Wiring**
  - Connect DPZ's Login/Register Modals or Pages to the existing `useAuth()` hooks.
  - Ensure JWT tokens are stored and passed correctly.
- [ ] **4.2. Product Fetching**
  - Replace static mock data in DPZ's `CategoryGrid` and `NewArrivals` components with Halalmart's `useQuery` API calls.
  - Implement infinite scrolling or pagination on the Catalog page using `useInfiniteQuery`.
- [ ] **4.3. Cart & Order Flow**
  - Replace DPZ's local `CartContext` with Halalmart's server-synced cart logic (or local Zustand store, depending on architecture).
  - Wire up the DPZ Checkout UI to trigger the `createOrder` mutation in the backend.
- [ ] **4.4. Admin Panel Adjustments**
  - Update the Admin Panel product creation forms (`/admin/products/create`) to include the new fields added in Phase 2 (e.g., Digital Download URLs).

---

## Phase 5: Testing & QA
**Goal:** Ensure the reskinned application is stable, performant, and production-ready.

- [ ] **5.1. E2E Workflow Testing**
  - Test user registration -> product selection -> cart -> checkout -> order confirmation.
- [ ] **5.2. Admin Verification**
  - Verify that orders appear correctly in the Admin Dashboard.
  - Test product creation, editing, and soft-deletes (Trash Bin).
- [ ] **5.3. Performance Optimization**
  - Ensure DPZ images are optimized using Next.js `<Image />`.
  - Verify Server-Side Rendering (SSR) is working for the Home and Product pages to guarantee SEO performance.

> [!TIP]
> **How to Use This Guide:** We will tackle this one phase at a time. When you are ready, simply instruct me to "Start Phase 1" and provide the directory where you want the new DPZ workspace created.
