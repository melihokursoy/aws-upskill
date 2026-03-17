# UI Standards

## Stack

| Tool                       | Version | Purpose                                         |
| -------------------------- | ------- | ----------------------------------------------- |
| Tailwind CSS               | v4      | Utility-first CSS — configured via `@theme {}`  |
| shadcn/ui                  | —       | Unstyled Radix UI primitives + Tailwind classes  |
| class-variance-authority   | latest  | Type-safe component variant definitions          |
| clsx + tailwind-merge      | latest  | Conditional class merging without conflicts      |
| prettier-plugin-tailwindcss| latest  | Auto-sorts Tailwind classes on format            |
| Atomic design              | —       | `ui/` → `molecules/` → `organisms/` hierarchy   |

---

## Tailwind v4 Setup

Tailwind v4 removes the `tailwind.config.js` file. All design tokens live in `apps/web/app/global.css` inside the `@theme {}` block:

```css
@import 'tailwindcss';

@theme {
  --color-primary: oklch(55% 0.2 250);
  --color-primary-foreground: oklch(98% 0 0);
  --color-secondary: oklch(92% 0.01 250);
  --color-secondary-foreground: oklch(20% 0 0);
  --color-muted: oklch(96% 0.005 250);
  --color-muted-foreground: oklch(45% 0 0);
  --color-destructive: oklch(55% 0.22 25);
  --color-border: oklch(90% 0.005 250);
  --color-background: oklch(100% 0 0);
  --color-foreground: oklch(10% 0 0);

  --font-sans: 'Inter', ui-sans-serif, system-ui, sans-serif;
  --radius: 0.5rem;
}
```

These tokens become Tailwind utility classes automatically:

- `bg-primary`, `text-primary-foreground`
- `bg-muted`, `text-muted-foreground`
- `border-border`, `bg-background`, `text-foreground`
- `rounded-[--radius]` — references the `--radius` CSS variable directly

**To add a new token:** add a `--color-*` or `--*` entry to `@theme {}`. No config file changes needed.

---

## Component Hierarchy

```
apps/web/app/components/
├── ui/           — Primitive atoms (no business logic, no data fetching)
│   ├── button.tsx
│   ├── badge.tsx
│   ├── avatar.tsx
│   ├── dropdown-menu.tsx
│   └── separator.tsx
├── molecules/    — Composed atoms with light logic (e.g. auth state, user data)
│   ├── avatar-dropdown.tsx
│   └── auth-buttons.tsx
└── organisms/    — Full sections composed from molecules (e.g. page header)
    └── header.tsx
```

### Layer rules

| Layer       | May import            | May contain                      | May NOT contain             |
| ----------- | --------------------- | -------------------------------- | --------------------------- |
| `ui/`       | React, Radix, `cn()`  | Variants (CVA), accessibility    | Business logic, data fetch  |
| `molecules/`| `ui/`, `cn()`         | Local state, user props          | Global store, route changes |
| `organisms/`| `molecules/`, `ui/`   | Server-side data (`getUser()`)   | Inline styles               |

---

## Server vs Client Components

Next.js App Router defaults to **Server Components**. Add `'use client'` only when needed.

| Use Server Component when…                         | Use Client Component when…            |
| -------------------------------------------------- | ------------------------------------- |
| Component reads data (DB, headers, cookies)        | Component uses `useState` / `useEffect` |
| Component renders static or server-fetched content | Component handles browser events      |
| Component is in `organisms/` or a page             | Component uses browser-only APIs      |
| No interactivity needed                            | Component uses `usePathname` / router |

**Rule of thumb:** push `'use client'` as far down the tree as possible. Keep Server Components at the top (`organisms/`, pages) and Client Components at the leaves (`molecules/` when needed).

---

## `cn()` Utility

`cn()` from `apps/web/lib/utils.ts` combines `clsx` (conditional classes) with `tailwind-merge` (conflict resolution):

```typescript
import { cn } from '../lib/utils';

// Simple merge
cn('px-4 py-2', 'px-6')          // → 'py-2 px-6'  (px conflict resolved)

// Conditional classes
cn('base-class', isActive && 'bg-primary', isDisabled && 'opacity-50')

// Props override
cn(buttonVariants({ variant, size }), className)
```

**Always use `cn()` instead of string concatenation.** Manual concatenation breaks when Tailwind classes conflict (e.g. both `px-4` and `px-6` would both appear).

---

## CVA Variants Pattern

Use `class-variance-authority` for components with multiple visual variants:

```typescript
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '../lib/utils';

const buttonVariants = cva(
  // Base classes — always applied
  'inline-flex items-center rounded-[--radius] text-sm font-medium transition-colors',
  {
    variants: {
      variant: {
        default:   'bg-primary text-primary-foreground hover:bg-primary/90',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost:     'hover:bg-muted hover:text-foreground',
      },
      size: {
        default: 'h-9 px-4 py-2',
        sm:      'h-8 px-3 text-xs',
        lg:      'h-10 px-8',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

// Component props extend VariantProps to get full type safety
interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

function Button({ variant, size, className, ...props }: ButtonProps) {
  return (
    <button
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}
```

**The `className` prop always goes last in `cn()`** so consumers can override variant defaults.

---

## Tailwind Class Ordering

Class order is enforced automatically by `prettier-plugin-tailwindcss`. Never manually reorder classes — just run `prettier` (or save in an editor with format-on-save).

```bash
# Format all files
npx prettier --write .
```

The plugin follows Tailwind's recommended order: layout → flexbox/grid → spacing → sizing → typography → backgrounds → borders → effects.

---

## Accessibility Guidelines

- All interactive elements must be keyboard-accessible (Radix UI handles this for `dropdown-menu`, `avatar`)
- Use semantic HTML: `<button>` for actions, `<a>` for navigation
- Provide `aria-label` on icon-only buttons: `<button aria-label="Open menu">`
- Ensure color contrast meets WCAG AA: foreground/background pairs in `@theme {}` are chosen for ≥ 4.5:1 ratio
- Dropdown menus close on `Escape` and outside click (built into Radix `DropdownMenu`)
- Avatar images use `alt` text: seed user avatars use the username as `alt`

---

## Anti-patterns

| Anti-pattern                       | Why it's wrong                                  | Correct approach              |
| ---------------------------------- | ----------------------------------------------- | ----------------------------- |
| `style={{ color: 'red' }}`         | Bypasses Tailwind, not themeable                | Use `text-destructive`        |
| `"class1 " + "class2"`             | Breaks on conflicting utilities                 | Use `cn()`                    |
| `props: any` on component          | Loses type safety for variants and HTML attrs   | Extend `VariantProps<...>`    |
| Hardcoded hex/rgb colors           | Not responsive to theme changes                 | Use `@theme {}` tokens        |
| Client component for static content| Unnecessary JS bundle, blocks streaming SSR     | Default to Server Component   |
| Importing `organisms/` from `ui/`  | Violates atomic hierarchy, creates cycles       | Only import down the tree     |
