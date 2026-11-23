"""Large files for integration_test/perf_test.dart, written to build/perf_fixtures (never committed).

Standard library only. Text is generated from a fixed word list, so the files are the same on every run.

    python3 tool/make_perf_fixtures.py
    adb push build/perf_fixtures/. /data/local/tmp/unfurl/
"""
import os
import random
import struct
import sys
import zipfile
import zlib

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'build', 'perf_fixtures')
os.makedirs(os.path.join(OUT, 'covers'), exist_ok=True)
rnd = random.Random(7)
WORDS = ('the a of and to in that was his her with for had not you all but they which from this have one she were '
         'been their would when there what time garden letter window morning silence journey captain harbour winter '
         'remember question answer mountain river evening village stranger promise country brother daughter history '
         'extraordinary circumstances imagination particular conversation nevertheless understanding').split()


def sentence():
    n = rnd.randint(8, 22)
    s = ' '.join(rnd.choice(WORDS) for _ in range(n))
    return s[0].upper() + s[1:] + '.'


def para(lo=3, hi=7):
    return ' '.join(sentence() for _ in range(rnd.randint(lo, hi)))


def pdf(path, pages):
    objs = []

    def add(s):
        objs.append(s if isinstance(s, bytes) else s.encode('latin-1'))
        return len(objs)

    font = add('<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>')
    pages_id = len(objs) + 1
    add('')  # /Pages, filled in below
    kids = []
    for p in range(pages):
        lines = []
        if p % 20 == 0:
            lines.append(f'BT /F1 20 Tf 72 720 Td (Chapter {p // 20 + 1}) Tj ET')
        y = 690 if p % 20 == 0 else 720
        while y > 72:
            text = ''
            while len(text) < 78:
                text += rnd.choice(WORDS) + ' '
            lines.append(f'BT /F1 12 Tf 72 {y} Td ({text.strip()}) Tj ET')
            y -= 15
        lines.append(f'BT /F1 9 Tf 300 40 Td ({p + 1}) Tj ET')
        data = zlib.compress('\n'.join(lines).encode('latin-1'))
        c = add(f'<< /Length {len(data)} /Filter /FlateDecode >>\nstream\n'.encode() + data + b'\nendstream')
        kids.append(add(f'<< /Type /Page /Parent {pages_id} 0 R /MediaBox [0 0 612 792] '
                        f'/Resources << /Font << /F1 {font} 0 R >> >> /Contents {c} 0 R >>'))
    objs[pages_id - 1] = (f'<< /Type /Pages /Count {len(kids)} /Kids [' + ' '.join(f'{k} 0 R' for k in kids) + '] >>').encode()
    out_id = len(objs) + 1
    items = list(range(0, pages, 20))
    add(f'<< /Type /Outlines /First {out_id + 1} 0 R /Last {out_id + len(items)} 0 R /Count {len(items)} >>')
    for i, p in enumerate(items):
        prev = f'/Prev {out_id + i} 0 R ' if i else ''
        nxt = f'/Next {out_id + i + 2} 0 R ' if i + 1 < len(items) else ''
        add(f'<< /Title (Chapter {i + 1}) /Parent {out_id} 0 R {prev}{nxt}/Dest [{kids[p]} 0 R /Fit] >>')
    root = add(f'<< /Type /Catalog /Pages {pages_id} 0 R /Outlines {out_id} 0 R >>')
    with open(path, 'wb') as f:
        f.write(b'%PDF-1.4\n')
        offs = []
        for i, o in enumerate(objs, 1):
            offs.append(f.tell())
            f.write(f'{i} 0 obj\n'.encode() + o + b'\nendobj\n')
        x = f.tell()
        f.write(f'xref\n0 {len(objs) + 1}\n0000000000 65535 f \n'.encode())
        for o in offs:
            f.write(f'{o:010d} 00000 n \n'.encode())
        f.write(f'trailer << /Size {len(objs) + 1} /Root {root} 0 R >>\nstartxref\n{x}\n%%EOF\n'.encode())


def epub(path, chapters, paras):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('mimetype', 'application/epub+zip', zipfile.ZIP_STORED)
        z.writestr('META-INF/container.xml', '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="c.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
        man = ''.join(f'<item id="c{i}" href="c{i}.xhtml" media-type="application/xhtml+xml"/>' for i in range(chapters))
        spine = ''.join(f'<itemref idref="c{i}"/>' for i in range(chapters))
        z.writestr('c.opf', f'<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="u"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="u">perf</dc:identifier><dc:title>The Long Journey</dc:title><dc:creator>Perf Author</dc:creator><dc:language>en</dc:language></metadata><manifest>{man}<item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/></manifest><spine>{spine}</spine></package>')
        nav = ''.join(f'<li><a href="c{i}.xhtml">Chapter {i + 1}</a></li>' for i in range(chapters))
        z.writestr('nav.xhtml', f'<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><body><nav epub:type="toc"><ol>{nav}</ol></nav></body></html>')
        for i in range(chapters):
            body = ''.join(f'<p>{para()}</p>' for _ in range(paras))
            z.writestr(f'c{i}.xhtml', f'<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter {i + 1}</title></head><body><h1>Chapter {i + 1}</h1>{body}</body></html>')


def docx(path, n):
    body = ''
    for i in range(n):
        if i % 40 == 0:
            body += f'<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Part {i // 40 + 1}</w:t></w:r></w:p>'
        body += f'<w:p><w:r><w:t xml:space="preserve">{para()}</w:t></w:r></w:p>'
    ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>')
        z.writestr('_rels/.rels', '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
        z.writestr('word/styles.xml', f'<w:styles {ns}><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style></w:styles>')
        z.writestr('word/document.xml', f'<w:document {ns}><w:body>{body}</w:body></w:document>')


def xlsx(path, rows, cols):
    def col(i):
        s = ''
        i += 1
        while i:
            i, r = divmod(i - 1, 26)
            s = chr(65 + r) + s
        return s
    data = ''
    for r in range(1, rows + 1):
        cells = ''.join(f'<c r="{col(c)}{r}" t="inlineStr"><is><t>{rnd.choice(WORDS)}</t></is></c>' if c % 3 == 0
                        else f'<c r="{col(c)}{r}"><v>{rnd.randint(1, 99999) / 100}</v></c>' for c in range(cols))
        data += f'<row r="{r}">{cells}</row>'
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>')
        z.writestr('_rels/.rels', '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        z.writestr('xl/workbook.xml', '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Data" sheetId="1" r:id="r1"/></sheets></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels', '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>')
        z.writestr('xl/worksheets/sheet1.xml', f'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>{data}</sheetData></worksheet>')


def png(path, w, h, seed):
    r = random.Random(seed)
    base = [r.randint(40, 220) for _ in range(3)]
    raw = b''
    for y in range(h):
        raw += b'\0' + b''.join(bytes(min(255, max(0, b + (x * 60 // w) - (y * 60 // h) + r.randint(-6, 6))) for b in base) for x in range(w))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


pdf(os.path.join(OUT, 'big.pdf'), 600)
epub(os.path.join(OUT, 'big.epub'), 60, 45)
docx(os.path.join(OUT, 'big.docx'), 1500)
xlsx(os.path.join(OUT, 'big.xlsx'), 6000, 20)
with open(os.path.join(OUT, 'big.md'), 'w') as f:
    for i in range(30):
        f.write(f'## Section {i + 1}\n\n' + '\n\n'.join(para() for _ in range(40)) + '\n\n')
with open(os.path.join(OUT, 'big.txt'), 'w') as f:
    f.write('\n\n'.join(para() for _ in range(1500)))
for i in range(40):
    png(os.path.join(OUT, 'covers', f'{i}.img'), 288, 408, i)
src = os.path.join(ROOT, 'test', 'fixtures')
for n in os.listdir(src):
    with open(os.path.join(src, n), 'rb') as a, open(os.path.join(OUT, n), 'wb') as b:
        b.write(a.read())
for n in sorted(os.listdir(OUT)):
    if n.startswith('big.'):
        print(n, os.path.getsize(os.path.join(OUT, n)) // 1024, 'KB')
