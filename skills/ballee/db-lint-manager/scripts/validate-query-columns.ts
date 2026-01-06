/**
 * Column Existence Validation Script
 *
 * Validates that all database column references in service files match the actual database schema.
 * This prevents runtime errors from invalid column references by catching them at build time.
 *
 * Usage:
 *   pnpm tsx scripts/validate-query-columns.ts
 *
 * Exit codes:
 *   0 - All validations passed
 *   1 - Validation failures found
 */
import { readdirSync, readFileSync, statSync } from 'fs';
import path from 'path';

// Regular expressions to extract database operations
const EQ_REGEX = /\.eq\(['"](\w+)['"],/g;
const SELECT_REGEX = /\.select\(['"]([\w,\s*()]+)['"]\)/g;
const ORDER_REGEX = /\.order\(['"](\w+)['"]/g;
const IN_REGEX = /\.in\(['"](\w+)['"]/g;
const NEQ_REGEX = /\.neq\(['"](\w+)['"]/g;

interface ValidationError {
  file: string;
  table: string;
  column: string;
  line?: number;
  operation: string;
}

interface TableSchema {
  name: string;
  columns: Set<string>;
}

/**
 * Extract table schemas from database.types.ts
 */
function extractTableSchemas(schemaContent: string): Map<string, TableSchema> {
  const schemas = new Map<string, TableSchema>();

  // Split content into lines for easier parsing
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
 * Extract table and column references from a file
 * Improved to better track query chains and avoid false positives
 */
function extractReferences(
  content: string,
  _filePath: string,
): Map<string, Set<string>> {
  const references = new Map<string, Set<string>>();

  // Split content into logical query blocks by looking for .from() calls
  // Then analyze each query chain separately
  const lines = content.split('\n');
  let currentTable: string | null = null;
  let inQueryChain = false;
  let queryBuffer = '';

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Detect start of a new query chain
    const tableMatch = line.match(/\.from\(['"](\w+)['"]\)/);
    if (tableMatch) {
      // Process previous query buffer if exists
      if (currentTable && queryBuffer) {
        processQueryBuffer(currentTable, queryBuffer, references);
      }

      currentTable = tableMatch[1];
      queryBuffer = line;
      inQueryChain = true;

      if (!references.has(currentTable)) {
        references.set(currentTable, new Set());
      }
      continue;
    }

    // Continue building query buffer if we're in a chain
    if (inQueryChain) {
      queryBuffer += '\n' + line;

      // End query chain on statement terminators
      if (
        line.includes(';') ||
        line.includes('await') ||
        line.trim().endsWith('}')
      ) {
        if (currentTable) {
          processQueryBuffer(currentTable, queryBuffer, references);
        }
        currentTable = null;
        queryBuffer = '';
        inQueryChain = false;
      }
    }
  }

  // Process any remaining buffer
  if (currentTable && queryBuffer) {
    processQueryBuffer(currentTable, queryBuffer, references);
  }

  return references;
}

/**
 * Process a query buffer and extract column references
 */
function processQueryBuffer(
  tableName: string,
  buffer: string,
  references: Map<string, Set<string>>,
) {
  // Extract columns from various operations
  const eqMatches = [...buffer.matchAll(EQ_REGEX)];
  const orderMatches = [...buffer.matchAll(ORDER_REGEX)];
  const inMatches = [...buffer.matchAll(IN_REGEX)];
  const neqMatches = [...buffer.matchAll(NEQ_REGEX)];

  for (const match of [
    ...eqMatches,
    ...orderMatches,
    ...inMatches,
    ...neqMatches,
  ]) {
    references.get(tableName)!.add(match[1]);
  }

  // Extract columns from select statements (only top-level, not nested)
  const selectMatches = [...buffer.matchAll(SELECT_REGEX)];
  for (const selectMatch of selectMatches) {
    const selectClause = selectMatch[1];

    // Skip if this appears to be a nested select (contains parentheses)
    if (selectClause.includes('(')) {
      continue;
    }

    // Parse simple column names
    const columns = selectClause.split(',').map((c) => c.trim());

    for (const column of columns) {
      // Only validate simple column names (not nested relations or functions)
      if (/^\w+$/.test(column) && column !== '*' && column !== 'count') {
        references.get(tableName)!.add(column);
      }
    }
  }
}

/**
 * Validate that all column references exist in the schema
 */
function validateReferences(
  references: Map<string, Set<string>>,
  schemas: Map<string, TableSchema>,
  filePath: string,
): ValidationError[] {
  const errors: ValidationError[] = [];

  for (const [tableName, columns] of references.entries()) {
    const schema = schemas.get(tableName);

    if (!schema) {
      // Table not found in schema - might be a view
      console.warn(
        `⚠️  Table '${tableName}' not found in schema (might be a view)`,
      );
      continue;
    }

    for (const column of columns) {
      if (!schema.columns.has(column)) {
        errors.push({
          file: filePath,
          table: tableName,
          column,
          operation: 'query',
        });
      }
    }
  }

  return errors;
}

/**
 * Recursively find files matching pattern
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
 * Main validation function
 */
async function validateQueries(): Promise<void> {
  console.log('🔍 Validating database query columns...\n');

  // Read database schema
  const schemaPath = path.join(process.cwd(), 'lib', 'database.types.ts');

  try {
    readFileSync(schemaPath);
  } catch {
    console.error('❌ Could not find database.types.ts');
    console.error('   Run: pnpm supabase:typegen');
    process.exit(1);
  }

  const schemaContent = readFileSync(schemaPath, 'utf-8');
  const schemas = extractTableSchemas(schemaContent);

  console.log(`✅ Loaded ${schemas.size} table schemas\n`);

  // Find all service and action files
  const appDir = path.join(process.cwd(), 'app');
  const serviceFiles = findFiles(appDir, /\.(service|actions)\.ts$/);

  console.log(`📁 Scanning ${serviceFiles.length} service files...\n`);

  let totalErrors = 0;
  const errorsByFile = new Map<string, ValidationError[]>();

  // Validate each file
  for (const filePath of serviceFiles) {
    const content = readFileSync(filePath, 'utf-8');
    const references = extractReferences(content, filePath);
    const errors = validateReferences(references, schemas, filePath);

    if (errors.length > 0) {
      const relativePath = path.relative(process.cwd(), filePath);
      errorsByFile.set(relativePath, errors);
      totalErrors += errors.length;
    }
  }

  // Report errors
  if (totalErrors > 0) {
    console.error(`❌ Found ${totalErrors} invalid column reference(s):\n`);

    for (const [filePath, errors] of errorsByFile.entries()) {
      console.error(`📄 ${filePath}:`);

      for (const error of errors) {
        console.error(
          `   - Column '${error.column}' does not exist on table '${error.table}'`,
        );
      }

      console.error('');
    }

    console.error('💡 Fix these references or update the database schema.\n');
    process.exit(1);
  }

  console.log('✅ All query columns validated successfully!');
  console.log(
    `   Validated ${serviceFiles.length} files across ${schemas.size} tables.\n`,
  );
}

// Run validation
validateQueries().catch((error) => {
  console.error('❌ Validation script failed:', error);
  process.exit(1);
});
