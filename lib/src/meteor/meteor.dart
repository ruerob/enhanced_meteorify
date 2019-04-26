import 'dart:async';

import 'package:ddp/ddp.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../listeners/listeners.dart';

enum ConnectionStatus { CONNECTED, DISCONNECTED }

class Meteor {
  static DdpClient _client;
  static DdpClient get client => _client;
  static MeteorConnectionListener _connectionListener;
  static String _connectionUrl;
  static bool isConnected = false;
  static String _currentUserId;
  static String get currentUserId => _currentUserId;
  static Db db = null;

  static Future<ConnectionStatus> connect(String url) async {
    Completer<ConnectionStatus> completer = Completer<ConnectionStatus>();

    _connectionUrl = url;
    _client = DdpClient("meteor", _connectionUrl, "meteor");
    _client.connect();

    _client.addStatusListener((status) {
      if (status == ConnectStatus.connected) {
        isConnected = true;
        _notifyConnected();
        completer.complete(ConnectionStatus.CONNECTED);
      } else if (status == ConnectStatus.disconnected) {
        isConnected = false;
        _notifyDisconnected();
        completer.complete(ConnectionStatus.DISCONNECTED);
      }
    });
    return completer.future;
  }

  static disconnect() {
    _client.close();
    _notifyDisconnected();
  }

  static reconnect() {
    _client.reconnect();
  }

  static addConnectionListener(
      MeteorConnectionListener _meteorConnectionListener) {
    _connectionListener = _meteorConnectionListener;
  }

  static removeConnectionListener() {
    _connectionListener = null;
  }

  static void _notifyConnected() {
    if (_connectionListener != null) _connectionListener.onConnected();
  }

  static void _notifyDisconnected() {
    if (_connectionListener != null) _connectionListener.onDisconnected();
  }

/**
 * Methods associated with authentication
 */
  static bool isLoggedIn() {
    return _currentUserId != null;
  }

  static void loginWithPassword(
      String email, String password, ResultListener resultListener) async {
    if (isConnected) {
      var result = await _client.call("login", [
        {
          "password": password,
          "user": {"email": email}
        }
      ]);
      print(result.reply);
      notifyLoginResult(result, resultListener);
    }
  }

  static void loginWithToken(
      String token, ResultListener resultListener) async {
    if (isConnected) {
      var result = await _client.call("login", [
        {"resume": token}
      ]);
      print(result.reply);
      notifyLoginResult(result, resultListener);
    }
  }

  static void notifyLoginResult(Call result, ResultListener resultListener) {
    String userId = result.reply["id"];
    String token = result.reply["token"];
    if (userId != null) {
      _currentUserId = userId;
      if (resultListener != null) {
        resultListener.onSuccess(token);
      }
    } else {
      _notifyError(resultListener, result);
    }
  }

  static void logout() async {
    if (isConnected) {
      var result = await _client.call("logout", []);
      print(result.reply);
    }
  }

  static void _notifyError(ResultListener resultListener, Call result) {
    resultListener.onError(result.reply['reason']);
  }

  /**
   * Methods associated with connection to MongoDB
   */
  static Future<Db> getMeteorDatabase() async {
    Completer<Db> completer = Completer<Db>();
    if (db == null) {
      final uri = Uri.parse(_connectionUrl);
      String dbUrl = "mongodb://" + uri.host + ":3001/meteor";
      print("Connecting to $dbUrl");
      db = Db(dbUrl);
      await db.open();
    }
    completer.complete(db);
    return completer.future;
  }

  static Db getCustomDatabase(String dbUrl) {
    return Db(dbUrl);
  }

/**
 * Methods associated with current user
 */
  static Future<Map<String, dynamic>> userAsMap() async {
    Completer completer = Completer<Map<String, dynamic>>();
    Db db = await getMeteorDatabase();
    var user = await db.collection("users").findOne({"_id": _currentUserId});
    completer.complete(user);
    return completer.future;
  }
}
