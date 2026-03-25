# YLE Teksti-TV price scraper (Perl)

Fetches **tomorrow’s electricity prices** from YLE Teksti-TV and outputs them as a clean numeric stream.

The idea is simple: don’t trust layout, just find the numbers.

## Default data source

By default the script reads:

https://yle.fi/tekstitv/txt/189_0003.htm  
https://yle.fi/tekstitv/txt/189_0004.htm

These pages contain **tomorrow’s prices** (96 quarter-hour values).

## What it does

- Downloads two Teksti-TV pages
- Strips HTML and scans all text
- Accepts only lines with **exactly 4 numeric values** (Finnish format: `0,37`)
- Collects **12 rows per page**
- Converts values to floats (`0.37`)
- Outputs **96 values total** (48 per page)

## Output format

Values are printed in **column-major order**:

col1 rows 0..11  
col2 rows 0..11  
col3 rows 0..11  
col4 rows 0..11  

First page first, then second page.

One value per line.

## Usage

Run with defaults (tomorrow’s prices):

perl fetch_yle_prices.pl

Enable debug output:

perl fetch_yle_prices.pl --debug

Use custom pages:

perl fetch_yle_prices.pl URL1 URL2

## Why this approach

Teksti-TV is not an API.

So instead of trusting layout:
- scan everything
- accept only valid rows
- stop when enough data is collected

Same principle as any engineering:
don’t rely on assumptions that can drift.

## Dependencies

- HTTP::Tiny  
- Encode  
- Getopt::Long  

(All are standard in most Perl installations.)

## Notes

- Assumes exactly **12 rows × 4 values per page**
- Fails fast if structure changes
- No averaging — raw values only
- Output = **96 quarter-hour prices for tomorrow**
