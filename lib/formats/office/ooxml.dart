import 'package:xml/xml.dart';

/// Shared readers for Office Open XML properties, so every flag in Word's
/// markup is read the same way.

/// The first child named [name] (any namespace).
XmlElement? ooxmlChild(XmlElement? e, String name) =>
    e?.childElements.where((XmlElement c) => c.localName == name).firstOrNull;

/// The element's `val` attribute (any namespace).
String? ooxmlVal(XmlElement? e) =>
    e?.attributes.where((XmlAttribute a) => a.localName == 'val').map((XmlAttribute a) => a.value).firstOrNull;

/// An on/off property (ST_OnOff): `<w:b/>` and `w:val="1|true|on"` are on,
/// `w:val="0|false|off"` is off, an absent element is null (inherit).
/// The element's presence alone never means on when its value says off.
bool? ooxmlOn(XmlElement? e) {
  if (e == null) return null;
  return switch (ooxmlVal(e)?.toLowerCase()) {
    null || '1' || 'true' || 'on' => true,
    _ => false,
  };
}

/// Underline (ST_Underline): any style but `none` is on.
bool? ooxmlUnderline(XmlElement? e) {
  if (e == null) return null;
  final String? v = ooxmlVal(e);
  return v != 'none' && v != '0' && v != 'false';
}
