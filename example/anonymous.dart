import 'package:xmpp/xmpp.dart';

void main() {
  var host ='127.0.0.1';
  var port = 5222;
  var xmppManager = new XmppManager(new XmppConnection(host, port));
  xmppManager.execute(XmppOperation.BEGIN)
  .then((xmppManager) => xmppManager.execute(XmppOperation.SASL_ANONYMOUS))
  .then((xmppManager) => xmppManager.execute(XmppOperation.BEGIN))
  .then((xmppManager) => xmppManager.execute(XmppOperation.BIND))
  .then((xmppManager) => xmppManager.execute(XmppOperation.END))
  .then((_) { print('main(): finished ...'); });
}
