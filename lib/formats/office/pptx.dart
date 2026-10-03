import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../reading_document.dart';

class SlideRun {
  const SlideRun(this.text, {this.size, this.bold = false, this.italic = false, this.color});

  final String text;

  /// Points.
  final double? size;
  final bool bold;
  final bool italic;

  /// ARGB from the slide's own `srgbClr`; null takes the slide ink.
  final int? color;
}

class SlideParagraph {
  const SlideParagraph(this.runs, {this.level = 0, this.bullet = false, this.align = 'l'});

  final List<SlideRun> runs;
  final int level;
  final bool bullet;
  final String align;

  String get text => runs.map((SlideRun r) => r.text).join();
}

/// A positioned shape on a slide, in fractions of the slide size.
class SlideShape {
  const SlideShape({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.paragraphs = const <SlideParagraph>[],
    this.image,
    this.fill,
    this.kind = 'body',
  });

  final double x, y, w, h;
  final List<SlideParagraph> paragraphs;
  final String? image;

  /// ARGB solid fill.
  final int? fill;

  /// 'title', 'body', 'other' (from the placeholder type).
  final String kind;
}

class Slide {
  const Slide({required this.shapes, this.notes = '', this.background});

  final List<SlideShape> shapes;
  final String notes;
  final int? background;

  String get title => shapes
      .where((SlideShape s) => s.kind == 'title')
      .expand((SlideShape s) => s.paragraphs)
      .map((SlideParagraph p) => p.text)
      .join(' ')
      .trim();
}

/// A PowerPoint deck: slides as positioned shapes (rendered approximately),
/// with the notes, and an outline for Reader mode.
class Pptx {
  Pptx._(this.slides, this.images, this.aspect, this.title);

  final List<Slide> slides;
  final Map<String, Uint8List> images;

  /// Width over height.
  final double aspect;
  final String? title;

  static const double _defaultTitle = 40, _defaultBody = 22;

  static Pptx parse(Uint8List bytes) {
    final Archive zip = ZipDecoder().decodeBytes(bytes);
    String? text(String path) {
      final ArchiveFile? f = zip.findFile(path);
      return f == null ? null : utf8.decode(f.content, allowMalformed: true);
    }

    Map<String, String> rels(String part) {
      final String relsPath = p.posix.join(p.posix.dirname(part), '_rels', '${p.posix.basename(part)}.rels');
      final String? xml = text(relsPath);
      if (xml == null) return const <String, String>{};
      return <String, String>{
        for (final XmlElement r in XmlDocument.parse(
          xml,
        ).descendantElements.where((XmlElement e) => e.localName == 'Relationship'))
          r.getAttribute('Id')!: _target(part, r.getAttribute('Target')!),
      };
    }

    final XmlDocument pres = XmlDocument.parse(text('ppt/presentation.xml')!);
    final Map<String, String> presRels = rels('ppt/presentation.xml');
    final XmlElement? size = pres.descendantElements.where((XmlElement e) => e.localName == 'sldSz').firstOrNull;
    final double cx = double.tryParse(size?.getAttribute('cx') ?? '') ?? 12192000;
    final double cy = double.tryParse(size?.getAttribute('cy') ?? '') ?? 6858000;
    final Map<String, Uint8List> images = <String, Uint8List>{};
    final List<Slide> slides = <Slide>[];

    for (final XmlElement id in pres.descendantElements.where((XmlElement e) => e.localName == 'sldId')) {
      final String? rid = id.attributes
          .where((XmlAttribute a) => a.localName == 'id' && a.name.prefix == 'r')
          .map((XmlAttribute a) => a.value)
          .firstOrNull;
      final String? part = rid == null ? null : presRels[rid];
      final String? xml = part == null ? null : text(part);
      if (part == null || xml == null) continue;
      final Map<String, String> slideRels = rels(part);
      final String? layoutPart = slideRels.values.where((String t) => t.contains('slideLayout')).firstOrNull;
      final Map<String, XmlElement> layoutXfrm = _placeholderFrames(layoutPart == null ? null : text(layoutPart));
      final String? masterPart = layoutPart == null
          ? null
          : rels(layoutPart).values.where((String t) => t.contains('slideMaster')).firstOrNull;
      final Map<String, XmlElement> masterXfrm = _placeholderFrames(masterPart == null ? null : text(masterPart));

      final List<SlideShape> shapes = <SlideShape>[];
      final XmlDocument doc = XmlDocument.parse(xml);
      for (final XmlElement sp in doc.descendantElements.where(
        (XmlElement e) => e.localName == 'sp' || e.localName == 'pic',
      )) {
        final XmlElement? ph = sp.descendantElements.where((XmlElement e) => e.localName == 'ph').firstOrNull;
        final String phType = ph?.getAttribute('type') ?? (ph != null ? 'body' : 'other');
        final String kind = phType == 'title' || phType == 'ctrTitle'
            ? 'title'
            : (phType == 'subTitle'
                  ? 'body'
                  : phType == 'body'
                  ? 'body'
                  : 'other');
        final String phKey = '${ph?.getAttribute('type') ?? 'body'}:${ph?.getAttribute('idx') ?? ''}';
        XmlElement? xfrm = sp.descendantElements.where((XmlElement e) => e.localName == 'xfrm').firstOrNull;
        xfrm ??=
            layoutXfrm[phKey] ??
            layoutXfrm[phKey.split(':').first] ??
            masterXfrm[phKey.split(':').first] ??
            masterXfrm[kind == 'title' ? 'title' : 'body'];
        final XmlElement? off = xfrm?.childElements.where((XmlElement e) => e.localName == 'off').firstOrNull;
        final XmlElement? ext = xfrm?.childElements.where((XmlElement e) => e.localName == 'ext').firstOrNull;
        final double x = (double.tryParse(off?.getAttribute('x') ?? '') ?? cx * 0.08) / cx;
        final double y =
            (double.tryParse(off?.getAttribute('y') ?? '') ?? (kind == 'title' ? cy * 0.06 : cy * 0.25)) / cy;
        final double w = (double.tryParse(ext?.getAttribute('cx') ?? '') ?? cx * 0.84) / cx;
        final double h =
            (double.tryParse(ext?.getAttribute('cy') ?? '') ?? (kind == 'title' ? cy * 0.16 : cy * 0.6)) / cy;

        if (sp.localName == 'pic') {
          final XmlElement? blip = sp.descendantElements.where((XmlElement e) => e.localName == 'blip').firstOrNull;
          final String? embed = blip?.attributes
              .where((XmlAttribute a) => a.localName == 'embed')
              .map((XmlAttribute a) => a.value)
              .firstOrNull;
          final String? target = embed == null ? null : slideRels[embed];
          final ArchiveFile? f = target == null ? null : zip.findFile(target);
          if (f != null) {
            images[target!] = f.content;
            shapes.add(SlideShape(x: x, y: y, w: w, h: h, image: target, kind: 'other'));
          }
          continue;
        }
        final List<SlideParagraph> paras = <SlideParagraph>[];
        for (final XmlElement para in sp.descendantElements.where(
          (XmlElement e) => e.localName == 'p' && e.parentElement?.localName == 'txBody',
        )) {
          final XmlElement? ppr = para.childElements.where((XmlElement e) => e.localName == 'pPr').firstOrNull;
          final int level = int.tryParse(ppr?.getAttribute('lvl') ?? '') ?? 0;
          final bool noBullet = ppr?.childElements.any((XmlElement e) => e.localName == 'buNone') ?? false;
          final List<SlideRun> runs = <SlideRun>[
            for (final XmlElement r in para.childElements.where(
              (XmlElement e) => e.localName == 'r' || e.localName == 'br',
            ))
              if (r.localName == 'br')
                const SlideRun('\n')
              else
                _run(r, kind == 'title' ? _defaultTitle : _defaultBody - level * 2),
          ];
          if (runs.isEmpty) continue;
          paras.add(
            SlideParagraph(
              runs,
              level: level,
              bullet: kind == 'body' && phType == 'body' && !noBullet,
              align: ppr?.getAttribute('algn') ?? (phType == 'ctrTitle' || phType == 'subTitle' ? 'ctr' : 'l'),
            ),
          );
        }
        final XmlElement? fill = sp.childElements
            .where((XmlElement e) => e.localName == 'spPr')
            .firstOrNull
            ?.childElements
            .where((XmlElement e) => e.localName == 'solidFill')
            .firstOrNull;
        shapes.add(SlideShape(x: x, y: y, w: w, h: h, paragraphs: paras, kind: kind, fill: _color(fill)));
      }

      String notes = '';
      final String? notesPart = slideRels.values.where((String t) => t.contains('notesSlide')).firstOrNull;
      final String? notesXml = notesPart == null ? null : text(notesPart);
      if (notesXml != null) {
        final XmlDocument nd = XmlDocument.parse(notesXml);
        notes = nd.descendantElements
            .where(
              (XmlElement e) =>
                  e.localName == 'sp' &&
                  e.descendantElements.any((XmlElement p) => p.localName == 'ph' && p.getAttribute('type') == 'body'),
            )
            .expand((XmlElement sp) => sp.descendantElements.where((XmlElement e) => e.localName == 't'))
            .map((XmlElement t) => t.innerText)
            .join(' ')
            .trim();
      }
      slides.add(Slide(shapes: shapes, notes: notes));
    }
    final XmlDocument? core = text('docProps/core.xml') == null ? null : XmlDocument.parse(text('docProps/core.xml')!);
    final String? title = core?.descendantElements
        .where((XmlElement e) => e.localName == 'title')
        .map((XmlElement e) => e.innerText.trim())
        .where((String s) => s.isNotEmpty)
        .firstOrNull;
    return Pptx._(slides, images, cx / cy, title);
  }

  static SlideRun _run(XmlElement r, double fallbackSize) {
    final XmlElement? rpr = r.childElements.where((XmlElement e) => e.localName == 'rPr').firstOrNull;
    final String t = r.childElements
        .where((XmlElement e) => e.localName == 't')
        .map((XmlElement e) => e.innerText)
        .join();
    final double? sz = double.tryParse(rpr?.getAttribute('sz') ?? '');
    return SlideRun(
      t,
      size: sz == null ? fallbackSize : sz / 100,
      bold: rpr?.getAttribute('b') == '1',
      italic: rpr?.getAttribute('i') == '1',
      color: _color(rpr?.childElements.where((XmlElement e) => e.localName == 'solidFill').firstOrNull),
    );
  }

  static int? _color(XmlElement? fill) {
    final String? hex = fill?.childElements
        .where((XmlElement e) => e.localName == 'srgbClr')
        .firstOrNull
        ?.getAttribute('val');
    return hex == null ? null : 0xFF000000 | (int.tryParse(hex, radix: 16) ?? 0);
  }

  /// Placeholder frames on a layout or master, keyed "type:idx" and "type".
  static Map<String, XmlElement> _placeholderFrames(String? xml) {
    if (xml == null) return const <String, XmlElement>{};
    final Map<String, XmlElement> out = <String, XmlElement>{};
    for (final XmlElement sp in XmlDocument.parse(
      xml,
    ).descendantElements.where((XmlElement e) => e.localName == 'sp')) {
      final XmlElement? ph = sp.descendantElements.where((XmlElement e) => e.localName == 'ph').firstOrNull;
      final XmlElement? xfrm = sp.descendantElements.where((XmlElement e) => e.localName == 'xfrm').firstOrNull;
      if (ph == null || xfrm == null) continue;
      final String type = ph.getAttribute('type') ?? 'body';
      out['$type:${ph.getAttribute('idx') ?? ''}'] = xfrm;
      out.putIfAbsent(type, () => xfrm);
      if (type == 'ctrTitle') out.putIfAbsent('title', () => xfrm);
      if (type == 'subTitle') out.putIfAbsent('body', () => xfrm);
    }
    return out;
  }

  /// Reader mode: an outline. Each slide is a section: "SLIDE n", its title
  /// as a heading, then bullets and images. Sources are slide numbers.
  ReadingDocument toReading(String name) {
    final List<Section> sections = <Section>[];
    for (int i = 0; i < slides.length; i++) {
      final Slide s = slides[i];
      final SourceRef src = SourceRef(page: i + 1);
      final String heading = s.title.isEmpty ? 'Slide ${i + 1}' : s.title;
      final List<Block> blocks = <Block>[
        Block(kind: BlockKind.heading, level: 6, runs: <Inline>[Inline('SLIDE ${i + 1}')], source: src),
        Block(kind: BlockKind.heading, level: 2, runs: <Inline>[Inline(heading)], source: src),
        for (final SlideShape sh in s.shapes)
          if (sh.kind != 'title')
            if (sh.image != null)
              Block(kind: BlockKind.image, image: sh.image, source: src)
            else
              for (final SlideParagraph para in sh.paragraphs)
                if (para.text.trim().isNotEmpty)
                  Block(
                    kind: BlockKind.listItem,
                    level: para.level + 1,
                    runs: <Inline>[Inline(para.text.trim())],
                    source: src,
                  ),
        if (s.notes.isNotEmpty) Block(kind: BlockKind.caption, runs: <Inline>[Inline(s.notes)], source: src),
      ];
      sections.add(Section(title: heading, blocks: blocks));
    }
    if (sections.isEmpty) {
      sections.add(
        Section(
          title: '',
          blocks: <Block>[
            Block(kind: BlockKind.paragraph, runs: const <Inline>[Inline('')]),
          ],
        ),
      );
    }
    return ReadingDocument(title: title ?? name, sections: sections, resources: images, unitLabel: 'Slide');
  }
}

/// A relationship target: package-absolute ("/xl/...") or relative to the part.
String _target(String part, String target) =>
    target.startsWith('/') ? target.substring(1) : p.posix.normalize(p.posix.join(p.posix.dirname(part), target));
