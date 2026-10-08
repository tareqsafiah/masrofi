# يضبط ملفات الويب لتعمل كتطبيق على شاشة الآيفون الرئيسية (PWA)
import json, re

m = json.load(open('web/manifest.json', encoding='utf-8'))
m.update({
    'name': 'مصروفي',
    'short_name': 'مصروفي',
    'description': 'تتبّع المصاريف والادخار',
    'lang': 'ar',
    'dir': 'rtl',
    'display': 'standalone',
    'orientation': 'portrait',
    'background_color': '#0D1015',
    'theme_color': '#0D1015',
})
json.dump(m, open('web/manifest.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

h = open('web/index.html', encoding='utf-8').read()
h = re.sub(r'<html[^>]*>', '<html lang="ar" dir="rtl">', h, count=1)
h = re.sub(r'<title>.*?</title>', '<title>مصروفي</title>', h, flags=re.S)
h = re.sub(r'<meta name="apple-mobile-web-app-title"[^>]*>', '', h)
h = re.sub(r'<meta name="apple-mobile-web-app-status-bar-style"[^>]*>', '', h)
h = re.sub(r'<meta name="theme-color"[^>]*>', '', h)
extra = '''
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="مصروفي">
  <meta name="theme-color" content="#0D1015">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <style>html,body{background:#0D1015;margin:0}</style>
'''
h = h.replace('</head>', extra + '</head>', 1)
open('web/index.html', 'w', encoding='utf-8').write(h)
print('web patched')
