"""Build the trailer page: copies the finished renders into site/img and writes site/index.html.
Styles are shared with the bathhouse page (../../gazebo-spa/site/style.css).

usage: python3 build.py ../renders
"""
import html, json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REN = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'renders'))
IMG = os.path.join(HERE, 'img')
PALETTE = {1: '#d64034', 2: '#2f6eaa', 3: '#3f703c', 0: '#787068'}
E = html.escape


def img(name, cap, cls='', w=1600, h=900):
    src = f'img/{name}.jpg'
    return (f'<figure class="{cls}"><button class="zoom" type="button" data-full="{src}" data-cap="{E(cap)}">'
            f'<img src="{src}" alt="{E(cap)}" loading="lazy" width="{w}" height="{h}"></button><figcaption>{E(cap)}</figcaption></figure>')


def legend(name):
    p = os.path.join(REN, name + '.legend.json')
    if not os.path.exists(p):
        return ''
    items = json.load(open(p))
    lis = ''.join(f'<li><span class="n" style="background:{PALETTE.get(i["phase"], PALETTE[0])}">{i["n"]}</span><span>{E(i["label"])}</span></li>' for i in items)
    return f'<ol class="legend" aria-label="Plan key">{lis}</ol>'


def page(body):
    css = open(os.path.join(HERE, '..', '..', 'gazebo-spa', 'site', 'style.css')).read()
    extra = '''
.tiers .scheme-letter { font-size: 2.6rem; }
.money { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }
.money div { background: var(--wash); padding: 12px 14px; display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.money b { font-family: var(--figure); font-weight: 600; font-size: 1.15rem; }
.money span { font-size: 0.8rem; color: var(--muted); }
.bars { display: flex; flex-direction: column; gap: 14px; }
.bar-row { display: grid; grid-template-columns: 150px minmax(0, 1fr); gap: 12px; align-items: center; }
.bar-track { position: relative; height: 22px; }
.bar { height: 22px; background: var(--bar); border-radius: 0 4px 4px 0; }
.bar-val { position: absolute; top: 0; height: 22px; display: flex; align-items: center; padding-left: 8px; font-size: 0.85rem; font-variant-numeric: tabular-nums; white-space: nowrap; color: var(--ink); }
.bar-axis { border-left: 1px solid var(--line); }
.tip { position: fixed; z-index: 15; background: var(--ink); color: var(--paper); font-size: 0.8rem; padding: 6px 9px; pointer-events: none; max-width: 260px; }
@media (max-width: 520px) { .bar-row { grid-template-columns: 1fr; gap: 4px; } }
'''
    return f'''<title>Build-Years Trailer</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fondamento&family=Inknut+Antiqua:wght@600&family=Inter+Tight:wght@400;600;700&display=swap">
<style>{css}{extra}</style>
{body}
<div class="lightbox" id="lightbox" hidden role="dialog" aria-modal="true" aria-label="Enlarged render">
  <button type="button" id="lb-close">Close</button>
  <div><img id="lb-img" alt=""><p id="lb-cap"></p></div>
</div>
<div class="tip" id="tip" hidden></div>
<script>
(function () {{
  var lb = document.getElementById('lightbox'), im = document.getElementById('lb-img'), cap = document.getElementById('lb-cap');
  var last = null;
  function open(b) {{ last = b; im.src = b.dataset.full; im.alt = b.dataset.cap; cap.textContent = b.dataset.cap; lb.hidden = false; document.getElementById('lb-close').focus(); }}
  function close() {{ lb.hidden = true; im.removeAttribute('src'); if (last) last.focus(); }}
  document.addEventListener('click', function (e) {{
    var b = e.target.closest('.zoom'); if (b) {{ open(b); return; }}
    if (!lb.hidden && (e.target === lb || e.target.id === 'lb-close')) close();
  }});
  document.addEventListener('keydown', function (e) {{ if (e.key === 'Escape' && !lb.hidden) close(); }});
  // bar tooltips
  var tip = document.getElementById('tip');
  document.querySelectorAll('.bar-track').forEach(function (t) {{
    t.addEventListener('mousemove', function (e) {{ tip.textContent = t.dataset.tip; tip.hidden = false; tip.style.left = (e.clientX + 14) + 'px'; tip.style.top = (e.clientY + 14) + 'px'; }});
    t.addEventListener('mouseleave', function () {{ tip.hidden = true; }});
  }});
  document.querySelectorAll('.actions input').forEach(function (cb) {{
    try {{ cb.checked = localStorage.getItem('rv-' + cb.id) === '1'; }} catch (err) {{}}
    cb.addEventListener('change', function () {{ try {{ localStorage.setItem('rv-' + cb.id, cb.checked ? '1' : '0'); }} catch (err) {{}} }});
  }});
}})();
</script>'''


def main():
    os.makedirs(IMG, exist_ok=True)
    for f in os.listdir(REN):
        if f.endswith('.jpg'):
            shutil.copy(os.path.join(REN, f), os.path.join(IMG, f))
    import content as C
    body = C.intro() + C.toc() + C.rule() + C.pod() + C.looks(img, legend) + C.which() + C.where() + C.how() + C.budget() + C.desert() + C.actions() + C.sources()
    out = page(body)
    open(os.path.join(HERE, 'index.html'), 'w').write(out)
    print('wrote index.html', len(out) // 1024, 'KB')


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    main()
