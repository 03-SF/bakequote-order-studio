"""Syntax checks only: does not execute migrations or prove RLS behavior."""
from pathlib import Path
import re
import pglast

for path in sorted(Path('supabase').rglob('*.sql')):
    source = path.read_text(encoding='utf-8-sig')
    statements = pglast.parse_sql(source)
    for function in re.findall(r'create function\b.*?\$\$;', source, flags=re.I | re.S):
        pglast.parse_plpgsql(function)
    print(f'PARSED {path.as_posix()}: {len(statements)} SQL statements')
