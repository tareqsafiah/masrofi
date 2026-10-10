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
  <style>
    html,body{background:#0D1015;margin:0;height:100%}
    @font-face{font-family:KufiL;src:url(assets/assets/fonts/NotoKufiArabic-Bold.ttf);font-weight:700;font-display:swap}
    #ldr{position:fixed;inset:0;z-index:9999;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:22px;
      background:radial-gradient(120% 80% at 50% 0%,#12221d 0%,#0D1015 60%);color:#F2F4F7;font-family:KufiL,system-ui,sans-serif;
      transition:opacity .45s ease,visibility .45s;padding-bottom:env(safe-area-inset-bottom)}
    #ldr.out{opacity:0;visibility:hidden}
    #ldr .logo{position:relative;width:96px;height:96px}
    #ldr .logo img{width:96px;height:96px;border-radius:26px;display:block;animation:ldr-pop .9s cubic-bezier(.2,.9,.3,1.3) both}
    #ldr .logo::after{content:"";position:absolute;inset:-12px;border-radius:36px;border:2px solid #2ED6A0;opacity:0;animation:ldr-ring 1.8s ease-out .5s infinite}
    #ldr h1{margin:0;font-size:30px;font-weight:700;letter-spacing:0;animation:ldr-up .7s .15s ease both}
    #ldr .bar{width:150px;height:4px;border-radius:4px;background:#1E232C;overflow:hidden;animation:ldr-up .7s .3s ease both}
    #ldr .bar i{display:block;height:100%;width:40%;border-radius:4px;background:linear-gradient(90deg,#14A37A,#2ED6A0);animation:ldr-slide 1.2s ease-in-out infinite}
    #ldr p{margin:0;font-size:13px;color:#8A93A3;animation:ldr-up .7s .45s ease both}
    #ldr button{display:none;margin-top:4px;background:#2ED6A0;color:#04140E;border:0;border-radius:14px;padding:12px 22px;font:inherit;font-size:14px}
    #ldr.slow button{display:block}
    @keyframes ldr-pop{from{transform:scale(.6);opacity:0}to{transform:scale(1);opacity:1}}
    @keyframes ldr-ring{0%{transform:scale(.85);opacity:.7}100%{transform:scale(1.35);opacity:0}}
    @keyframes ldr-up{from{transform:translateY(10px);opacity:0}to{transform:none;opacity:1}}
    @keyframes ldr-slide{0%{transform:translateX(260%)}100%{transform:translateX(-110%)}}
  </style>
'''
h = h.replace('</head>', extra + '</head>', 1)
loader = '''
  <div id="ldr">
    <div class="logo"><img src="icons/Icon-192.png" alt=""></div>
    <h1>مصروفي</h1>
    <div class="bar"><i></i></div>
    <p id="ldr-msg">جارٍ التحميل…</p>
    <button onclick="location.reload()">إعادة المحاولة</button>
  </div>
  <script>
    (function(){
      var l=document.getElementById('ldr'),m=document.getElementById('ldr-msg');
      var t1=setTimeout(function(){m.textContent='لحظات… نجهّز التطبيق';},4000);
      var t2=setTimeout(function(){l.classList.add('slow');m.textContent='التحميل أبطأ من المعتاد، تحقق من الإنترنت';},20000);
      window.addEventListener('flutter-first-frame',function(){
        clearTimeout(t1);clearTimeout(t2);
        setTimeout(function(){l.classList.add('out');setTimeout(function(){l.remove();},600);},150);
      });
    })();
  </script>
'''
h = re.sub(r'<body[^>]*>', lambda mm: mm.group(0) + loader, h, count=1)
open('web/index.html', 'w', encoding='utf-8').write(h)
print('web patched')
