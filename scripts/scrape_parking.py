"""
Merge Hygglo + Finn parking ads into a single Tuno-staging JSON.
"""
import os, re, json, glob
from datetime import datetime

# ---------- Helpers ----------

DAY_PATTERNS = [
    (re.compile(r'(\d[\d\s.,]*)\s*(?:kr|,-|nok)\s*(?:per|pr\.?|i)?\s*døgn', re.I), 'DAY', 1),
    (re.compile(r'(\d[\d\s.,]*)\s*(?:kr|,-|nok)\s*(?:per|pr\.?|i)?\s*dag(?:en)?\b', re.I), 'DAY', 1),
    (re.compile(r'\bdagsleie\s*[:\-]?\s*(\d[\d\s.,]*)\s*(?:kr|,-)', re.I), 'DAY', 1),
]
WEEK_PATTERNS = [
    (re.compile(r'(\d[\d\s.,]*)\s*(?:kr|,-|nok)\s*(?:per|pr\.?|i)?\s*uke(?:n)?', re.I), 'WEEK', 1),
    (re.compile(r'\bukesleie\s*[:\-]?\s*(\d[\d\s.,]*)\s*(?:kr|,-)', re.I), 'WEEK', 1),
]
MONTH_PATTERNS = [
    (re.compile(r'(\d[\d\s.,]*)\s*(?:kr|,-|nok)\s*(?:per|pr\.?|i|/)\s*(?:måned|mnd)', re.I), 'MONTH', 1),
    (re.compile(r'(?:per|pr\.?|i|/)\s*(?:måned|mnd)[\s.:\-]+(\d[\d\s.,]*)\s*(?:kr|,-)', re.I), 'MONTH', 1),
    (re.compile(r'\bmånedspris\s*[:\-]?\s*(\d[\d\s.,]*)\s*(?:kr|,-)', re.I), 'MONTH', 1),
    (re.compile(r'\bmånedsleie\s*(?:er\s+)?(?:på\s+)?[:\-]?\s*(\d[\d\s.,]*)\s*(?:kr|,-)?', re.I), 'MONTH', 1),
    (re.compile(r'(\d[\d\s.,]*)\s*kr/mnd', re.I), 'MONTH', 1),
    (re.compile(r'(\d[\d\s.,]*)\s*kr\s*i\s*måneden', re.I), 'MONTH', 1),
]
YEAR_PATTERNS = [
    (re.compile(r'(\d[\d\s.,]*)\s*(?:kr|,-|nok)\s*(?:per|pr\.?|i)?\s*år', re.I), 'YEAR', 1),
    (re.compile(r'\bårsleie\s*[:\-]?\s*(\d[\d\s.,]*)\s*(?:kr|,-)', re.I), 'YEAR', 1),
]
HOUR_PATTERNS = [
    (re.compile(r'(\d[\d\s.,]*)\s*(?:kr|,-|nok)\s*(?:per|pr\.?|i)?\s*time', re.I), 'HOUR', 1),
    (re.compile(r'\btimespris\s*[:\-]?\s*(\d[\d\s.,]*)\s*(?:kr|,-)', re.I), 'HOUR', 1),
]
# Custom: "X kroner for N måneder"
CUSTOM = re.compile(r'(\d[\d\s.,]*)\s*(?:kr|kroner|,-|nok)\s*(?:eks\.?\s*mva\s*)?(?:for|i)\s*(\d+)\s*(måneder|mnd|måned|uker|uke|dager|dag|år)', re.I)


def parse_int(s):
    n = re.sub(r'[\s.,]', '', str(s))
    try:
        v = int(n)
        return v if 1 <= v < 1_000_000 else None
    except:
        return None


def extract_desc_packages(text):
    if not text:
        return []
    out = []
    seen = set()  # (type, value, price)
    def add(type_, val, price, raw):
        key = (type_, val, price)
        if key in seen or not price:
            return
        seen.add(key)
        out.append({'period_type': type_, 'period_value': val, 'price_nok': price, 'source': 'DESCRIPTION_TEXT'})
    
    for patterns in (HOUR_PATTERNS, DAY_PATTERNS, WEEK_PATTERNS, MONTH_PATTERNS, YEAR_PATTERNS):
        for pat, ptype, pval in patterns:
            for m in pat.finditer(text):
                price = parse_int(m.group(1))
                if price:
                    add(ptype, pval, price, m.group(0))
    
    for m in CUSTOM.finditer(text):
        price = parse_int(m.group(1))
        n = int(m.group(2))
        unit = m.group(3).lower()
        type_ = None
        if 'dag' in unit: type_ = 'DAY'
        elif 'uke' in unit: type_ = 'WEEK'
        elif 'måned' in unit or 'mnd' in unit: type_ = 'MONTH'
        elif 'år' in unit: type_ = 'YEAR'
        if price and type_ and n:
            add(type_, n, price, m.group(0))
    
    return out


def extract_opening_hours(text):
    if not text:
        return []
    text_lower = text.lower()
    out = []
    seen = set()
    
    # Determine day-range hint
    # Look for "mandag-fredag" or "man-fre" first; default to 1..7
    default_dow = [1,2,3,4,5,6,7]
    
    def find_dow(ctx):
        c = ctx.lower()
        if re.search(r'\bman\s*[-–—]\s*fre\b|\bmandag\s*[-–—]\s*fredag\b|\bukedager\b|\bhverdager\b', c):
            return [1,2,3,4,5]
        if re.search(r'\bhelg\b|\blør\s*[-–—]\s*søn\b|\blørdag\s*[-–—]\s*søndag\b', c):
            return [6,7]
        if re.search(r'\balle\s+dager\b|\bhver\s+dag\b|\bhele\s+uka\b', c):
            return [1,2,3,4,5,6,7]
        return None
    
    # Pattern 1: hh:mm-hh:mm or hh.mm-hh.mm
    for m in re.finditer(r'\b(\d{1,2})[.:](\d{2})\s*[-–—]\s*(\d{1,2})[.:](\d{2})\b', text):
        h1, mn1, h2, mn2 = int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))
        if h1 > 23 or h2 > 23: continue
        idx = m.start()
        ctx = text[max(0, idx-100):idx+100]
        ctx_l = ctx.lower()
        if 'visning' in ctx_l or 'fremvisning' in ctx_l: continue
        # skip dates like "01.01-31.12"
        if h1 in (0,) and h2 == 0: continue
        dow = find_dow(ctx) or default_dow
        ts = f'{h1:02d}:{mn1:02d}'
        te = f'{h2:02d}:{mn2:02d}'
        key = (tuple(dow), ts, te)
        if key in seen: continue
        seen.add(key)
        out.append({'days_of_week': dow, 'time_start': ts, 'time_end': te})
    
    # Pattern 2: "kl. 08-16" style (no minutes)
    for m in re.finditer(r'kl\.?\s*(\d{1,2})\s*[-–—]\s*(\d{1,2})\b(?!\s*[.:])', text, re.I):
        h1, h2 = int(m.group(1)), int(m.group(2))
        if h1 > 23 or h2 > 23: continue
        idx = m.start()
        ctx = text[max(0, idx-100):idx+100]
        ctx_l = ctx.lower()
        if 'visning' in ctx_l or 'fremvisning' in ctx_l: continue
        dow = find_dow(ctx) or default_dow
        ts = f'{h1:02d}:00'
        te = f'{h2:02d}:00'
        key = (tuple(dow), ts, te)
        if key in seen: continue
        seen.add(key)
        out.append({'days_of_week': dow, 'time_start': ts, 'time_end': te})
    
    return out


def extract_features(text):
    if not text: text = ''
    return {
        'ev_charging': bool(re.search(r'elbil|el-bil|el\s*lader|elbillader|lader\b|lading|ladekabel|charging|ladeboks|ladestasjon', text, re.I)),
        'heated': bool(re.search(r'oppvarmet|varm\s+garasje|varmtvann', text, re.I)),
        'indoor': bool(re.search(r'innendørs|garasje|lukket\s+anlegg|parkeringskjeller|p[-\s]hus|garasjeanlegg', text, re.I)),
        'outdoor': bool(re.search(r'utendørs|ute\s+plass|carport|asfaltert\s+ute', text, re.I)),
        'surveillance': bool(re.search(r'overvåk|kamera|videoovervåk|bevoktet|alarm', text, re.I)),
        'covered': bool(re.search(r'carport|tak\s+over|under\s+tak', text, re.I)),
        'gated': bool(re.search(r'portåpner|elektronisk\s+port|fjernstyrt\s+port|automatisk\s+port|lukket\s+port|nøkkel(?:brikke)?', text, re.I)),
        'max_height_cm': (lambda m: int(m.group(1)) if m else None)(re.search(r'(?:max(?:imal)?|maks(?:imal)?)\s*h?ø?yde\s*[:\-]?\s*(\d{2,3})\s*cm', text, re.I)),
        'max_length_cm': (lambda m: int(m.group(1)) if m else None)(re.search(r'(?:max(?:imal)?|maks(?:imal)?)\s*lengde\s*[:\-]?\s*(\d{2,3})\s*cm', text, re.I)),
    }


# ---------- Hygglo parser ----------

def parse_hygglo_ad(html, slug):
    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if not m:
        return None
    try:
        data = json.loads(m.group(1))
    except Exception as e:
        return None
    pl = data.get('props', {}).get('pageProps', {}).get('productListing')
    if not pl:
        return None
    p = pl.get('product', {})
    loc = pl.get('location') or {}
    bestloc = loc.get('bestLocation') or {}
    coords = (bestloc.get('position') or {}).get('coordinates') or []
    
    # platform tier prices
    platform_pkgs = []
    for pp in (p.get('prices') or []):
        days = pp.get('days')
        price = pp.get('price')
        if days == 1:
            platform_pkgs.append({'period_type': 'DAY', 'period_value': 1, 'price_nok': price, 'source': 'PLATFORM_TIER'})
        elif days == 7:
            platform_pkgs.append({'period_type': 'WEEK', 'period_value': 1, 'price_nok': price, 'source': 'PLATFORM_TIER'})
        else:
            platform_pkgs.append({'period_type': 'DAY', 'period_value': days, 'price_nok': price, 'source': 'PLATFORM_TIER'})
    
    desc = p.get('description') or ''
    desc_pkgs = extract_desc_packages(desc)
    
    # dedupe: prefer platform tier
    seen = set((x['period_type'], x['period_value'], x['price_nok']) for x in platform_pkgs)
    pkgs = list(platform_pkgs)
    for d in desc_pkgs:
        key = (d['period_type'], d['period_value'], d['price_nok'])
        if key not in seen:
            pkgs.append(d)
            seen.add(key)
    
    images = [(img.get('fullSizeUrl') or img.get('thumbnailUrl') or img.get('url') or img.get('src') or '') for img in (p.get('images') or [])]
    images = [u for u in images if u and u.startswith('http')]
    
    title = p.get('name') or ''
    is_wanted = bool(re.search(r'(søker|ønsker\s+(?:å\s+)?(?:leie|kjøpe)|looking\s+for|trenger\s+å\s+leie)', title, re.I))
    
    return {
        'source': 'hygglo',
        'source_id': pl.get('slug') or slug,
        'url': pl.get('publicUrl') or f'https://www.hygglo.no/i/{slug}',
        'title': title,
        'description': desc,
        'address': loc.get('street'),
        'zip': loc.get('zip'),
        'municipality': loc.get('municipality'),
        'fylke': loc.get('label') or bestloc.get('name'),
        'lat': coords[1] if len(coords) >= 2 else (loc.get('zipLatitude')),
        'lng': coords[0] if len(coords) >= 2 else (loc.get('zipLongitude')),
        'currency': p.get('currency') or 'NOK',
        'min_rental_days': p.get('minimumRentalDays'),
        'price_packages': pkgs,
        'opening_hours': extract_opening_hours((title or '') + '\n' + desc),
        'features': extract_features((title or '') + ' ' + desc),
        'primary_image_url': images[0] if images else None,
        'image_urls': images,
        'seller_type': 'wanted' if is_wanted else 'private',  # Hygglo doesn't expose org clearly
        'org_name': None,
        'lease_period': None,
    }


# ---------- Finn parser ----------

def parse_finn_ad(html, finnkode):
    out = {
        'source': 'finn',
        'source_id': finnkode,
        'url': f'https://www.finn.no/realestate/lettings/ad.html?finnkode={finnkode}',
    }
    m = re.search(r'<title[^>]*>([^<]+?)\s*\|\s*FINN eiendom</title>', html)
    out['title'] = m.group(1).strip() if m else None
    m = re.search(r'<div class="description-area[^"]*">(.*?)</div>', html, re.DOTALL)
    desc_html = m.group(1) if m else ''
    desc_text = re.sub(r'<[^>]+>', ' ', desc_html).strip() if desc_html else ''
    # Strip the h3 heading "Beskrivelse" if it's the only content
    if desc_text == 'Beskrivelse' or desc_text.lower() == 'beskrivelse':
        desc_text = ''
    elif desc_text.startswith('Beskrivelse '):
        desc_text = desc_text[len('Beskrivelse '):].strip()
    out['description'] = desc_text
    m = re.search(r'<span itemprop="address"[^>]*>([^<]+)</span>|address" class="pl-4">([^<]+)</span>', html)
    if m:
        out['address'] = (m.group(1) or m.group(2)).strip()
    # Try to find postal code/zip in address
    if out.get('address'):
        m = re.search(r'(\d{4})\s+(\S+)', out['address'])
        if m:
            out['zip'] = m.group(1)
    # Monthly price
    monthly = None
    m = re.search(r'Månedsleie\s*</dt>\s*<dd[^>]*>(.*?)</dd>', html, re.DOTALL)
    if m:
        v = parse_int(re.sub(r'[^\d]', '', m.group(1)))
        if v: monthly = v
    if monthly is None:
        m = re.search(r'price_monthly[^"]*"[^"]*value"[^"]*"\["?(\d+)', html)
        if m: monthly = int(m.group(1))
    
    pkgs = []
    if monthly:
        pkgs.append({'period_type': 'MONTH', 'period_value': 1, 'price_nok': monthly, 'source': 'PLATFORM_TIER'})
    
    # Description-based packages
    desc_pkgs = extract_desc_packages(out['description'])
    seen = set((x['period_type'], x['period_value'], x['price_nok']) for x in pkgs)
    for d in desc_pkgs:
        key = (d['period_type'], d['period_value'], d['price_nok'])
        if key not in seen:
            pkgs.append(d); seen.add(key)
    out['price_packages'] = pkgs
    
    # Deposit
    m = re.search(r'Depositum\s*</dt>\s*<dd[^>]*>(.*?)</dd>', html, re.DOTALL)
    if m:
        v = parse_int(re.sub(r'[^\d]', '', m.group(1)))
        if v: out['deposit_nok'] = v
    
    # Lease period
    m = re.search(r'Leieperiode\s*</dt>\s*<dd[^>]*>(.*?)</dd>', html, re.DOTALL)
    if m:
        out['lease_period'] = re.sub(r'<[^>]+>', '', m.group(1)).strip()
    
    # Floor
    m = re.search(r'Etasje\s*</dt>\s*<dd[^>]*>(.*?)</dd>', html, re.DOTALL)
    if m:
        out['floor'] = re.sub(r'<[^>]+>', '', m.group(1)).strip()
    
    # Breadcrumbs => fylke / kommune
    crumb = re.findall(r'<a href="/realestate/lettings/search\.html\?location=[^"]+" class="s-text-link">([^<]+)</a>', html)
    out['fylke'] = crumb[0] if crumb else None
    out['kommune'] = crumb[-1] if len(crumb) > 1 else (crumb[0] if crumb else None)
    out['municipality'] = out.get('kommune')
    
    # Lat/lng - find in JSON blob (Finn uses serialized format)
    m = re.search(r'\\"lat\\"\s*,\s*([\d.-]+)\s*,\s*\\"lng\\"\s*,\s*([\d.-]+)', html)
    if m:
        out['lat'] = float(m.group(1))
        out['lng'] = float(m.group(2))
    m = re.search(r'"latitude"\s*:\s*([\d.]+)\s*,\s*"longitude"\s*:\s*([\d.]+)', html)
    if m:
        out['lat'] = float(m.group(1)); out['lng'] = float(m.group(2))
    else:
        # try alt format
        m = re.search(r'\\"latitude\\"\s*,\s*([\d.]+)', html)
        if m: out['lat'] = float(m.group(1))
        m = re.search(r'\\"longitude\\"\s*,\s*([\d.]+)', html)
        if m: out['lng'] = float(m.group(1))
    
    # Images - find og:image and other image URLs
    images = []
    for m in re.finditer(r'<meta property="og:image"\s+content="([^"]+)"', html):
        images.append(m.group(1))
    # gallery images from finncdn
    for m in re.finditer(r'(https://images\.finncdn\.no/dynamic/[^"\s\\]+\.jpg)', html):
        images.append(m.group(1))
    # dedupe preserving order, prefer larger images
    seen_imgs = set()
    images_clean = []
    for u in images:
        if u not in seen_imgs:
            seen_imgs.add(u); images_clean.append(u)
    out['image_urls'] = images_clean
    out['primary_image_url'] = images_clean[0] if images_clean else None
    
    # Seller (org info)
    out['seller_type'] = 'private'
    out['org_name'] = None
    # Find companyProfile JSON block
    cp_idx = html.find('"companyProfile":{')
    if cp_idx > 0:
        depth = 0
        start = cp_idx + len('"companyProfile":')
        end = start
        for i in range(start, min(start + 5000, len(html))):
            c = html[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1; break
        try:
            cp = json.loads(html[start:end])
            if cp.get('orgName'):
                out['seller_type'] = 'professional'
                out['org_name'] = cp.get('orgName')
                out['org_id'] = cp.get('orgId')
                out['org_homepage'] = cp.get('homepageUrl')
                if cp.get('contacts'):
                    out['contact_name'] = cp['contacts'][0].get('name')
                    out['contact_email'] = cp['contacts'][0].get('email')
                    out['contact_title'] = cp['contacts'][0].get('title')
        except:
            pass
    
    # Currency
    out['currency'] = 'NOK'
    out['min_rental_days'] = None  # finn doesn't expose this; assume monthly
    
    text = (out.get('title','') or '') + ' ' + (out.get('description','') or '')
    out['opening_hours'] = extract_opening_hours(text)
    out['features'] = extract_features(text)
    
    return out


# ---------- Run ----------

results = []

# Hygglo
hygglo_dir = '/sessions/happy-eloquent-pasteur/mnt/outputs/hygglo/ads'
for path in sorted(glob.glob(f'{hygglo_dir}/*.html')):
    slug = os.path.basename(path).replace('.html','')
    with open(path) as f:
        html = f.read()
    data = parse_hygglo_ad(html, slug)
    if data:
        results.append(data)

# Finn
finn_dir = '/sessions/happy-eloquent-pasteur/mnt/outputs/finn/ads'
for path in sorted(glob.glob(f'{finn_dir}/*.html')):
    finnkode = os.path.basename(path).replace('.html','')
    with open(path) as f:
        html = f.read()
    data = parse_finn_ad(html, finnkode)
    if data:
        results.append(data)

# FILTER: Tuno does not support HOUR pricing
removed_hour = 0
for r in results:
    if r.get('price_packages'):
        before = len(r['price_packages'])
        r['price_packages'] = [p for p in r['price_packages'] if p.get('period_type') != 'HOUR']
        removed_hour += before - len(r['price_packages'])
print(f'Removed {removed_hour} HOUR pricing entries')

# Stats
print(f'Total parsed: {len(results)}')
print(f'  Hygglo: {sum(1 for r in results if r["source"]=="hygglo")}')
print(f'  Finn: {sum(1 for r in results if r["source"]=="finn")}')
print()
total_pkgs = sum(len(r['price_packages']) for r in results)
print(f'Total price packages: {total_pkgs} (avg {total_pkgs/len(results):.1f}/ad)')
total_oh = sum(len(r['opening_hours']) for r in results)
print(f'Total opening_hours entries: {total_oh}')
ads_with_oh = sum(1 for r in results if r['opening_hours'])
print(f'Ads with opening hours: {ads_with_oh}')
ads_with_image = sum(1 for r in results if r['primary_image_url'])
print(f'Ads with at least 1 image: {ads_with_image} of {len(results)} ({100*ads_with_image/len(results):.0f}%)')

# Save
out_path = '/sessions/happy-eloquent-pasteur/mnt/outputs/tuno_staging.json'
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print(f'\nSaved {out_path}')
print(f'Size: {os.path.getsize(out_path):,} bytes')
