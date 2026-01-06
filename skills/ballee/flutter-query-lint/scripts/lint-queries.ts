#!/usr/bin/env npx ts-node

/**
 * Flutter Query Linter
 *
 * Validates Supabase queries in Flutter API files against database.types.ts schema.
 * Reports mismatches in table names, column names, relationships, and RPC functions.
 *
 * Usage: npx ts-node .claude/skills/flutter-query-lint/scripts/lint-queries.ts
 */
import * as fs from 'fs';
import * as path from 'path';

// Configuration
const PROJECT_ROOT = path.resolve(__dirname, '../../../../');
const FLUTTER_API_PATHS = [
  'apps/mobile/lib/modules/*/api/*.dart',
  'apps/mobile/lib/core/data/api/*.dart',
];
const DATABASE_TYPES_PATH = 'apps/web/lib/database.types.ts';

// Types
interface TableSchema {
  columns: Set<string>;
  relationships: Map<string, string>; // FK name -> referenced table
}

interface Schema {
  tables: Map<string, TableSchema>;
  functions: Set<string>;
}

interface QueryLocation {
  file: string;
  line: number;
  query: string;
}

interface LintError {
  location: QueryLocation;
  type: 'error' | 'warning';
  message: string;
  suggestion?: string;
}

// Glob implementation (simple, no dependencies)
function glob(pattern: string, baseDir: string): string[] {
  const results: string[] = [];
  const parts = pattern.split('/');

  function walk(dir: string, partIndex: number): void {
    if (partIndex >= parts.length) return;

    const part = parts[partIndex];
    const isLast = partIndex === parts.length - 1;

    if (!fs.existsSync(dir)) return;

    if (part === '*') {
      // Match any single directory/file
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (isLast) {
          if (entry.isFile()) results.push(fullPath);
        } else if (entry.isDirectory()) {
          walk(fullPath, partIndex + 1);
        }
      }
    } else if (part === '**') {
      // Match any depth
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      // Try matching current level
      walk(dir, partIndex + 1);
      // Recurse into subdirectories
      for (const entry of entries) {
        if (entry.isDirectory()) {
          walk(path.join(dir, entry.name), partIndex);
        }
      }
    } else if (part.includes('*')) {
      // Wildcard pattern like *.dart
      const regex = new RegExp('^' + part.replace(/\*/g, '.*') + '$');
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        if (regex.test(entry.name)) {
          const fullPath = path.join(dir, entry.name);
          if (isLast) {
            if (entry.isFile()) results.push(fullPath);
          } else if (entry.isDirectory()) {
            walk(fullPath, partIndex + 1);
          }
        }
      }
    } else {
      // Exact match
      const fullPath = path.join(dir, part);
      if (fs.existsSync(fullPath)) {
        if (isLast) {
          if (fs.statSync(fullPath).isFile()) results.push(fullPath);
        } else {
          walk(fullPath, partIndex + 1);
        }
      }
    }
  }

  walk(baseDir, 0);
  return results;
}

// Parse database.types.ts to extract schema using a more robust approach
function parseSchema(typesPath: string): Schema {
  const content = fs.readFileSync(typesPath, 'utf-8');
  const lines = content.split('\n');
  const schema: Schema = {
    tables: new Map(),
    functions: new Set(),
  };

  let inPublicSchema = false;
  let inTables = false;
  let inViews = false;
  let inFunctions = false;
  let currentTable: string | null = null;
  let currentSection: 'Row' | 'Insert' | 'Update' | 'Relationships' | null =
    null;
  let braceDepth = 0;
  let publicStartDepth = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Count braces for depth tracking (before processing)
    const openBraces = (line.match(/\{/g) || []).length;
    const closeBraces = (line.match(/\}/g) || []).length;

    // Detect public schema section (not graphql_public)
    if (line.match(/^\s{2}public:\s*\{/) && !inPublicSchema) {
      inPublicSchema = true;
      publicStartDepth = braceDepth;
    }

    // Detect end of public schema
    if (
      inPublicSchema &&
      line.match(/^\s{2}\};/) &&
      braceDepth === publicStartDepth + 1
    ) {
      inPublicSchema = false;
      inTables = false;
      inFunctions = false;
    }

    if (inPublicSchema) {
      // Detect Tables section
      if (line.match(/^\s{4}Tables:\s*\{/)) {
        inTables = true;
        inViews = false;
        inFunctions = false;
      }

      // Detect Views section (also parse views as they are queryable like tables)
      if (line.match(/^\s{4}Views:\s*\{/)) {
        inTables = false;
        inViews = true;
        currentTable = null;
      }

      // Detect Functions section
      if (line.match(/^\s{4}Functions:\s*\{/)) {
        inFunctions = true;
        inTables = false;
        inViews = false;
      }

      // Detect Enums section (end of Functions)
      if (line.match(/^\s{4}Enums:\s*\{/)) {
        inFunctions = false;
        inViews = false;
      }

      if (inTables) {
        // Detect new table definition: tableName: {
        const tableMatch = line.match(/^\s{6}(\w+):\s*\{/);
        if (tableMatch && !currentTable) {
          currentTable = tableMatch[1];
          schema.tables.set(currentTable, {
            columns: new Set(),
            relationships: new Map(),
          });
        }

        // Detect Row section
        if (currentTable && line.match(/^\s{8}Row:\s*\{/)) {
          currentSection = 'Row';
        }

        // Detect Relationships section
        if (currentTable && line.match(/^\s{8}Relationships:\s*\[/)) {
          currentSection = 'Relationships';
        }

        // Extract columns from Row section (handle both with and without semicolons)
        if (currentTable && currentSection === 'Row') {
          const colMatch = line.match(/^\s{10}(\w+):\s*.+[;]?$/);
          if (colMatch && !line.includes('{') && !line.includes('}')) {
            const table = schema.tables.get(currentTable);
            if (table) {
              table.columns.add(colMatch[1]);
            }
          }
        }

        // Detect end of Row section (when we see Insert:)
        if (currentSection === 'Row' && line.match(/^\s{8}Insert:\s*\{/)) {
          currentSection = null;
        }

        // Extract relationship info
        if (currentTable && currentSection === 'Relationships') {
          const refMatch = line.match(/referencedRelation:\s*['"](\w+)['"]/);
          if (refMatch) {
            // Look back for the column name
            for (let j = i - 1; j >= Math.max(0, i - 5); j--) {
              const colMatch = lines[j].match(/columns:\s*\[['"](\w+)['"]\]/);
              if (colMatch) {
                const table = schema.tables.get(currentTable);
                if (table) {
                  table.relationships.set(colMatch[1], refMatch[1]);
                }
                break;
              }
            }
          }
        }

        // Detect end of Relationships (closing bracket)
        if (currentSection === 'Relationships' && line.match(/^\s{8}\][;]?$/)) {
          currentSection = null;
        }

        // Detect end of table definition
        if (currentTable && line.match(/^\s{6}\}[;]?$/)) {
          currentTable = null;
          currentSection = null;
        }
      }

      // Parse Views section (views are queryable just like tables)
      if (inViews) {
        // Detect new view definition: viewName: {
        const viewMatch = line.match(/^\s{6}(\w+):\s*\{/);
        if (viewMatch && !currentTable) {
          currentTable = viewMatch[1]; // Reuse currentTable for view name
          schema.tables.set(currentTable, {
            columns: new Set(),
            relationships: new Map(),
          });
        }

        // Detect Row section
        if (currentTable && line.match(/^\s{8}Row:\s*\{/)) {
          currentSection = 'Row';
        }

        // Extract columns from Row section
        if (currentTable && currentSection === 'Row') {
          const colMatch = line.match(/^\s{10}(\w+):\s*.+[;]?$/);
          if (colMatch && !line.includes('{') && !line.includes('}')) {
            const table = schema.tables.get(currentTable);
            if (table) {
              table.columns.add(colMatch[1]);
            }
          }
        }

        // Detect end of Row section (when we see Insert: or closing brace)
        if (
          currentSection === 'Row' &&
          (line.match(/^\s{8}Insert:\s*\{/) || line.match(/^\s{8}\}/))
        ) {
          currentSection = null;
        }

        // Detect end of view definition
        if (currentTable && line.match(/^\s{6}\}[;]?$/)) {
          currentTable = null;
          currentSection = null;
        }
      }

      if (inFunctions) {
        // Extract function names - match lines like: functionName: { or functionName: { Args...
        const funcMatch = line.match(/^\s{6}(\w+):\s*\{/);
        if (funcMatch) {
          schema.functions.add(funcMatch[1]);
        }
      }
    }

    braceDepth += openBraces - closeBraces;
  }

  return schema;
}

// Extract queries from Dart file
interface ExtractedQuery {
  table?: string;
  columns: string[];
  relationships: Array<{
    alias?: string;
    table: string;
    fk?: string;
    columns: string[];
  }>;
  filters: Array<{ column: string; method: string }>;
  rpcName?: string;
  orderColumns: string[];
  line: number;
  rawQuery: string;
}

function extractQueries(filePath: string): ExtractedQuery[] {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const queries: ExtractedQuery[] = [];

  // Track multiline strings
  let inMultilineString = false;
  let multilineBuffer = '';
  let multilineStartLine = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNum = i + 1;

    // Check for .from('table_name') - but skip storage operations
    const fromMatch = line.match(/\.from\(['"](\w+)['"]\)/);
    // Skip if this is a storage operation (e.g., _client.storage.from('bucket'))
    const isStorageOperation =
      line.includes('.storage.from(') || line.includes('storage.from(');
    if (fromMatch && !isStorageOperation) {
      const query: ExtractedQuery = {
        table: fromMatch[1],
        columns: [],
        relationships: [],
        filters: [],
        orderColumns: [],
        line: lineNum,
        rawQuery: '',
      };

      // Look ahead for chained methods
      let j = i;
      let queryText = '';
      let parenDepth = 0;
      let inString = false;
      let stringChar = '';

      while (j < lines.length && j < i + 50) {
        // Limit lookahead
        const currentLine = lines[j];
        queryText += currentLine + '\n';

        // Simple state tracking for string boundaries
        for (const char of currentLine) {
          if (!inString && (char === "'" || char === '"')) {
            inString = true;
            stringChar = char;
          } else if (inString && char === stringChar) {
            inString = false;
          } else if (!inString) {
            if (char === '(') parenDepth++;
            if (char === ')') parenDepth--;
          }
        }

        // Check for end of query chain (semicolon outside string)
        if (!inString && currentLine.includes(';')) break;
        j++;
      }

      query.rawQuery = queryText;

      // Extract .select() content
      const selectMatch = queryText.match(
        /\.select\(\s*(?:'''|"""|['"])([\s\S]*?)(?:'''|"""|['"])\s*\)/,
      );
      if (selectMatch) {
        parseSelectContent(selectMatch[1], query);
      }

      // Extract filter methods
      const filterMethods = [
        'eq',
        'neq',
        'gt',
        'gte',
        'lt',
        'lte',
        'inFilter',
        'contains',
      ];
      for (const method of filterMethods) {
        const filterRegex = new RegExp(`\\.${method}\\(['"]([\\w.]+)['"]`, 'g');
        let filterMatch;
        while ((filterMatch = filterRegex.exec(queryText)) !== null) {
          query.filters.push({ column: filterMatch[1], method });
        }
      }

      // Extract .order()
      const orderRegex = /\.order\(['"](\w+)['"]/g;
      let orderMatch;
      while ((orderMatch = orderRegex.exec(queryText)) !== null) {
        query.orderColumns.push(orderMatch[1]);
      }

      queries.push(query);
    }

    // Check for .rpc('function_name')
    const rpcMatch = line.match(/\.rpc\(['"](\w+)['"]/);
    if (rpcMatch) {
      queries.push({
        rpcName: rpcMatch[1],
        columns: [],
        relationships: [],
        filters: [],
        orderColumns: [],
        line: lineNum,
        rawQuery: line,
      });
    }
  }

  return queries;
}

// Parse select content into columns and relationships (handles nested relationships)
function parseSelectContent(
  selectContent: string,
  query: ExtractedQuery,
): void {
  // Clean up whitespace and newlines
  const cleaned = selectContent.replace(/\s+/g, ' ').trim();

  // Split by commas (but not inside parentheses)
  const parts = splitByComma(cleaned);

  for (const part of parts) {
    if (part === '*') continue; // Skip wildcard

    // Check for relationship: alias:table!fk(columns) or table(columns)
    // Match patterns like:
    // - productions(id, name)
    // - role:cast_roles!cast_role_id(*)
    // - event:events!inner(id, title, production:productions(id, name))
    const relMatch = part.match(/^(?:(\w+):)?(\w+)(?:!(\w+))?\(([\s\S]*)\)$/);
    if (relMatch) {
      const alias = relMatch[1];
      const table = relMatch[2];
      const fk = relMatch[3];
      const innerContent = relMatch[4];

      // Parse inner columns, filtering out nested relationships
      const innerParts = splitByComma(innerContent);
      const simpleColumns: string[] = [];

      for (const innerPart of innerParts) {
        if (innerPart === '*') continue;
        // If it contains parentheses, it's a nested relationship - skip for column validation
        if (innerPart.includes('(')) continue;
        // If it's a simple identifier, it's a column
        if (/^\w+$/.test(innerPart)) {
          simpleColumns.push(innerPart);
        }
      }

      query.relationships.push({ alias, table, fk, columns: simpleColumns });
    } else if (part.includes('.')) {
      // Nested column reference like event.start_date_time - skip for now
      continue;
    } else if (/^\w+$/.test(part)) {
      // Simple column (only alphanumeric)
      query.columns.push(part);
    }
  }
}

// Split string by comma, respecting parentheses nesting
function splitByComma(str: string): string[] {
  const parts: string[] = [];
  let current = '';
  let depth = 0;

  for (const char of str) {
    if (char === '(') depth++;
    if (char === ')') depth--;
    if (char === ',' && depth === 0) {
      const trimmed = current.trim();
      if (trimmed) parts.push(trimmed);
      current = '';
    } else {
      current += char;
    }
  }
  const trimmed = current.trim();
  if (trimmed) parts.push(trimmed);

  return parts;
}

// Find similar strings for suggestions
function findSimilar(
  target: string,
  candidates: Iterable<string>,
  maxDistance: number = 3,
): string | undefined {
  let best: string | undefined;
  let bestDistance = maxDistance + 1;

  for (const candidate of candidates) {
    const distance = levenshteinDistance(
      target.toLowerCase(),
      candidate.toLowerCase(),
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }

  return bestDistance <= maxDistance ? best : undefined;
}

// Levenshtein distance
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
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1,
        );
      }
    }
  }

  return matrix[b.length][a.length];
}

// Validate queries against schema
function validateQueries(
  queries: ExtractedQuery[],
  schema: Schema,
  filePath: string,
): LintError[] {
  const errors: LintError[] = [];
  const relativePath = path.relative(PROJECT_ROOT, filePath);

  for (const query of queries) {
    const location: QueryLocation = {
      file: relativePath,
      line: query.line,
      query:
        query.rawQuery.substring(0, 100) +
        (query.rawQuery.length > 100 ? '...' : ''),
    };

    // Validate RPC function
    if (query.rpcName) {
      if (!schema.functions.has(query.rpcName)) {
        const suggestion = findSimilar(query.rpcName, schema.functions);
        errors.push({
          location,
          type: 'error',
          message: `RPC function '${query.rpcName}' does not exist`,
          suggestion: suggestion ? `Did you mean '${suggestion}'?` : undefined,
        });
      }
      continue;
    }

    // Validate table
    if (query.table) {
      if (!schema.tables.has(query.table)) {
        const suggestion = findSimilar(query.table, schema.tables.keys());
        errors.push({
          location,
          type: 'error',
          message: `Table '${query.table}' does not exist`,
          suggestion: suggestion ? `Did you mean '${suggestion}'?` : undefined,
        });
        continue; // Can't validate columns without table
      }

      const tableSchema = schema.tables.get(query.table)!;

      // Validate columns
      for (const col of query.columns) {
        if (!tableSchema.columns.has(col)) {
          const suggestion = findSimilar(col, tableSchema.columns);
          errors.push({
            location,
            type: 'error',
            message: `Column '${col}' does not exist on table '${query.table}'`,
            suggestion: suggestion
              ? `Did you mean '${suggestion}'?`
              : undefined,
          });
        }
      }

      // Validate filter columns
      for (const filter of query.filters) {
        // Handle nested filters like 'event.start_date_time'
        const colName = filter.column.includes('.')
          ? filter.column.split('.')[0]
          : filter.column;

        // Skip if it's a nested reference (we'd need to resolve the relationship)
        if (filter.column.includes('.')) continue;

        if (!tableSchema.columns.has(colName)) {
          const suggestion = findSimilar(colName, tableSchema.columns);
          errors.push({
            location,
            type: 'error',
            message: `Filter column '${colName}' does not exist on table '${query.table}'`,
            suggestion: suggestion
              ? `Did you mean '${suggestion}'?`
              : undefined,
          });
        }
      }

      // Validate order columns
      for (const col of query.orderColumns) {
        if (!tableSchema.columns.has(col)) {
          const suggestion = findSimilar(col, tableSchema.columns);
          errors.push({
            location,
            type: 'error',
            message: `Order column '${col}' does not exist on table '${query.table}'`,
            suggestion: suggestion
              ? `Did you mean '${suggestion}'?`
              : undefined,
          });
        }
      }

      // Validate relationships
      for (const rel of query.relationships) {
        // Check if relationship table exists
        if (!schema.tables.has(rel.table)) {
          const suggestion = findSimilar(rel.table, schema.tables.keys());
          errors.push({
            location,
            type: 'error',
            message: `Relationship table '${rel.table}' does not exist`,
            suggestion: suggestion
              ? `Did you mean '${suggestion}'?`
              : undefined,
          });
          continue;
        }

        // Validate nested columns
        const relTableSchema = schema.tables.get(rel.table)!;
        for (const col of rel.columns) {
          if (col === '*') continue;
          if (!relTableSchema.columns.has(col)) {
            const suggestion = findSimilar(col, relTableSchema.columns);
            errors.push({
              location,
              type: 'error',
              message: `Column '${col}' does not exist on related table '${rel.table}'`,
              suggestion: suggestion
                ? `Did you mean '${suggestion}'?`
                : undefined,
            });
          }
        }
      }
    }
  }

  return errors;
}

// Main function
function main(): void {
  console.log('# Flutter Query Lint Report\n');
  console.log(`**Date**: ${new Date().toISOString().split('T')[0]}`);

  // Parse schema
  const schemaPath = path.join(PROJECT_ROOT, DATABASE_TYPES_PATH);
  if (!fs.existsSync(schemaPath)) {
    console.error(`Error: Schema file not found at ${schemaPath}`);
    process.exit(1);
  }

  console.log(`**Schema**: ${DATABASE_TYPES_PATH}`);
  const schema = parseSchema(schemaPath);
  console.log(`**Tables found**: ${schema.tables.size}`);
  console.log(`**Functions found**: ${schema.functions.size}\n`);

  // Find all Dart files
  const dartFiles: string[] = [];
  for (const pattern of FLUTTER_API_PATHS) {
    const files = glob(pattern, PROJECT_ROOT);
    dartFiles.push(...files);
  }

  console.log(`**Files scanned**: ${dartFiles.length}\n`);

  if (dartFiles.length === 0) {
    console.log('No Flutter API files found.');
    return;
  }

  // Process each file
  const allErrors: LintError[] = [];
  let totalQueries = 0;

  for (const file of dartFiles) {
    const queries = extractQueries(file);
    totalQueries += queries.length;

    const errors = validateQueries(queries, schema, file);
    allErrors.push(...errors);
  }

  console.log(`**Total queries**: ${totalQueries}`);
  console.log(`**Total issues**: ${allErrors.length}\n`);

  // Group errors by type
  const errorList = allErrors.filter((e) => e.type === 'error');
  const warningList = allErrors.filter((e) => e.type === 'warning');

  if (errorList.length > 0) {
    console.log('## Errors (Must Fix)\n');
    for (const error of errorList) {
      console.log(`### ${error.location.file}:${error.location.line}`);
      console.log(`- **Issue**: ${error.message}`);
      if (error.suggestion) {
        console.log(`- **Suggestion**: ${error.suggestion}`);
      }
      console.log('');
    }
  }

  if (warningList.length > 0) {
    console.log('## Warnings\n');
    for (const warning of warningList) {
      console.log(`### ${warning.location.file}:${warning.location.line}`);
      console.log(`- **Issue**: ${warning.message}`);
      if (warning.suggestion) {
        console.log(`- **Suggestion**: ${warning.suggestion}`);
      }
      console.log('');
    }
  }

  if (allErrors.length === 0) {
    console.log('## Result\n');
    console.log('No issues found! All queries are valid.\n');
  }

  // Summary
  console.log('## Summary\n');
  console.log(`| Metric | Count |`);
  console.log(`|--------|-------|`);
  console.log(`| Files scanned | ${dartFiles.length} |`);
  console.log(`| Queries validated | ${totalQueries} |`);
  console.log(`| Errors | ${errorList.length} |`);
  console.log(`| Warnings | ${warningList.length} |`);

  // Exit with error code if there are errors
  if (errorList.length > 0) {
    process.exit(1);
  }
}

main();
