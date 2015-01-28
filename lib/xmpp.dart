library xmpp;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xmlstream/xmlstream.dart';

import 'package:xmpp/src/xml.dart';

class XmppManager {

  XmppConnection _xmppConnection;

  XmppManager(this._xmppConnection) {
    _xmppConnection.connect();
  }

  Future<XmppManager> execute(XmppOperation xmppOperation) {
    print('execute(): xmppOperation = $xmppOperation');
    Completer<XmppManager> completer = new Completer<XmppManager>();
    StreamSubscription<XmppServerMessage> xmppServerMessageStreaSubscription;
    xmppServerMessageStreaSubscription =_xmppConnection.xmppServerMessageBroadcastStream.listen((xmppServerMessage) {
      if (xmppOperation.isWaitingFor(xmppServerMessage)) {
        xmppServerMessageStreaSubscription.cancel();
        // TODO error handling
        completer.complete(this);        
      }
    });
    _xmppConnection.xmppClientMessageStreamController.add(xmppOperation.xmppClientMessage);
    return completer.future;
  }

}


class XmppOperation {

  static XmppOperation BEGIN = new XmppOperation(XmppClientMessage.OPEN_STREAM, new RegExp('<stream:stream xmlns:stream'));
  static XmppOperation END = new XmppOperation(XmppClientMessage.CLOSE_STREAM, new RegExp('</stream:stream'));
  static XmppOperation SASL_ANONYMOUS = new XmppOperation(XmppClientMessage.SASL_ANONYMOUS, new RegExp('<success xmlns="urn:ietf:params:xml:ns:xmpp-sasl"'));
  static XmppOperation BIND = new XmppOperation(XmppClientMessage.BIND, new RegExp('<iq type="result"'));

  XmppClientMessage _xmppClientMessage;
  Pattern _xmppServerMessagePattern;

  XmppOperation(this._xmppClientMessage, this._xmppServerMessagePattern);

  XmppClientMessage get xmppClientMessage => _xmppClientMessage;
  
  bool isWaitingFor(XmppServerMessage xmppServerMessage) {
    print('isWaitingFor(): xmppOperation = $this, xmppServerMessage = $xmppServerMessage');
    return xmppServerMessage._content.startsWith(_xmppServerMessagePattern);
  }

}


class XmppConnection {

  String _host;
  int _port;
  Future<Socket> _socketFuture;
  StreamController<XmppClientMessage> xmppClientMessageStreamController = new StreamController<XmppClientMessage>();
  StreamController<XmppServerMessage> xmppServerMessageStreamController = new StreamController<XmppServerMessage>(
      onListen: () => print('StreamController<XmppServerMessage>#onListen'),
      onPause:  () => print('StreamController<XmppServerMessage>#onPause'),
      onResume: () => print('StreamController<XmppServerMessage>#onResume'),
      onCancel: () => print('StreamController<XmppServerMessage>#onCancel'));
  Stream<XmppServerMessage> xmppServerMessageBroadcastStream;

  XmppConnection(this._host, this._port) {
    xmppServerMessageBroadcastStream = xmppServerMessageStreamController.stream.asBroadcastStream();
  }

  void connect() {
    _socketFuture = Socket.connect(_host, _port);
    _socketFuture.then((Socket socket) {
      print('connect(): socket: ${socket.address.address}:${socket.port} -> ${socket.remoteAddress.address}:${socket.remotePort}');
      socket.transform(UTF8.decoder).transform(XmlUtil.formater).listen(
          (String xmppServerMessages) { xmppServerMessageStreamController.add(new XmppServerMessage.from(xmppServerMessages)); },
          onDone: () { print('Socket Stream Done !!!'); }
      );
      xmppClientMessageStreamController.stream.listen((XmppClientMessage xmppClientMessage) { socket.add(UTF8.encoder.convert(xmppClientMessage.toString())); });
    });
  }

}


class XmlUtil {

  static StreamTransformer<String, String> formater = new StreamTransformer<String, String>.fromHandlers(
      handleData: (String value, EventSink<String> sink) {
        print('StreamTransformer.handleData(): $value');
        var resultList = new List<String>();
        XmlDocument xmlDocument;
        XmlElement xmlElement;
        var xmlStreamer = new XmlStreamer(value);
        xmlStreamer.read().listen((XmlEvent xmlEvent) {
          // print("XmlStreamer.read.listen(): $xmlEvent");
          switch (xmlEvent.state) {
            case XmlState.StartDocument:
              print('XmlStreamer.read.listen(): still not sure about XmlState.StartDocument');
              xmlDocument = new XmlDocument();
              break;
            case XmlState.Top:
              print('XmlStreamer.read.listen(): still not sure about XmlState.TOP');
              level = 0;
              break;
            case XmlState.Open:
              XmlElement newXmlElement = new XmlElement(xmlEvent.value, shouldBeClosed: true);
              if (xmlElement != null) {
                newXmlElement.parent = xmlElement;
                xmlElement.children.add(newXmlElement);
              } else {
                if (xmlDocument.rootElement != null) {
                  resultList.add(xmlDocument.toXmlString());
                }
                xmlDocument.rootElement = newXmlElement;
              }
              xmlElement = newXmlElement;
              level ++;
              break;
            case XmlState.Attribute:
              xmlElement.attributes.add(new XmlAttribute(xmlEvent.key, xmlEvent.value));
              break;
            case XmlState.Text:
              xmlElement.text = xmlEvent.value;
              break;
            case XmlState.Closed:
              if (xmlElement == null) {
                resultList.add('</${xmlEvent.value}>');
                break;
              }
              xmlElement.markClosed();
              xmlElement = xmlElement.parent;
              level --;
              break;
            case XmlState.EndDocument:
              if (xmlDocument.rootElement != null) {
                print('XmlStreamer.read.listen(): ${xmlDocument.toXmlString(pretty: true)}');
                if (xmlDocument.rootElement.isIncomplete) {
                  resultList.add(xmlDocument.rootElement.toXmlString(withChildren: false));
                  xmlDocument.rootElement.children.forEach((e) => resultList.add(e.toXmlString()));
                } else {
                  resultList.add(xmlDocument.rootElement.toXmlString());
                }
              }
              resultList.forEach((element) { sink.add(element); });
              break;
          }
        });
      });

  static var level = 0;

}


class XmppClientMessage {

  static XmppClientMessage OPEN_STREAM = new XmppClientMessage.from('<?xml version="1.0"?><stream:stream xmlns:stream="http://etherx.jabber.org/streams" xmlns="jabber:client" version="1.0" to="kodra.net">');
  static XmppClientMessage CLOSE_STREAM = new XmppClientMessage.from('</stream:stream>');
  static XmppClientMessage SASL_ANONYMOUS = new XmppClientMessage.from('<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="ANONYMOUS" />');
  static XmppClientMessage BIND = new XmppClientMessage.from('<iq type="set" id="bind_1"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"/></iq>');

  String _content;

  XmppClientMessage.from(this._content) {
  }

  String toString() {
    print('XmppClientMessage.toString(): ${this._content}');
    return this._content;
  }

}


class XmppServerMessage {

  String _content;

  XmppServerMessage(this._content);

  XmppServerMessage.from(String xmppServerMessage) {
    print('XmppServerMessage.from(): ${xmppServerMessage}');
    this._content = xmppServerMessage;
  }

  String toString() {
    print('XmppServerMessage.toString(): ${this._content}');
    return this._content;
  }

}


class XmppRequest {
}


class XmppResponse {
}

