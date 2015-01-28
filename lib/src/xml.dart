
class XmlDocument {
  XmlElement _rootElement;
  void set rootElement(XmlElement xmlElement) {
    _rootElement = xmlElement;
  }
  XmlElement get rootElement => _rootElement;
  String toXmlString({pretty: false}) {
    return _rootElement.toXmlString(pretty: pretty);
  }
}

class XmlElement {
  String _name;
  String text;
  XmlElement parent;
  List<XmlAttribute> attributes = [];
  List<XmlElement> children = [];
  bool _shouldBeClosed = false, _markedClosed = false;
  XmlElement(this._name, {shouldBeClosed: false}) {
    _shouldBeClosed = shouldBeClosed;
  }
  String get name => _name;
  void markClosed() {
    _markedClosed = true;
  }
  bool get isIncomplete => _shouldBeClosed && !_markedClosed;
  String toXmlString({withChildren: true, pretty: false}) {
    StringBuffer sb = new StringBuffer('<${this._name}${attributes.map((a) => a.toString()).fold('', (s, r) => s+' '+r)}>');
    if (withChildren) {
      sb.write('${children.map((e) => e.toXmlString(pretty: pretty)).fold('', (s,r) => s+r)}');
    }
    if (text != null) {
      sb.write(text);
    }
    if (! isIncomplete) {
      sb.write('</${this._name}>');
    }
    return sb.toString();
  }
}

class XmlAttribute {
  String name, value;
  XmlAttribute(this.name, this.value);
  String toString() => '$name="$value"';
}
