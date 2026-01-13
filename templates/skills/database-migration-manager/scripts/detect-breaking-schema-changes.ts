/**
 * Breaking Schema Change Detection Script
 *
 * Detects breaking changes in database schema (removed/renamed columns) and identifies
 * which files need to be updated. Run this after generating new database types from migrations.
 *
 * Usage:
 *   # 1. Backup current schema before applying migrations
 *   cp lib/database.types.ts lib/database.types.ts.bak
 *
 *   # 2. Apply migrations and regenerate types
 *   pnpm supabase:migration up
 *   pnpm supabase:typegen
 *
 *   # 3. Detect breaking changes
 *   pnpm tsx scripts/detect-breaking-schema-changes.ts
 *
 * Exit codes:
 *   0 - No breaking changes or backup not found
 *   1 - Breaking changes detected (removed columns found in codebase)
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'fs';
import path from 'path';

interface TableSchema {
  name: string;
  columns: Set<string>;
}

interface RemovedColumn {
  table: string;
  column: string;
  possibleRename?: {
    newColumn: string;
    similarity: number;
  };
}

interface FileReference {
  filePath: string;
  table: string;
  column: string;
  lineNumbers: number[];
}

/**
 * Extract table schemas from database.types.ts
 * Reuses logic from validate-query-columns.ts
 */
function extractTableSchemas(schemaContent: string): Map<string, TableSchema> {
  const schemas = new Map<string, TableSchema>();
  const lines = schemaContent.split('\n');

  let currentTable: string | null = null;
  let inRow = false;
  let braceDepth = 0;
  let currentColumns = new Set<string>();

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    // Check if we're entering a table definition
    if (line.endsWith(': {') && !inRow && currentTable === null) {
      const tableMatch = line.match(/^(\w+):\s*\{$/);
      if (tableMatch) {
        // Check if next lines contain "Row:"
        for (let j = i + 1; j < Math.min(i + 5, lines.length); j++) {
          if (lines[j].includes('Row:')) {
            currentTable = tableMatch[1];
            break;
          }
        }
      }
    }

    // Check if we're in the Row section
    if (currentTable && line === 'Row: {') {
      inRow = true;
      braceDepth = 1;
      currentColumns = new Set();
      continue;
    }

    // Track brace depth in Row section
    if (inRow) {
      braceDepth += (line.match(/\{/g) || []).length;
      braceDepth -= (line.match(/\}/g) || []).length;

      // Extract column names while in Row section
      if (braceDepth > 0) {
        const columnMatch = line.match(/^(\w+):/);
        if (columnMatch) {
          currentColumns.add(columnMatch[1]);
        }
      }

      // End of Row section
      if (braceDepth === 0 && currentColumns.size > 0) {
        schemas.set(currentTable, {
          name: currentTable,
          columns: new Set(currentColumns),
        });
        currentTable = null;
        inRow = false;
      }
    }
  }

  return schemas;
}

/**
 * Calculate Levenshtein distance for fuzzy matching
 * Used to detect potential column renames
 */
function levenshteinDistance(a: string, b: string): number {
  const matrix: number[][] = [];

  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b.charAt(i - 1) === a.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1, // substitution
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j] + 1, // deletion
        );
      }
    }
  }

  return matrix[b.length][a.length];
}

/**
 * Calculate similarity score (0-1) between two strings
 */
function similarityScore(a: string, b: string): number {
  const distance = levenshteinDistance(a, b);
  const maxLength = Math.max(a.length, b.length);
  return 1 - distance / maxLength;
}

/**
 * Detect removed columns between old and new schemas
 */
function detectRemovedColumns(
  oldSchemas: Map<string, TableSchema>,
  newSchemas: Map<string, TableSchema>,
): RemovedColumn[] {
  const removedColumns: RemovedColumn[] = [];

  for (const [tableName, oldSchema] of oldSchemas.entries()) {
    const newSchema = newSchemas.get(tableName);

    // Table was removed entirely (rare but possible)
    if (!newSchema) {
      console.warn(`⚠️  Table '${tableName}' was removed entirely`);
      continue;
    }

    // Check each old column
    for (const oldColumn of oldSchema.columns) {
      if (!newSchema.columns.has(oldColumn)) {
        // Column was removed - check if it might have been renamed
        const possibleRename = findPossibleRename(
          oldColumn,
          newSchema.columns,
          oldSchema.columns,
        );

        removedColumns.push({
          table: tableName,
          column: oldColumn,
          possibleRename,
        });
      }
    }
  }

  return removedColumns;
}

/**
 * Find possible renamed column using fuzzy matching
 * Returns the most similar new column if similarity > 0.7
 */
function findPossibleRename(
  oldColumn: string,
  newColumns: Set<string>,
  oldColumns: Set<string>,
): { newColumn: string; similarity: number } | undefined {
  let bestMatch: { newColumn: string; similarity: number } | undefined;

  for (const newColumn of newColumns) {
    // Skip if this column existed in old schema (not a rename)
    if (oldColumns.has(newColumn)) {
      continue;
    }

    const similarity = similarityScore(oldColumn, newColumn);

    // Consider it a possible rename if similarity > 70%
    if (similarity > 0.7) {
      if (!bestMatch || similarity > bestMatch.similarity) {
        bestMatch = { newColumn, similarity };
      }
    }
  }

  return bestMatch;
}

/**
 * Find all files that reference a specific table and column
 */
function findColumnReferences(
  table: string,
  column: string,
  searchDirs: string[],
): FileReference[] {
  const references: FileReference[] = [];
  const pattern = /\.(ts|tsx)$/;

  for (const dir of searchDirs) {
    const files = findFiles(dir, pattern);

    for (const filePath of files) {
      try {
        const content = readFileSync(filePath, 'utf-8');
        const lines = content.split('\n');
        const matchingLines: number[] = [];

        // Check if file references both the table and column
        const hasTableRef =
          content.includes(`'${table}'`) || content.includes(`"${table}"`);
        const hasColumnRef =
          content.includes(`'${column}'`) || content.includes(`"${column}"`);

        if (hasTableRef && hasColumnRef) {
          // Find specific line numbers
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (
              (line.includes(`'${table}'`) || line.includes(`"${table}"`)) &&
              (line.includes(`'${column}'`) || line.includes(`"${column}"`))
            ) {
              matchingLines.push(i + 1);
            }
          }

          if (matchingLines.length > 0) {
            references.push({
              filePath: path.relative(process.cwd(), filePath),
              table,
              column,
              lineNumbers: matchingLines,
            });
          }
        }
      } catch {
        // Skip files that can't be read
      }
    }
  }

  return references;
}

/**
 * Recursively find files matching pattern
 * Reuses logic from validate-query-columns.ts
 */
function findFiles(
  dir: string,
  pattern: RegExp,
  files: string[] = [],
): string[] {
  try {
    const entries = readdirSync(dir);

    for (const entry of entries) {
      const fullPath = path.join(dir, entry);
      const stat = statSync(fullPath);

      if (stat.isDirectory()) {
        // Skip node_modules and hidden directories
        if (!entry.startsWith('.') && entry !== 'node_modules') {
          findFiles(fullPath, pattern, files);
        }
      } else if (stat.isFile() && pattern.test(entry)) {
        files.push(fullPath);
      }
    }
  } catch {
    // Skip directories we can't read
  }

  return files;
}

/**
 * Main detection function
 */
async function detectBreakingChanges(): Promise<void> {
  console.log('🔍 Detecting breaking database schema changes...\n');

  // Check if backup exists
  const backupPath = path.join(process.cwd(), 'lib', 'database.types.ts.bak');
  const currentPath = path.join(process.cwd(), 'lib', 'database.types.ts');

  if (!existsSync(backupPath)) {
    console.log('ℹ️  No schema backup found (database.types.ts.bak)');
    console.log(
      '   Create backup before schema changes: cp lib/database.types.ts lib/database.types.ts.bak\n',
    );
    process.exit(0);
  }

  if (!existsSync(currentPath)) {
    console.error('❌ Could not find database.types.ts');
    console.error('   Run: pnpm supabase:typegen');
    process.exit(1);
  }

  // Load old and new schemas
  const oldContent = readFileSync(backupPath, 'utf-8');
  const newContent = readFileSync(currentPath, 'utf-8');

  const oldSchemas = extractTableSchemas(oldContent);
  const newSchemas = extractTableSchemas(newContent);

  console.log(`✅ Loaded ${oldSchemas.size} old table schemas`);
  console.log(`✅ Loaded ${newSchemas.size} new table schemas\n`);

  // Detect removed columns
  const removedColumns = detectRemovedColumns(oldSchemas, newSchemas);

  if (removedColumns.length === 0) {
    console.log('✅ No breaking schema changes detected');
    console.log('   All columns from previous schema still exist.\n');
    process.exit(0);
  }

  // Report removed columns
  console.error(
    `❌ Breaking changes detected: ${removedColumns.length} column(s) removed\n`,
  );

  const searchDirs = [
    path.join(process.cwd(), 'app'),
    path.join(process.cwd(), 'lib'),
  ];

  let hasReferences = false;

  for (const { table, column, possibleRename } of removedColumns) {
    console.error(`📊 ${table}.${column} (removed)`);

    if (possibleRename) {
      const percentage = Math.round(possibleRename.similarity * 100);
      console.error(
        `   💡 Possible rename → ${table}.${possibleRename.newColumn} (${percentage}% similar)`,
      );
    }

    // Find files that reference this column
    const references = findColumnReferences(table, column, searchDirs);

    if (references.length > 0) {
      hasReferences = true;
      console.error(`   ⚠️  Referenced in ${references.length} file(s):`);

      for (const ref of references) {
        const lineRefs =
          ref.lineNumbers.length > 0 ? `:${ref.lineNumbers.join(', ')}` : '';
        console.error(`      - ${ref.filePath}${lineRefs}`);
      }
    } else {
      console.error(`   ✅ No references found in codebase`);
    }

    console.error('');
  }

  // Exit with error if any removed columns are still referenced
  if (hasReferences) {
    console.error('💡 Action required:');
    console.error('   1. Update queries to use new column names');
    console.error('   2. Remove references to deleted columns');
    console.error('   3. Run tests to verify changes\n');
    process.exit(1);
  } else {
    console.log('✅ No code references found for removed columns');
    console.log('   Safe to proceed with schema changes.\n');
    process.exit(0);
  }
}

// Run detection
detectBreakingChanges().catch((error) => {
  console.error('❌ Detection script failed:', error);
  process.exit(1);
});
