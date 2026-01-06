---
description: Document and PDF patterns for Ballee using @kit/documents for document management and @kit/pdf-core for PDF generation. Use when working with file uploads, document viewers, or generating PDFs.
version: "1.0.0"
updated: "2025-12-25"
---

# Document & PDF Patterns

## @kit/documents Package

The `@kit/documents` package provides a complete document management system with types, components, hooks, and server actions.

### Exports

```typescript
import type { Document, DocumentWithUrl, EditableDocument } from '@kit/documents/types';
import { FileTypeCategory, ThumbnailSizes } from '@kit/documents/constants';
import { getFileCategory, formatFileSize, downloadDocument } from '@kit/documents/utils';
import { useDocumentViewer, useDocumentDownload, useReactPdf } from '@kit/documents/hooks';
import { DocumentList, DocumentViewerDialog, SortableDocumentList } from '@kit/documents/components';
import { getDocumentSignedUrlAction } from '@kit/documents/server';
```

### Core Types

```typescript
// Base document interface
interface Document {
  id: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
  storagePath: string;
  bucket: string;
  uploadedAt?: string | null;
  description?: string | null;
}

// Document with signed URL for display
interface DocumentWithUrl extends Document {
  signedUrl: string;
  thumbnailUrl?: string | null;
}

// Editable document with title/order for CRUD lists
interface EditableDocument extends Document {
  title: string;
  displayOrder?: number | null;
  documentType?: string;
}

interface EditableDocumentWithUrl extends EditableDocument {
  signedUrl: string;
  thumbnailUrl?: string | null;
}

// For document updates
interface DocumentUpdateInput {
  title?: string;
  description?: string;
}

// For reordering documents
interface DocumentReorderItem {
  id: string;
  displayOrder: number;
}

// For upload dialogs
interface DocumentUploadInput {
  file: File;
  title: string;
  documentType?: string;
  description?: string;
}
```

### Constants

```typescript
// File type categories
import { FileTypeCategory, getFileCategory } from '@kit/documents/constants';

FileTypeCategory.IMAGE       // 'image'
FileTypeCategory.PDF         // 'pdf'
FileTypeCategory.VIDEO       // 'video'
FileTypeCategory.DOCUMENT    // 'document'
FileTypeCategory.SPREADSHEET // 'spreadsheet'
FileTypeCategory.OTHER       // 'other'

const category = getFileCategory('image/jpeg'); // 'image'

// Thumbnail sizes for image transforms
import { ThumbnailSizes } from '@kit/documents/constants';

ThumbnailSizes.SMALL   // { width: 100, height: 100, quality: 80 }
ThumbnailSizes.MEDIUM  // { width: 200, height: 200, quality: 80 }
ThumbnailSizes.LARGE   // { width: 400, height: 400, quality: 85 }
ThumbnailSizes.XLARGE  // { width: 800, height: 800, quality: 90 }
```

### Components

**Display Components:**

```typescript
import {
  FileTypeIcon,      // Icon based on MIME type
  DocumentThumbnail, // Thumbnail with fallback icon
  DocumentCard,      // Card view with actions
  DocumentRow,       // List view row
  DocumentList,      // Simple list wrapper
} from '@kit/documents/components';
```

**Viewer Components:**

```typescript
import {
  ImageViewer,         // Image preview with pan/zoom
  PdfViewer,           // PDF preview using react-pdf
  DocumentNavigator,   // Navigation between documents
  DocumentViewerDialog, // Full modal viewer with keyboard shortcuts
} from '@kit/documents/components';
```

**Editable Components:**

```typescript
import {
  EditableDocumentCard,  // Card with edit/delete actions
  SortableDocumentList,  // Full CRUD list with reordering
  DocumentEditDialog,    // Edit metadata dialog
  DocumentUploadDialog,  // Upload new document dialog
} from '@kit/documents/components';
```

### Hooks

```typescript
import {
  useDocumentUrl,      // Fetch signed URL for a document
  useDocumentDownload, // Download document utility
  useDocumentViewer,   // Manage viewer state (current doc, zoom, fullscreen)
  useDocumentEdit,     // Manage edit dialog state
  useDocumentReorder,  // Manage document ordering
  useReactPdf,         // PDF viewer utilities
} from '@kit/documents/hooks';
```

### Server Actions

```typescript
import { getDocumentSignedUrlAction } from '@kit/documents/server';

// Get a signed URL for viewing/downloading
const result = await getDocumentSignedUrlAction({
  bucket: 'venue-documents',
  path: 'venue-123/photo.jpg',
  expiresIn: 3600,           // Optional: seconds (default 3600)
  download: false,           // Optional: force download
  transform: {               // Optional: image transforms
    width: 400,
    height: 400,
    quality: 85,
  },
});

if (result.success) {
  const url = result.url;
}
```

---

## @kit/pdf-core Package

Shared PDF generation utilities, styles, and components using `@react-pdf/renderer`.

### Exports

```typescript
// Utilities
import {
  sanitizeForPdf,        // Deep sanitize Supabase data for PDF
  nodeStreamToWebStream, // Convert Node stream to Web stream
  getPdfResponseHeaders, // Get standard PDF response headers
} from '@kit/pdf-core';

// Style tokens
import {
  pdfColors,     // Brand colors
  pdfFonts,      // Font families
  pdfFontSizes,  // Size scale
  pdfSpacing,    // Spacing scale
  pdfPage,       // Page dimensions
} from '@kit/pdf-core';

// Pre-built style objects
import {
  headerStyles,
  footerStyles,
  sectionStyles,
  tableStyles,
  badgeStyles,
  textStyles,
} from '@kit/pdf-core';

// Components
import {
  PdfHeader,       // Document header with logo
  PdfFooter,       // Page footer with numbers
  PdfSection,      // Titled section wrapper
  PdfTable,        // Data table
  PdfBadge,        // Status badge
  PdfBadgeList,    // List of badges
  PdfInfoSection,  // Key-value info display
  PdfFieldRow,     // Form field row
  PdfNotes,        // Notes section
  PdfTotals,       // Totals section
  PdfBankSection,  // Bank details section
  PdfLegend,       // Legend/key section
} from '@kit/pdf-core/components';
```

### PDF Template Pattern

```typescript
// packages/features/my-feature/src/templates/pdf/my-template.tsx
import React from 'react';
import { Document, Page, View, Text } from '@react-pdf/renderer';
import {
  PdfHeader,
  PdfFooter,
  PdfSection,
  PdfTable,
  pageStyles,
  pdfColors,
} from '@kit/pdf-core';

interface MyPdfProps {
  data: {
    title: string;
    items: Array<{ name: string; value: number }>;
  };
}

export function MyPdfTemplate({ data }: MyPdfProps) {
  return (
    <Document>
      <Page size="A4" style={pageStyles.page}>
        <PdfHeader title={data.title} />

        <View style={pageStyles.content}>
          <PdfSection title="Items">
            <PdfTable
              columns={[
                { header: 'Name', accessor: 'name', width: '70%' },
                { header: 'Value', accessor: 'value', width: '30%', align: 'right' },
              ]}
              data={data.items}
            />
          </PdfSection>
        </View>

        <PdfFooter />
      </Page>
    </Document>
  );
}
```

---

## Document Management Patterns

### Basic Read-Only Document List

```typescript
import { DocumentList, DocumentViewerDialog } from '@kit/documents/components';
import { useDocumentViewer } from '@kit/documents/hooks';
import type { DocumentWithUrl } from '@kit/documents/types';

interface Props {
  documents: DocumentWithUrl[];
}

export function DocumentGallery({ documents }: Props) {
  const viewer = useDocumentViewer(documents);

  return (
    <>
      <DocumentList
        documents={documents}
        onView={(doc) => viewer.open(doc)}
        onDownload={(doc) => window.open(doc.signedUrl)}
      />

      <DocumentViewerDialog
        documents={documents}
        currentIndex={viewer.currentIndex}
        isOpen={viewer.isOpen}
        onClose={viewer.close}
        onNavigate={viewer.navigate}
        zoom={viewer.zoom}
        onZoomChange={viewer.setZoom}
      />
    </>
  );
}
```

### Editable Document List with CRUD

```typescript
import { SortableDocumentList } from '@kit/documents/components';
import type { EditableDocumentWithUrl, DocumentUploadInput } from '@kit/documents/types';

interface Props {
  documents: EditableDocumentWithUrl[];
  documentTypes: Array<{ value: string; label: string }>;
  onUpload: (input: DocumentUploadInput) => Promise<void>;
  onEdit: (id: string, data: { title?: string; description?: string }) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onReorder: (items: Array<{ id: string; displayOrder: number }>) => Promise<void>;
}

export function VenueDocumentsList({
  documents,
  documentTypes,
  onUpload,
  onEdit,
  onDelete,
  onReorder,
}: Props) {
  return (
    <SortableDocumentList
      documents={documents}
      documentTypes={documentTypes}
      onUpload={onUpload}
      onEdit={onEdit}
      onDelete={onDelete}
      onReorder={onReorder}
      emptyMessage="No documents uploaded yet"
    />
  );
}
```

### Adapter Pattern (Database to Component Types)

When your database schema doesn't match `@kit/documents` types exactly, create an adapter:

```typescript
// adapters/venue-document-adapter.ts
import type { EditableDocumentWithUrl, Document } from '@kit/documents/types';

interface VenueDocument {
  id: string;
  venue_id: string;
  title: string;
  document_type: string | null;
  storage_path: string;
  file_name: string;
  file_size: number;
  mime_type: string;
  display_order: number | null;
  created_at: string;
}

export function toEditableDocument(
  doc: VenueDocument,
  signedUrl: string,
  thumbnailUrl?: string,
): EditableDocumentWithUrl {
  return {
    id: doc.id,
    title: doc.title,
    fileName: doc.file_name,
    fileSize: doc.file_size,
    mimeType: doc.mime_type,
    storagePath: doc.storage_path,
    bucket: 'venue-documents',
    displayOrder: doc.display_order,
    documentType: doc.document_type ?? undefined,
    uploadedAt: doc.created_at,
    signedUrl,
    thumbnailUrl,
  };
}
```

---

## PDF Generation Patterns

**CRITICAL**: Use API Routes for PDF generation, not Server Actions. See `api-patterns` skill for the complete pattern.

### Quick Reference

```typescript
// 1. Fetch data with RLS-protected client
const data = await fetchData(client, id);

// 2. Sanitize for PDF (REQUIRED!)
import { sanitizeForPdf } from '@kit/pdf-core';
const safeData = sanitizeForPdf(data);

// 3. Render to stream
import { renderToStream } from '@react-pdf/renderer';
const stream = await renderToStream(<MyPdfTemplate data={safeData} />);

// 4. Return streaming response
import { nodeStreamToWebStream, getPdfResponseHeaders } from '@kit/pdf-core';
return new Response(nodeStreamToWebStream(stream), {
  headers: getPdfResponseHeaders('my-document.pdf'),
});
```

### Existing PDF Routes

| Route | Purpose |
|-------|---------|
| `/api/pdf/hire-order` | Admin hire order documents |
| `/api/pdf/resume` | Dancer resume/CV |
| `/api/pdf/cast-sheet` | Cast assignment sheets |

---

## Storage Integration

Use `@kit/shared/storage` constants with document operations:

```typescript
import { StorageBuckets, SignedUrlExpiry } from '@kit/shared/storage';

// Available buckets
StorageBuckets.DANCER_MEDIA           // 'dancer-media'
StorageBuckets.VENUE_DOCUMENTS        // 'venue-documents'
StorageBuckets.PRODUCTION_DOCUMENTS   // 'production-documents'
StorageBuckets.REIMBURSEMENT_DOCUMENTS // 'reimbursement-documents'
StorageBuckets.LEGAL_DOCUMENTS        // 'legal-documents'
StorageBuckets.CONTRACTS              // 'contracts'
StorageBuckets.INVOICE_PDFS           // 'invoice-pdfs'

// Expiry times
SignedUrlExpiry.IMMEDIATE_DISPLAY  // 3600 (1 hour)
SignedUrlExpiry.DOWNLOAD           // 86400 (24 hours)
SignedUrlExpiry.PROFILE_PHOTO      // 604800 (7 days)
```

---

## Anti-Patterns

```typescript
// ❌ WRONG - Server Action for PDF generation
'use server';
import { renderToBuffer } from '@react-pdf/renderer';
export async function generatePdf(data) {
  return await renderToBuffer(<MyPdf data={data} />); // hasOwnProperty error!
}

// ✅ CORRECT - Use API Route (see api-patterns skill)

// ❌ WRONG - Raw Supabase data to PDF
const data = await client.from('table').select('*').single();
return <MyPdf data={data} />; // May fail with undefined/null

// ✅ CORRECT - Sanitize first
import { sanitizeForPdf } from '@kit/pdf-core';
const safeData = sanitizeForPdf(data);
return <MyPdf data={safeData} />;

// ❌ WRONG - Hardcoded bucket names
await client.storage.from('venue-documents').upload(...);

// ✅ CORRECT - Use constants
import { StorageBuckets } from '@kit/shared/storage';
await client.storage.from(StorageBuckets.VENUE_DOCUMENTS).upload(...);
```

---

## Related Skills

| Need | Skill |
|------|-------|
| Storage service patterns | `service-patterns` |
| PDF API routes | `api-patterns` |
| UI components | `ui-patterns` |
| Database migrations for document tables | `database-migration-manager` |
| RLS policies for document access | `rls-policy-generator` |
