---
description: UI patterns for Ballee using MakerKit @kit/ui components, React Server Components, dark mode support, and admin CRUD pages. Use when building UI components, forms, tables, or admin pages.
---

# UI Patterns

## Component Priority

1. **@kit/ui first** - Check packages/@kit/ui/ before building custom
2. **Server components default** - Only `'use client'` when needed
3. **Dark mode support** - Use semantic color classes

## Common @kit/ui Components

```typescript
// Buttons
import { Button } from '@kit/ui/button';

// Forms
import { Form, FormField, FormItem, FormLabel, FormControl } from '@kit/ui/form';
import { Input } from '@kit/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@kit/ui/select';

// Layout
import { Card, CardContent, CardHeader, CardTitle } from '@kit/ui/card';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@kit/ui/dialog';

// Data Display
import { DataTable } from '@kit/ui/enhanced-data-table';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@kit/ui/table';
import { Badge } from '@kit/ui/badge';

// Feedback
import { toast } from '@kit/ui/sonner';
```

## Table Component (IMPORTANT)

The `Table` component from `@kit/ui/table` **already includes a border wrapper**. Do NOT wrap it with an additional `<div className="rounded-md border">`.

```typescript
// ✅ CORRECT - Table has its own border
<Table>
  <TableHeader>
    <TableRow>
      <TableHead>Name</TableHead>
      <TableHead>Status</TableHead>
    </TableRow>
  </TableHeader>
  <TableBody>
    {items.map(item => (
      <TableRow key={item.id}>
        <TableCell>{item.name}</TableCell>
        <TableCell>{item.status}</TableCell>
      </TableRow>
    ))}
  </TableBody>
</Table>

// ❌ WRONG - Creates double border
<div className="rounded-md border">
  <Table>
    ...
  </Table>
</div>
```

**Why**: The Table component wrapper div has `rounded-lg border` built in (see `packages/ui/src/shadcn/table.tsx:11`).

## Server vs Client Components

```
Server Component (default):     Client Component ('use client'):
├─ Data fetching               ├─ onClick, onChange handlers
├─ Database access             ├─ useState, useEffect hooks
├─ Sensitive logic             ├─ Browser APIs (localStorage)
└─ No interactivity            └─ Real-time subscriptions
```

## Form Pattern

```typescript
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Form, FormField, FormItem, FormLabel, FormControl, FormMessage } from '@kit/ui/form';
import { Input } from '@kit/ui/input';
import { Button } from '@kit/ui/button';
import { toast } from '@kit/ui/sonner';

const schema = z.object({
  name: z.string().min(1, 'Required'),
  email: z.string().email(),
});

export function MyForm({ onSubmit }) {
  const form = useForm({
    resolver: zodResolver(schema),
    defaultValues: { name: '', email: '' },
  });

  const handleSubmit = async (data) => {
    const result = await onSubmit(data);
    if (result.success) {
      toast.success('Saved');
      form.reset();
    } else {
      toast.error(result.error.message);
    }
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Saving...' : 'Save'}
        </Button>
      </form>
    </Form>
  );
}
```

## Admin CRUD Page Pattern

```typescript
// page.tsx (Server Component)
import { AdminPageTemplate } from '@/components/admin/admin-page-template';
import { DataTable } from '@kit/ui/enhanced-data-table';
import { columns } from './columns';
import { loadItems } from './loader';

export default async function ItemsPage() {
  const items = await loadItems();

  return (
    <AdminPageTemplate
      title="Items"
      description="Manage items"
      createButton={{ label: 'Add Item', href: '/admin/items/new' }}
    >
      <DataTable columns={columns} data={items} />
    </AdminPageTemplate>
  );
}
```

## Styling & Dark Mode

### Semantic Colors (Auto Dark Mode)

Use semantic color tokens for general UI - they automatically switch in dark mode:

```typescript
// ✅ DO - Semantic colors (no dark: variants needed)
className="bg-background text-foreground"        // Base
className="bg-card text-card-foreground"         // Cards
className="bg-muted text-muted-foreground"       // Muted elements
className="bg-primary text-primary-foreground"   // Primary actions
className="bg-secondary text-secondary-foreground" // Secondary
className="bg-destructive text-destructive-foreground" // Destructive
className="border-border"                        // Borders
className="border-input"                         // Input borders

// ❌ DON'T - Hardcoded colors (breaks dark mode)
className="bg-white text-black"
className="bg-slate-100 dark:bg-slate-800"       // Use bg-muted instead
className="border-gray-200 dark:border-neutral-800" // Use border-border instead
```

### Status Colors (Require dark: Variants)

For status indicators (success/warning/error/info), use hardcoded colors WITH explicit dark variants:

```typescript
// ✅ DO - Status colors with dark mode variants
// Success (green)
className="bg-green-100 text-green-800 border-green-200 dark:bg-green-900/30 dark:text-green-100 dark:border-green-700"
className="text-green-600 dark:text-green-400"
className="bg-green-50 dark:bg-green-950"

// Warning (amber/yellow)
className="bg-amber-100 text-amber-800 border-amber-200 dark:bg-amber-900/30 dark:text-amber-100 dark:border-amber-700"
className="text-amber-600 dark:text-amber-400"

// Error (red)
className="bg-red-100 text-red-800 border-red-200 dark:bg-red-900/30 dark:text-red-100 dark:border-red-700"
className="text-red-600 dark:text-red-400"

// Info (blue)
className="bg-blue-100 text-blue-800 border-blue-200 dark:bg-blue-900/30 dark:text-blue-100 dark:border-blue-700"
className="text-blue-600 dark:text-blue-400"
```

### Color-Coded Percentage Indicators

```typescript
const getColorClass = (percentage: number) => {
  if (percentage === 100) return 'text-green-600 dark:text-green-400';
  if (percentage >= 75) return 'text-emerald-600 dark:text-emerald-400';
  if (percentage >= 50) return 'text-amber-600 dark:text-amber-400';
  if (percentage > 0) return 'text-orange-600 dark:text-orange-400';
  return 'text-red-600 dark:text-red-400';
};
```

### Quick Reference

| Element | Pattern |
|---------|---------|
| Cards | `bg-card text-card-foreground border-border rounded-lg` |
| Muted text | `text-muted-foreground` |
| Inputs | `border-input placeholder:text-muted-foreground` |
| Buttons | Use variants: `default`, `outline`, `ghost`, `destructive` |
| Status badges | Hardcoded colors with `dark:` variants |
| Icons with status | `text-green-600 dark:text-green-400` |

## Status Badge Pattern

Type-safe status mapping with Badge component:

```typescript
import { Badge } from '@kit/ui/badge';

type Status = 'active' | 'pending' | 'completed' | 'canceled';

function getStatusVariant(status: Status): 'default' | 'secondary' | 'destructive' | 'outline' {
  switch (status) {
    case 'active': return 'default';
    case 'pending': return 'secondary';
    case 'completed': return 'outline';
    case 'canceled': return 'destructive';
  }
}

function getStatusLabel(status: Status): string {
  const labels: Record<Status, string> = {
    active: 'Active',
    pending: 'Pending',
    completed: 'Completed',
    canceled: 'Canceled',
  };
  return labels[status];
}

export function StatusBadge({ status }: { status: Status }) {
  return (
    <Badge variant={getStatusVariant(status)}>
      {getStatusLabel(status)}
    </Badge>
  );
}
```

## Empty State Pattern

```typescript
import { EmptyState, EmptyStateHeading, EmptyStateText, EmptyStateButton } from '@kit/ui/empty-state';
import { FolderOpen } from 'lucide-react';

<EmptyState>
  <FolderOpen className="h-12 w-12 text-muted-foreground" />
  <EmptyStateHeading>No items found</EmptyStateHeading>
  <EmptyStateText>Get started by creating your first item.</EmptyStateText>
  <EmptyStateButton onClick={onCreate}>Create Item</EmptyStateButton>
</EmptyState>
```

## URL-Based Filter Pattern

Filters that sync with URL search params:

```typescript
'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { Input } from '@kit/ui/input';
import { useDebouncedCallback } from 'use-debounce';

export function TableSearchInput({ placeholder = 'Search...' }) {
  const router = useRouter();
  const searchParams = useSearchParams();

  const handleSearch = useDebouncedCallback((term: string) => {
    const params = new URLSearchParams(searchParams);
    if (term) {
      params.set('search', term);
    } else {
      params.delete('search');
    }
    params.set('page', '1'); // Reset pagination
    router.push(`?${params.toString()}`);
  }, 300);

  return (
    <Input
      placeholder={placeholder}
      defaultValue={searchParams.get('search') ?? ''}
      onChange={(e) => handleSearch(e.target.value)}
    />
  );
}
```

## Icon Button Pattern

Consistent icon + text button styling:

```typescript
import { Button } from '@kit/ui/button';
import { Plus, Download, Trash2 } from 'lucide-react';

// Icon with text
<Button variant="outline" size="sm">
  <Plus className="mr-2 h-4 w-4" />
  Add Item
</Button>

// Icon only (with aria-label for accessibility)
<Button variant="ghost" size="icon" aria-label="Delete item">
  <Trash2 className="h-4 w-4" />
</Button>

// Common icon sizes: h-4 w-4 (default), h-5 w-5 (larger)
```

## Responsive Grid Pattern

```typescript
// Card grid - responsive columns
<div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
  {items.map(item => <ItemCard key={item.id} item={item} />)}
</div>

// Form layout - two columns on desktop
<div className="grid grid-cols-1 gap-4 md:grid-cols-2">
  <FormField name="firstName" ... />
  <FormField name="lastName" ... />
</div>
```

## Accessibility Checklist

```typescript
// ✅ Icon-only buttons need aria-label
<Button variant="ghost" size="icon" aria-label="Close dialog">
  <X className="h-4 w-4" />
</Button>

// ✅ Form inputs need labels
<FormField
  name="email"
  render={({ field }) => (
    <FormItem>
      <FormLabel>Email</FormLabel>  {/* Required */}
      <FormControl>
        <Input {...field} aria-describedby="email-hint" />
      </FormControl>
      <FormDescription id="email-hint">We'll never share your email.</FormDescription>
      <FormMessage />
    </FormItem>
  )}
/>

// ✅ Error states need aria-invalid
<Input aria-invalid={!!error} aria-describedby={error ? 'error-msg' : undefined} />

// ✅ Interactive elements need keyboard support
<div role="button" tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && onClick()}>
```

## Date Formatting

Use `date-fns` for consistent date formatting:

```typescript
import { format, formatDistanceToNow } from 'date-fns';

// Display formats
format(date, 'LLL dd, y')     // "Jan 15, 2025"
format(date, 'yyyy-MM-dd')    // "2025-01-15"
format(date, 'HH:mm')         // "14:30"
format(date, 'EEEE, MMMM d')  // "Wednesday, January 15"

// Relative time
formatDistanceToNow(date, { addSuffix: true })  // "2 hours ago"
```

## DataTable with Filters

```typescript
const columns = [
  { accessorKey: 'name', header: 'Name' },
  { accessorKey: 'status', header: 'Status',
    cell: ({ row }) => <Badge>{row.original.status}</Badge>
  },
  { id: 'actions', cell: ({ row }) => <RowActions item={row.original} /> },
];

<DataTable
  columns={columns}
  data={items}
  searchKey="name"
  filterableColumns={[
    { id: 'status', title: 'Status', options: ['active', 'inactive'] },
  ]}
/>
```

## Admin Table Architecture

All admin tables MUST follow this consistent architecture for actions columns.

### Column Layout Standard

```
| Primary Actions | Data Columns...        | Destructive Actions |
|-----------------|------------------------|---------------------|
| [View] [Edit]   | Name, Status, Date...  | [Delete]            |
```

**Action Types by Position:**

| Type | Position | Icon | Confirmation Required |
|------|----------|------|----------------------|
| View | First column | `Eye` | No |
| Edit | First column | `Pencil` | No |
| Download | First column | `Download` | No |
| Delete | Last column | `Trash2` | **Yes (AlertDialog)** |
| Special Admin | Last column | Varies | Context-dependent |

### Primary Actions Column (First)

```typescript
import { Eye, Pencil, Download } from 'lucide-react';
import { Button } from '@kit/ui/button';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@kit/ui/tooltip';
import { Trans } from '@kit/ui/trans';
import Link from 'next/link';

// Column definition
{
  id: 'actions',
  header: '',
  cell: ({ row }) => {
    const item = row.original;

    return (
      <TooltipProvider>
        <div className="flex items-center gap-1">
          {/* View - always present */}
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="ghost" size="icon" asChild>
                <Link href={`/admin/items/${item.id}`}>
                  <Eye className="h-4 w-4" aria-hidden="true" />
                </Link>
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <Trans i18nKey="common:view" defaults="View" />
            </TooltipContent>
          </Tooltip>

          {/* Edit - if applicable */}
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="ghost" size="icon" asChild>
                <Link href={`/admin/items/${item.id}/edit`}>
                  <Pencil className="h-4 w-4" aria-hidden="true" />
                </Link>
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <Trans i18nKey="common:edit" defaults="Edit" />
            </TooltipContent>
          </Tooltip>
        </div>
      </TooltipProvider>
    );
  },
  enableSorting: false,
  enableHiding: false,
}
```

### Destructive Actions Column (Last)

**CRITICAL**: All delete actions MUST have AlertDialog confirmation.

```typescript
import { Trash2 } from 'lucide-react';
import { Button } from '@kit/ui/button';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@kit/ui/tooltip';
import { cn } from '@kit/ui/utils';
import { Trans } from '@kit/ui/trans';

// State in component
const [itemToDelete, setItemToDelete] = useState<Item | null>(null);

// Column definition (place as LAST column)
{
  id: 'destructive_actions',
  header: '',
  cell: ({ row }) => {
    const item = row.original;
    const canDelete = /* your condition - e.g., no dependencies */;

    return (
      <TooltipProvider>
        <div className="flex items-center justify-end gap-1">
          <Tooltip>
            <TooltipTrigger asChild>
              <span> {/* span wrapper for disabled button tooltip */}
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => setItemToDelete(item)}
                  disabled={!canDelete}
                >
                  <Trash2
                    className={cn(
                      'h-4 w-4',
                      canDelete ? 'text-destructive' : 'text-muted-foreground'
                    )}
                    aria-hidden="true"
                  />
                </Button>
              </span>
            </TooltipTrigger>
            <TooltipContent>
              {canDelete ? (
                <Trans i18nKey="common:delete" defaults="Delete" />
              ) : (
                <Trans i18nKey="common:cannotDelete" defaults="Cannot delete" />
              )}
            </TooltipContent>
          </Tooltip>
        </div>
      </TooltipProvider>
    );
  },
  enableSorting: false,
  enableHiding: false,
}
```

### Delete Confirmation Dialog (Required)

```typescript
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@kit/ui/alert-dialog';
import { Trans } from '@kit/ui/trans';

// State
const [itemToDelete, setItemToDelete] = useState<Item | null>(null);
const [isDeleting, setIsDeleting] = useState(false);

// Handler
const handleDelete = async () => {
  if (!itemToDelete) return;

  setIsDeleting(true);
  try {
    const result = await deleteItemAction({ id: itemToDelete.id });
    if (result.success) {
      toast.success(t('admin:items.deleted'));
      setItemToDelete(null);
    } else {
      toast.error(result.error || t('admin:items.deleteError'));
    }
  } catch (error) {
    toast.error(t('admin:items.deleteError'));
  } finally {
    setIsDeleting(false);
  }
};

// Dialog (render outside the table)
<AlertDialog
  open={!!itemToDelete}
  onOpenChange={(open) => !open && setItemToDelete(null)}
>
  <AlertDialogContent>
    <AlertDialogHeader>
      <AlertDialogTitle>
        <Trans
          i18nKey="admin:items.deleteTitle"
          values={{ name: itemToDelete?.name }}
        />
      </AlertDialogTitle>
      <AlertDialogDescription>
        <Trans i18nKey="admin:items.deleteDescription" />
      </AlertDialogDescription>
    </AlertDialogHeader>
    <AlertDialogFooter>
      <AlertDialogCancel disabled={isDeleting}>
        <Trans i18nKey="common:cancel" />
      </AlertDialogCancel>
      <AlertDialogAction
        onClick={handleDelete}
        disabled={isDeleting}
        className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
      >
        {isDeleting ? (
          <Trans i18nKey="common:deleting" />
        ) : (
          <Trans i18nKey="common:delete" />
        )}
      </AlertDialogAction>
    </AlertDialogFooter>
  </AlertDialogContent>
</AlertDialog>
```

### Complete Table Component Structure

```typescript
'use client';

import { useState, useMemo } from 'react';
import { ColumnDef } from '@tanstack/react-table';
// ... other imports

export function ItemsTable({ items, pageCount, pageSize, page, filters }) {
  const { t } = useTranslation();
  const [itemToDelete, setItemToDelete] = useState<Item | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDelete = async () => { /* ... */ };

  const columns: ColumnDef<Item>[] = useMemo(() => [
    // 1. PRIMARY ACTIONS (first)
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => { /* View, Edit, Download buttons */ },
      enableSorting: false,
      enableHiding: false,
    },

    // 2. DATA COLUMNS (middle)
    { id: 'name', header: t('admin:items.table.name'), /* ... */ },
    { id: 'status', header: t('admin:items.table.status'), /* ... */ },
    { id: 'created', header: t('admin:items.table.created'), /* ... */ },

    // 3. DESTRUCTIVE ACTIONS (last) - if applicable
    {
      id: 'destructive_actions',
      header: '',
      cell: ({ row }) => { /* Delete button */ },
      enableSorting: false,
      enableHiding: false,
    },
  ], [t, handleDelete]);

  return (
    <>
      <DataTable columns={columns} data={items} /* ... */ />

      {/* Delete confirmation dialog */}
      <AlertDialog open={!!itemToDelete} /* ... */}>
        {/* ... */}
      </AlertDialog>
    </>
  );
}
```

### Mobile Responsiveness

Icon buttons with `size="icon"` provide:
- 44x44px minimum touch targets (WCAG compliant)
- Tooltips automatically hidden on touch devices
- Consistent spacing with `gap-1`

No special mobile handling needed - the same icon buttons work on all screen sizes.

### TooltipProvider Requirement

**CRITICAL**: Always wrap tooltip groups with `<TooltipProvider>`:

```typescript
// ✅ CORRECT - Provider wraps all tooltips
<TooltipProvider>
  <div className="flex items-center gap-1">
    <Tooltip>...</Tooltip>
    <Tooltip>...</Tooltip>
  </div>
</TooltipProvider>

// ❌ WRONG - Missing provider causes runtime error
<div className="flex items-center gap-1">
  <Tooltip>...</Tooltip>  // Error: Tooltip must be used within TooltipProvider
</div>
```

The ESLint rule `react-providers/require-provider` enforces this at lint time.

## Dialog Pattern

```typescript
'use client';

import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@kit/ui/dialog';
import { Button } from '@kit/ui/button';
import { useState } from 'react';

export function CreateDialog({ onSubmit }) {
  const [open, setOpen] = useState(false);

  const handleSubmit = async (data) => {
    const result = await onSubmit(data);
    if (result.success) {
      setOpen(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>Create</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create Item</DialogTitle>
        </DialogHeader>
        <MyForm onSubmit={handleSubmit} />
      </DialogContent>
    </Dialog>
  );
}
```

## Loading States

```typescript
// Button loading
<Button disabled={isLoading}>
  {isLoading ? 'Loading...' : 'Submit'}
</Button>

// Skeleton loading
import { Skeleton } from '@kit/ui/skeleton';
<Skeleton className="h-4 w-[200px]" />
```

## Responsive Layout Patterns

### Core Principles (Airbnb/Industry Best Practices)

1. **Mobile-first approach** - Base styles for mobile, then scale up with `sm:`, `md:`, `lg:`
2. **Device-agnostic naming** - Use "small", "medium", "large" not "phone", "tablet", "desktop"
3. **Content-driven breakpoints** - Break where the design needs it, not at arbitrary device widths
4. **Optimal line length** - 45-75 characters for readability (achieved via max-width containers)

### Tailwind Breakpoints Reference

```
sm:  640px   - Small devices (large phones, small tablets)
md:  768px   - Medium devices (tablets)
lg:  1024px  - Large devices (laptops)
xl:  1280px  - Extra large (desktops)
2xl: 1536px  - Ultra wide screens
```

### Container Width Patterns by Page Type

**CRITICAL**: Always use `mx-auto` with `max-w-*` to center content on wide screens.

| Page Type | Pattern | Use Case |
|-----------|---------|----------|
| Wizards/Forms | `mx-auto max-w-2xl` | Multi-step forms, settings |
| Single Forms | `mx-auto max-w-3xl` | Create/edit pages |
| Profile/Detail | `mx-auto max-w-4xl` | Profile pages, detail views |
| Dashboard | `mx-auto max-w-6xl` or full | Data-heavy pages, tables |
| Full Width | No max-width | Admin tables, kanban boards |

```typescript
// ✅ CORRECT - Centered with max-width
<PageBody>
  <div className="mx-auto max-w-2xl">
    <WizardForm />
  </div>
</PageBody>

// ❌ WRONG - Left-aligned, looks weird on desktop
<PageBody>
  <div className="max-w-2xl">
    <WizardForm />
  </div>
</PageBody>
```

### Standard Page Layout Template

```typescript
// page.tsx
import { PageBody, PageHeader } from '@kit/ui/page';

export default function MyPage() {
  return (
    <>
      <PageHeader
        title="Page Title"
        description={<AppBreadcrumbs />}
      />
      <PageBody>
        {/* Choose appropriate max-width for content type */}
        <div className="mx-auto max-w-4xl space-y-6">
          {/* Page content */}
        </div>
      </PageBody>
    </>
  );
}
```

### Responsive Component Patterns

**Mobile-First Visibility:**
```typescript
// Show on mobile, hide on desktop
<div className="sm:hidden">Mobile navigation</div>

// Hide on mobile, show on desktop
<div className="hidden sm:block">Desktop navigation</div>

// Different layouts at breakpoints
<div className="flex flex-col sm:flex-row">
  <Sidebar className="w-full sm:w-64" />
  <Content className="flex-1" />
</div>
```

**Responsive Grid:**
```typescript
// 1 col mobile → 2 cols tablet → 3 cols desktop
<div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
  {items.map(item => <Card key={item.id} />)}
</div>

// Two-column form on desktop
<div className="grid grid-cols-1 gap-4 md:grid-cols-2">
  <FormField name="firstName" />
  <FormField name="lastName" />
</div>
```

**Responsive Spacing:**
```typescript
// Tighter spacing on mobile
<div className="space-y-4 sm:space-y-6 lg:space-y-8">

// Responsive padding
<div className="p-4 sm:p-6 lg:p-8">

// Responsive text sizes
<h1 className="text-xl sm:text-2xl lg:text-3xl">
```

### Dialog Responsive Patterns

```typescript
// Full screen on mobile, constrained on desktop
<DialogContent className="flex max-h-[90vh] flex-col overflow-hidden sm:max-w-lg">

// Wider dialog for complex content
<DialogContent className="flex max-h-[90vh] flex-col overflow-hidden sm:max-w-2xl">
```

### Wizard/Stepper Responsive Pattern

Use the unified `MobileWizardLayout` components for all wizard/stepper flows:

```typescript
import { MobileWizardLayout } from '@kit/ui/mobile-wizard-layout';
import { WizardNavigation } from '@kit/ui/wizard-navigation';
import { WizardProgress } from '@kit/ui/wizard-progress';
```

**MobileWizardLayout** - Main wrapper with three slots:

```typescript
<MobileWizardLayout
  contentWidth="lg"  // 'md' | 'lg' | 'xl' | 'full'
  header={<WizardProgress ... />}
  navigation={<WizardNavigation ... />}
>
  {stepContent}
</MobileWizardLayout>
```

Features:
- Sticky header for progress indicator
- Fixed bottom navigation on mobile, inline on desktop (`sm:` breakpoint)
- Auto padding (`pb-24` on mobile, `sm:pb-8` on desktop)
- Centered content with configurable max-width

**WizardProgress** - Step indicator with variants:

```typescript
// Bar variant (default) - progress bar with step counter
<WizardProgress
  currentStep={0}           // 0-based index
  totalSteps={5}
  stepTitle="Overview"      // Optional
  variant="bar"             // 'bar' (default) | 'dots' | 'icons'
/>

// Icons variant - circles with icons and connector lines
import { Building, FileText, CreditCard } from 'lucide-react';

<WizardProgress
  variant="icons"
  currentStep={1}
  steps={[
    { id: 'address', label: 'Home Address', icon: Building },
    { id: 'tax', label: 'Tax Info', icon: FileText },
    { id: 'bank', label: 'Bank Details', icon: CreditCard },
  ]}
  showLabels={true}  // Optional, defaults to true (hidden on mobile)
/>
```

- Bar variant: Progress bar + "Step X of Y" + optional title
- Dots variant: Dot indicators for each step
- Icons variant: Circles with Lucide icons, connector lines between steps, checkmarks for completed steps
- i18n support via `common:stepOf` key (bar variant)

**WizardNavigation** - Bottom navigation buttons:

```typescript
<WizardNavigation
  isFirstStep={currentStep === 0}
  isLastStep={isLastStep}
  onBack={handleBack}
  onNext={handleNext}
  onSkip={handleSkip}       // Optional - renders skip button
  nextDisabled={!canProceed}
  isPending={isLoading}
  submitLabel={<Trans i18nKey="..." />}  // Optional custom label
/>
```

Features:
- Back button (icon, hidden on first step)
- Next/Submit button (h-12 touch targets)
- Optional skip button
- Loading spinner state

**Complete Example:**

```typescript
'use client';

import { MobileWizardLayout } from '@kit/ui/mobile-wizard-layout';
import { WizardNavigation } from '@kit/ui/wizard-navigation';
import { WizardProgress } from '@kit/ui/wizard-progress';

function MyWizard() {
  const [currentStep, setCurrentStep] = useState(0);
  const steps = ['Overview', 'Details', 'Review'];
  const isLastStep = currentStep === steps.length - 1;

  return (
    <MobileWizardLayout
      contentWidth="lg"
      header={
        <WizardProgress
          currentStep={currentStep}
          totalSteps={steps.length}
          stepTitle={steps[currentStep]}
        />
      }
      navigation={
        <WizardNavigation
          isFirstStep={currentStep === 0}
          isLastStep={isLastStep}
          onBack={() => setCurrentStep((s) => s - 1)}
          onNext={isLastStep ? handleSubmit : () => setCurrentStep((s) => s + 1)}
          nextDisabled={!canProceed}
          isPending={isSubmitting}
        />
      }
    >
      <div className="space-y-4">
        {renderStep()}
      </div>
    </MobileWizardLayout>
  );
}
```

**Usage in Ballee:**
- Feedback Form (`/home/(user)/feedback/[eventId]`)
- Contract Details Wizard (`/home/(user)/dancer/contract-details`)
- Profile Setup Wizard (`/home/(user)/dancer/profile/setup`) - uses WizardProgress for mobile

### Quick Reference: Common Responsive Classes

| Purpose | Mobile | Tablet (`sm:`) | Desktop (`lg:`) |
|---------|--------|----------------|-----------------|
| Hide/Show | `hidden` | `sm:block` | `lg:hidden` |
| Flex direction | `flex-col` | `sm:flex-row` | - |
| Grid columns | `grid-cols-1` | `sm:grid-cols-2` | `lg:grid-cols-3` |
| Text size | `text-sm` | `sm:text-base` | `lg:text-lg` |
| Padding | `p-4` | `sm:p-6` | `lg:p-8` |
| Gap | `gap-2` | `sm:gap-4` | `lg:gap-6` |

### Existing App Patterns to Follow

These patterns are already established in the codebase:

```typescript
// Wizard pages (contract-details, legal-status)
<div className="mx-auto max-w-2xl">

// Profile/dashboard pages
<div className="mx-auto w-full max-w-4xl space-y-6">

// Form pages
<div className="mx-auto max-w-3xl">

// Full-width with responsive padding
<div className="mx-auto flex w-full max-w-4xl flex-col gap-6">
```

## Toast Usage

```typescript
import { toast } from '@kit/ui/sonner';

// Success
toast.success('Item created');

// Error
toast.error('Failed to create item');

// With description
toast.success('Item created', { description: 'Redirecting...' });
```

## CRUD Mutations Hook (CRITICAL)

Use the generic `useCrudMutations` factory for consistent CRUD operations. Located at `apps/web/lib/hooks/use-crud-mutations.ts`.

### Basic Usage

```typescript
import { useCrudMutations } from '@/lib/hooks/use-crud-mutations';
import { createAction, updateAction, deleteAction } from './server/actions';

function useMyEntityMutations(options?: { onSuccess?: () => void }) {
  const mutations = useCrudMutations<Entity, CreateInput, UpdateInput>({
    entityName: 'entity',           // For toast messages
    queryKeys: ['entities', 'admin-entities'], // Cache keys to invalidate
    actions: {
      create: createAction,
      update: updateAction,
      delete: deleteAction,
    },
    optimisticUpdates: true,        // Optional: enable optimistic UI
    normalizeData: (data) => ({     // Optional: transform data before sending
      ...data,
      isActive: data.isActive ?? true,
    }),
  }, {
    onSuccess: (data) => options?.onSuccess?.(data),
  });

  // Return with entity-specific naming for backwards compatibility
  return {
    createEntity: mutations.create,
    createEntityAsync: mutations.createAsync,
    isCreating: mutations.isCreating,
    updateEntity: mutations.update,
    updateEntityAsync: mutations.updateAsync,
    isUpdating: mutations.isUpdating,
    deleteEntity: mutations.delete,
    deleteEntityAsync: mutations.deleteAsync,
    isDeleting: mutations.isDeleting,
  };
}
```

### Update Call Signature

The `update` function uses `{ id, data }` format:

```typescript
// Using the hook
const { updateEntity } = useEntityMutations();

// ✅ CORRECT - wrap data in 'data' property
await updateEntity({ id: entity.id, data: { name: 'New Name' } });

// ❌ WRONG - flat object (old pattern)
await updateEntity({ id: entity.id, name: 'New Name' });
```

### Migrated Hooks (Reference)

These admin hooks use `useCrudMutations`:
- `use-venue-mutations.ts`
- `use-choreographer-mutations.ts`
- `use-piece-mutations.ts`
- `use-client-mutations.ts`
- `use-jurisdiction-mutations.ts`
- `use-engagement-model-mutations.ts`
- `use-per-diem-rate-mutations.ts`
- `use-legal-status-type-mutations.ts`

### When NOT to Use

Don't use `useCrudMutations` for specialized workflows:
- Accept/decline flows (use-assignment-mutations)
- Approve/reject flows (use-dancer-legal-status-mutations)
- Status change workflows (use-campaign-mutations)
- Link/unlink operations (use-client-user-mutations)

---

## Dialog State Hook

Use `useDialogState` for consistent dialog state management. Located at `apps/web/lib/hooks/use-dialog-state.ts`.

### Basic Dialog State

```typescript
import { useDialogState } from '@/lib/hooks/use-dialog-state';

function MyComponent() {
  const dialog = useDialogState();

  return (
    <>
      <Button onClick={dialog.handleOpen}>Open</Button>
      <Dialog open={dialog.open} onOpenChange={dialog.setOpen}>
        <DialogContent>
          <Button onClick={dialog.handleClose}>Close</Button>
        </DialogContent>
      </Dialog>
    </>
  );
}
```

### Dialog with Selected Item (Edit Dialogs)

```typescript
import { useDialogStateWithItem } from '@/lib/hooks/use-dialog-state';

function EditDialog() {
  const { open, selectedItem, openWith, closeAndClear } = useDialogStateWithItem<Entity>();

  return (
    <>
      <Button onClick={() => openWith(entity)}>Edit</Button>
      <Dialog open={open} onOpenChange={(isOpen) => !isOpen && closeAndClear()}>
        <DialogContent>
          {selectedItem && <EditForm entity={selectedItem} onClose={closeAndClear} />}
        </DialogContent>
      </Dialog>
    </>
  );
}
```

### API Reference

```typescript
// useDialogState()
interface DialogState {
  open: boolean;
  setOpen: (open: boolean) => void;
  handleOpen: () => void;
  handleClose: () => void;
  toggle: () => void;
}

// useDialogStateWithItem<T>() - extends DialogState
interface DialogStateWithItem<T> extends DialogState {
  selectedItem: T | null;
  openWith: (item: T) => void;      // Open dialog with specific item
  closeAndClear: () => void;        // Close and clear selection (with delay)
}
```

---

## Centralized Formatters

Use formatters from `apps/web/lib/formatters.ts` for consistent formatting across the app.

### Available Formatters

```typescript
import {
  formatCurrency,
  formatNumber,
  formatPercent,
  formatDate,
  formatTime,
  formatTimeRange,
  formatShowtimeDate,
  formatFeverDate,
  getFullName,
  formatReimbursementType,
  formatReimbursementsText,
} from '@/lib/formatters';

// Currency (EUR default)
formatCurrency(1234.56);            // "€1,234.56"
formatCurrency(1234.56, 'USD');     // "$1,234.56"

// Numbers
formatNumber(1234.567);             // "1,234.57"
formatNumber(1234.567, 0);          // "1,235"
formatPercent(0.856);               // "85.6%"
formatPercent(0.856, 0);            // "86%"

// Dates
formatDate('2025-01-15');           // "Jan 15, 2025"
formatDate('2025-01-15', 'full');   // "Wednesday, January 15, 2025"
formatDate('2025-01-15', 'short');  // "1/15/25"
formatTime('14:30:00');             // "2:30 PM"
formatTimeRange('09:00', '17:00');  // "9:00 AM - 5:00 PM"
formatShowtimeDate('2025-01-15');   // "Wed Jan 15"
formatFeverDate('2025-01-15');      // "15.01.2025"

// Names
getFullName({ first_name: 'John', last_name: 'Doe' }); // "John Doe"

// Reimbursements
formatReimbursementType('transport');  // "Transport"
formatReimbursementsText([{ type: 'hotel', amount: 100 }]); // "Hotel: €100.00"
```

### When to Use

- **Admin pages**: formatCurrency, formatDate, formatNumber
- **Event displays**: formatShowtimeDate, formatTimeRange
- **Invoice/contract**: formatFeverDate (DD.MM.YYYY format)
- **Profile displays**: getFullName
- **Reimbursement lists**: formatReimbursementsText

---

## Data Mutation Pattern (CRITICAL)

### Architecture Overview

Ballee uses a hybrid approach:
- **Server Components (RSC)** load initial page data
- **TanStack Query** provides optimistic UI updates
- **Server Actions** handle mutations and revalidate RSC cache

**The key insight**: Server Actions MUST call `revalidatePath()` to sync RSC data. Client-side `queryClient.invalidateQueries()` only affects client cache.

### Complete Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│ Client Component                                                │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ useMutation hook                                            │ │
│ │  - onMutate: optimistic update (instant UI)                 │ │
│ │  - mutationFn: calls server action                          │ │
│ │  - onSuccess: toast + optional client cache invalidation    │ │
│ │  - onError: rollback + toast                                │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Server Action                                                   │
│  - Validate input (Zod)                                         │
│  - Call service                                                 │
│  - revalidatePath() on success ← CRITICAL!                      │
│  - Return result                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ RSC Cache Invalidated → Page re-renders with fresh data        │
└─────────────────────────────────────────────────────────────────┘
```

### ✅ CORRECT Pattern: Server Action + TanStack Query

**Step 1: Server Action with revalidatePath**

```typescript
// apps/web/app/admin/items/_lib/server/actions.ts
'use server';

import { revalidatePath } from 'next/cache';
import { withAuthParams } from '@/lib/auth-wrappers';

export const deleteItemAction = withAuthParams(async (params, id: string) => {
  const service = new ItemService(params.client);
  const result = await service.delete(id);

  if (result.success) {
    revalidatePath('/admin/items');  // ← CRITICAL: Invalidates RSC cache
  }

  return result;
});
```

**Step 2: TanStack Query Hook for Optimistic UI**

```typescript
// apps/web/app/admin/items/_lib/hooks/use-item-mutations.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from '@kit/ui/sonner';
import { deleteItemAction } from '../server/actions';

export function useItemMutations() {
  const queryClient = useQueryClient();
  // NOTE: No useRouter needed - server action handles revalidation

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const result = await deleteItemAction(id);
      if ('error' in result && result.error) {
        throw new Error(result.error);
      }
      return result;
    },

    onMutate: async (id) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['items'] });

      // Snapshot for rollback
      const previousItems = queryClient.getQueryData(['items']);

      // Optimistic update - UI updates instantly
      queryClient.setQueryData(['items'], (old: Item[] | undefined) =>
        old?.filter((item) => item.id !== id)
      );

      return { previousItems };
    },

    onError: (error, _id, context) => {
      // Rollback on error
      if (context?.previousItems) {
        queryClient.setQueryData(['items'], context.previousItems);
      }
      toast.error(error instanceof Error ? error.message : 'Failed to delete');
    },

    onSuccess: () => {
      // Optional: Invalidate client cache for components using useQuery
      queryClient.invalidateQueries({ queryKey: ['items'] });
      toast.success('Item deleted');
      // NO router.refresh() - server action already called revalidatePath()!
    },
  });

  return {
    deleteItem: deleteMutation.mutate,
    isDeleting: deleteMutation.isPending,
  };
}
```

### ❌ FORBIDDEN Patterns

```typescript
// ❌ WRONG - router.refresh() in client hook
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ['items'] });
  router.refresh();  // 700ms+ full page reload, move revalidation to server action
  toast.success('Deleted');
};

// ❌ WRONG - Server action without revalidatePath
export const deleteItemAction = withAuthParams(async (params, id) => {
  const result = await service.delete(id);
  return result;  // Missing revalidatePath!
});

// ❌ WRONG - Relying only on client cache invalidation
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ['items'] });
  // This only affects components using useQuery, not Server Components!
};
```

### When router.refresh() IS Acceptable

Only use `router.refresh()` in these rare cases:

1. **Auth state changed** - Login/logout requires full context refresh
2. **Account/workspace switched** - User switches between workspaces
3. **Error recovery fallback** - When optimistic rollback fails

```typescript
// ✅ OK - Auth state change
const handleLogout = async () => {
  await signOut();
  router.refresh(); // Required to clear auth context
};

// ✅ OK - Account switch
const handleAccountSwitch = async (accountId: string) => {
  await switchAccountAction(accountId);
  router.refresh(); // Required to refresh workspace context
};
```

### Performance Comparison

| Pattern | Perceived Latency | Full Page Reload |
|---------|------------------|------------------|
| `router.refresh()` | ~2000ms | Yes |
| `revalidatePath()` in action | ~200ms | No (targeted) |
| Optimistic + revalidatePath | ~20ms | No |

### Migration Checklist

When refactoring existing code:

1. **Server Action**: Add `revalidatePath()` call on success
2. **Client Hook**: Remove `router.refresh()` from `onSuccess`
3. **Client Hook**: Keep `queryClient.invalidateQueries()` for client cache
4. **Test**: Verify UI updates without manual refresh

## Edit Dialog vs Edit Page Decision Rules

**CRITICAL**: Never use BOTH a dialog AND a page for editing the same entity. Choose ONE.

### Decision Matrix

| Criteria | Use Dialog | Use Page |
|----------|------------|----------|
| Field count | ≤6 fields | >6 fields |
| Entity complexity | Simple lookup/config | Complex business entity |
| Relationships | None or simple FK | Nested relationships, tabs |
| Context needed | Minimal | Requires stats, history, related data |
| Navigation flow | Stay in list view | Deep-link/bookmark important |
| Example entities | Jurisdictions, Rates, Roles | Clients, Venues, Productions, Dancers |

### Use DIALOG When (ALL must be true):

1. **≤6 editable fields** - Quick inline edits
2. **No nested relationships** - No tabs, no sub-tables
3. **No contextual data needed** - No stats, history, or related records
4. **Lookup/configuration table** - Administrative settings, not core business data
5. **User stays in list context** - Return to same view after editing

```
✅ Good Dialog Use Cases:
- Engagement Models (code, name, description, vat_treatment, 2 checkboxes)
- Jurisdictions (code, name, currency, vat_rate, 2 checkboxes)
- Per Diem Rates (jurisdiction, role, amount, dates)
- Legal Status Types (name, description, status)
- Client User roles (role, is_primary_contact - 2 fields)
```

### Use EDIT PAGE When (ANY is true):

1. **>6 editable fields** - Complex forms need space
2. **Multiple sections/tabs** - Logical groupings of data
3. **Related data display** - Stats, history, linked records
4. **Nested relationships** - Sub-tables, child entities
5. **Deep-linking valuable** - Users bookmark or share edit URLs
6. **Core business entity** - Clients, Productions, Events, Dancers, Venues

```
✅ Good Edit Page Use Cases:
- Clients (8+ fields, multiple tabs: info, users, fees)
- Productions (11+ fields, tabs: overview, roles, show sheet)
- Venues (20+ fields, tabs: details, documents, contacts)
- Dancers (many fields, tabs: profile, rates, documents)
- Events (many fields, tabs: details, cast, participations)
```

### FORBIDDEN Patterns

```typescript
// ❌ NEVER: Both dialog AND page for same entity
// - edit-client-dialog.tsx + /admin/clients/[id] page
// - edit-production-dialog.tsx + /admin/productions/[id] page

// ❌ NEVER: Dialog for complex entities
// - Client edit dialog (8+ fields, needs tabs)
// - Event edit dialog (needs cast management)

// ❌ NEVER: Page for simple lookup tables
// - /admin/jurisdictions/[id] (only 6 fields)
// - /admin/engagement-models/[id] (only 6 fields)
```

### Implementation Patterns

**Dialog Pattern (Simple Entity):**

```typescript
// Table with edit action opening dialog
function LookupTable({ items }) {
  const [editItem, setEditItem] = useState(null);

  return (
    <>
      <DataTable
        columns={columns}
        data={items}
        onEditClick={(item) => setEditItem(item)}
      />
      <EditDialog
        item={editItem}
        open={!!editItem}
        onOpenChange={(open) => !open && setEditItem(null)}
      />
    </>
  );
}
```

**Page Pattern (Complex Entity):**

```typescript
// Table row links to edit page
{
  id: 'actions',
  cell: ({ row }) => (
    <Button variant="ghost" size="icon" asChild>
      <Link href={`/admin/entities/${row.original.id}`}>
        <Pencil className="h-4 w-4" />
      </Link>
    </Button>
  ),
}

// Edit page has inline form (not separate /edit route)
// apps/web/app/admin/entities/[id]/page.tsx
export default function EntityDetailPage({ params }) {
  return (
    <EntityTabs entity={entity}>
      <TabContent value="overview">
        <EntityForm entity={entity} /> {/* Inline edit form */}
      </TabContent>
      <TabContent value="related">
        <RelatedItemsTable />
      </TabContent>
    </EntityTabs>
  );
}
```

### Codebase Current State (Reference)

| Entity | Pattern | Status |
|--------|---------|--------|
| Clients | Page only | ✅ Correct |
| Client Users | Dialog only | ✅ Correct (2 fields) |
| Venues | Page only | ✅ Correct |
| Productions | Page only | ✅ Correct |
| Dancers | Page only | ✅ Correct |
| Events | Page (needs edit form) | ⚠️ Missing edit functionality |
| Engagement Models | Dialog only | ✅ Correct |
| Jurisdictions | Dialog only | ✅ Correct |
| Per Diem Rates | Dialog only | ✅ Correct |
| Legal Status Types | Dialog only | ✅ Correct |

### Migration Checklist (When Consolidating)

When removing a dialog in favor of an edit page:

1. **Verify all dialog fields exist in page form**
2. **Update table action**: Change dialog trigger to Link to detail page
3. **Remove dialog component and test files**
4. **Update imports in table component**
5. **Test: Edit from table → changes saved → return to table**

## Document Components

For document management UI, use `@kit/documents/components` instead of building custom:

```typescript
import {
  // Display
  DocumentList,        // Read-only document gallery
  DocumentCard,        // Card view with thumbnail
  DocumentRow,         // List view row

  // Viewer
  DocumentViewerDialog, // Full-screen viewer with keyboard shortcuts

  // Editable (CRUD)
  SortableDocumentList, // Full CRUD with upload, edit, delete, reorder
} from '@kit/documents/components';

import { useDocumentViewer } from '@kit/documents/hooks';
```

### Basic Usage

```typescript
import { DocumentList, DocumentViewerDialog } from '@kit/documents/components';
import { useDocumentViewer } from '@kit/documents/hooks';

function Gallery({ documents }) {
  const viewer = useDocumentViewer(documents);

  return (
    <>
      <DocumentList
        documents={documents}
        onView={(doc) => viewer.open(doc)}
      />
      <DocumentViewerDialog
        documents={documents}
        currentIndex={viewer.currentIndex}
        isOpen={viewer.isOpen}
        onClose={viewer.close}
        onNavigate={viewer.navigate}
      />
    </>
  );
}
```

For full patterns including CRUD, adapters, and PDF generation, see the `document-patterns` skill.
