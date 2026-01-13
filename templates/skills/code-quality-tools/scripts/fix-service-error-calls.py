#!/usr/bin/env python3
"""
Fix Result.fail() calls to use ServiceError instances
"""

import re
import sys

def fix_result_fail(content):
    """Replace Result.fail({...}) with Result.fail(new ServiceError(...))"""

    # Pattern: Result.fail({ code: 'X', message: 'Y', details: {...} })
    # This is a simpler pattern that works line-by-line for most cases

    lines = content.split('\n')
    result_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check if line contains Result.fail({
        if 'Result.fail({' in line:
            # Collect the full statement (may span multiple lines)
            statement = line
            depth = line.count('{') - line.count('}')

            while depth > 0 and i + 1 < len(lines):
                i += 1
                statement += '\n' + lines[i]
                depth += lines[i].count('{') - lines[i].count('}')

            # Now extract code, message, details
            code_match = re.search(r"code:\s*['\"]([^'\"]+)['\"]", statement)
            message_match = re.search(r"message:\s*['\"]([^'\"]*)['\"]", statement)
            details_match = re.search(r"details:\s*({[^}]+})", statement)

            if code_match and message_match:
                code = code_match.group(1)
                message = message_match.group(1)
                details = details_match.group(1) if details_match else 'undefined'

                # Get indentation
                indent = re.match(r'(\s*)', statement).group(1)

                # Replace with new ServiceError
                new_statement = f"{indent}return Result.fail(new ServiceError('{code}', '{message}', undefined, {details}));"

                result_lines.append(new_statement)
            else:
                # Couldn't parse, keep original
                result_lines.append(statement)
        else:
            result_lines.append(line)

        i += 1

    return '\n'.join(result_lines)

if __name__ == '__main__':
    file_path = sys.argv[1] if len(sys.argv) > 1 else '../../packages/features/events/src/server/actions/invitation-actions.ts'

    with open(file_path, 'r') as f:
        content = f.read()

    fixed_content = fix_result_fail(content)

    with open(file_path, 'w') as f:
        f.write(fixed_content)

    print(f"✅ Fixed ServiceError calls in {file_path}")
