# يجلب أسعار الدولار والذهب من sp-today.com ويطبعها كـ JSON (بالليرة القديمة)
import datetime, json, re, sys, urllib.request

req = urllib.request.Request('https://sp-today.com/', headers={
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/130.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ar,en;q=0.8',
})
html = urllib.request.urlopen(req, timeout=40).read().decode('utf-8', 'replace')
u = html.replace('\\"', '"')

m = re.search(r'"code":"USD".*?"damascus":\{"buy":([\d.]+),"sell":([\d.]+)', u, re.S)
if not m:
    sys.exit('USD rate not found')
usd = {'buy': float(m.group(1)), 'sell': float(m.group(2))}

gold = {}
g = u.find('"gold":{"karats"')
for k in re.finditer(r'"karat":"(\d+K)","cities":\{"damascus":\{"buy":([\d.]+),"sell":([\d.]+)', u[g:] if g >= 0 else u):
    gold[k.group(1)] = {'buy': float(k.group(2)), 'sell': float(k.group(3))}

if '21K' not in gold or '18K' not in gold:
    sys.exit('gold prices not found')
# فحص منطقي: الأسعار بالليرة القديمة
if not (1000 < usd['buy'] < 10_000_000) or gold['21K']['buy'] < usd['buy']:
    sys.exit(f'unexpected values {usd} {gold}')

upd = re.search(r'"code":"USD".*?"updated_at":"([^"]+)"', u, re.S)
print(json.dumps({
    'unit': 'old_syp',
    'source': 'sp-today.com',
    'sourceUpdatedAt': upd.group(1) if upd else None,
    'fetchedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'usd': usd,
    'gold': gold,
}, ensure_ascii=False, indent=1))
