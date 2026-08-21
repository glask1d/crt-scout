# crt-scout

**Fast subdomain discovery + live checking + wordlist generation** powered by [crt.name](https://crt.name).

`crt-scout` queries the Certificate Transparency index, optionally verifies which hosts are actually alive, and can extract clean subdomain prefixes to help you build high-quality custom wordlists.

---

## Features

- ⚡ Extremely fast subdomain enumeration via crt.name
- 🔍 Optional live host checking (HTTP/HTTPS) with customizable User-Agent
- 📝 Automatic extraction of subdomain prefixes for wordlist building
- 📁 Flexible output options (full list, live results, wordlist)
- 🚀 Parallel checking for speed
- 🆓 No API key required (1000 requests/IP/day free tier)

---

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/crt-scout.git
cd crt-scout
chmod +x crt-scout.sh
```

## Options

```
-c, --check
Check which subdomains are alive

--https-only
Only probe HTTPS (skip HTTP)

--ua <string>
Custom User-Agent for live checks

-o, --output <file>
Save results to a file

-w, --wordlist <file>
Extract unique subdomain prefixes to a wordlist

--dates, -d
Include first-seen dates from crt.name

--timeout <sec>
Connection timeout (default: 5)

-h, --help
Show help
```

## Examples

```
Basic enumeration
./crt-scout.sh x.com

Live check + save results
./crt-scout.sh x.com --check -o live.txt

Build a wordlist of subdomain prefixes
./crt-scout.sh x.com -w x-words.txt

Full power: live check + wordlist + custom UA
./crt-scout.sh microsoft.com --check --https-only \
  --ua "crt-scout/1.0" \
  -o live-ms.txt \
  -w ms-words.txt
```
