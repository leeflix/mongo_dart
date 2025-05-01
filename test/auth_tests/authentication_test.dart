import 'package:mongo_dart/mongo_dart.dart';
import 'package:sasl_scram/sasl_scram.dart' show CryptoStrengthStringGenerator;
import 'package:test/test.dart';

import 'package:mongo_dart/src/auth/scram_sha1_authenticator.dart'
    show ScramSha1Authenticator;
import 'package:mongo_dart/src/auth/scram_sha256_authenticator.dart'
    show ScramSha256Authenticator;
import 'package:mongo_dart/src/auth/mongodb_cr_authenticator.dart'
    show MongoDbCRAuthenticator;

import '../utils/test_database.dart';
//final String mongoDbUri =
//    'mongodb://test:test@ds031477.mlab.com:31477/dart';

//  switch (serverType) {
//    case ServerType.simple:
//      defaultPort = '27017';
//      defaultPort2 = defaultPort;
//    case ServerType.simpleAuth:
//      defaultPort = '27031';
//      defaultPort2 = defaultPort;
//    case ServerType.tlsServer:
//      defaultPort = '27032';
//      defaultPort2 = '27033';
//    case ServerType.tlsServerAuth:
//      defaultPort = '27034';
//      defaultPort2 = '27035';
//    case ServerType.tlsClient:
//      defaultPort = '27036';
//      defaultPort2 = defaultPort;
//    case ServerType.tlsClientAuth:
//      defaultPort = '27037';
//      defaultPort2 = defaultPort;
//    case ServerType.x509Auth:
//      defaultPort = '27038';
//      defaultPort2 = defaultPort;
//  }

const dbName = 'mongodb-auth';
const dbAddress = '127.0.0.1';

const mongoDbUri = 'mongodb://test:test@$dbAddress:27031/$dbName';
const mongoDbUri2 = 'mongodb://unicode:übelkübel@$dbAddress:27031/$dbName';
const mongoDbUri3 = 'mongodb://special:1234AbcD##@$dbAddress:27031/$dbName';

void main() async {
  Future<String?> getFcv(String uri) async {
    var db = Db(uri);
    try {
      await db.open();
      var fcv = db.masterConnection.serverCapabilities.fcv;

      await db.close();
      return fcv;
    } on Map catch (e) {
      if (e.containsKey(keyCode)) {
        if (e[keyCode] == 18) {
          return null;
        }
      }
      throw StateError('Unknown error $e');
    } catch (e) {
      throw StateError('Unknown error $e');
    }
  }

  group('Authentication', () {
    var serverRequiresAuth = false;
    var isVer3_6 = false;
    var isVer3_2 = false;

    var isNoMoreMongodbCR = false;

    setUpAll(() async {
      serverRequiresAuth = await testDatabase(mongoDbUri);
      if (serverRequiresAuth) {
        var fcv = await getFcv(mongoDbUri);
        isVer3_2 = fcv == '3.2';
        isVer3_6 = fcv == '3.6';
        if (fcv != null) {
          isNoMoreMongodbCR = fcv.length != 3 || fcv.compareTo('5.9') == 1;
        }
      }
    });

    group('General Test', () {
      if (!serverRequiresAuth) {
        //return;
      }

      test('Should be able to connect and authenticate', () async {
        if (serverRequiresAuth) {
          var db = Db(mongoDbUri, 'test scram sha1');

          await db.open();
          await db.collection('test').find().toList();
          await db.close();
        }
      });
      test('Should be able to connect and authenticate with MONGODB-CR on 3.2 ',
          () async {
        if (serverRequiresAuth && isVer3_2) {
          var db = Db(
              'mongodb://t:t@$dbAddress:27017/$dbName?authMechanism=${MongoDbCRAuthenticator.name}');

          await db.open();
          expect(db.masterConnection.isAuthenticated, isTrue);
          await db.collection('test').find().toList();
          await db.close();

          db = Db('$mongoDbUri2?authMechanism=${MongoDbCRAuthenticator.name}');

          await db.open();
          expect(db.masterConnection.isAuthenticated, isTrue);
          await db.collection('test').find().toList();
          await db.close();
        }
      });

      test('Should be able to connect and authenticate with scram sha1',
          () async {
        if (serverRequiresAuth) {
          var db =
              Db('$mongoDbUri?authMechanism=${ScramSha1Authenticator.name}');

          await db.open();
          expect(db.masterConnection.isAuthenticated, isTrue);
          await db.collection('test').find().toList();
          await db.close();
        }
      });
      test('Should be able to connect and authenticate with scram sha256',
          () async {
        if (serverRequiresAuth && !isVer3_6 && !isVer3_2) {
          var db =
              Db('$mongoDbUri?authMechanism=${ScramSha256Authenticator.name}');

          await db.open();
          expect(db.masterConnection.isAuthenticated, isTrue);
          await db.collection('test').find().toList();
          await db.close();

          db =
              Db('$mongoDbUri2?authMechanism=${ScramSha256Authenticator.name}');

          await db.open();
          expect(db.masterConnection.isAuthenticated, isTrue);
          await db.collection('test').find().toList();
          await db.close();
        }
      });

      test(
          'Should be able to connect and authenticate special with scram sha256',
          () async {
        if (serverRequiresAuth && !isVer3_6 && !isVer3_2) {
          var db =
              Db('$mongoDbUri?authMechanism=${ScramSha256Authenticator.name}');

          await db.open();
          expect(db.masterConnection.isAuthenticated, isTrue);
          await db.collection('test').find().toList();
          await db.close();

          db =
              Db('$mongoDbUri3?authMechanism=${ScramSha256Authenticator.name}');

          await db.open();
          expect(db.masterConnection.isAuthenticated, isTrue);
          await db.collection('test').find().toList();
          await db.close();
        }
      });

      test("Can't connect with mongodb-cr on a db without that scheme",
          () async {
        if (serverRequiresAuth) {
          var db =
              Db('$mongoDbUri?authMechanism=${MongoDbCRAuthenticator.name}');

          var expectedError = {
            'ok': 0.0,
            'errmsg': 'auth failed',
            'code': 18,
            'codeName': 'AuthenticationFailed',
          };
          var expectedError2 = {
            'ok': 0.0,
            'errmsg': 'Auth mechanism not specified',
            'code': 2,
            'codeName': 'BadValue',
          };
          var expectedError3 = {
            'ok': 0.0,
            'errmsg': "BSON field 'authenticate.nonce' is an unknown field.",
            'code': 40415,
            'codeName': 'Location40415'
          };
          var expectedError4 = {
            'ok': 0.0,
            'errmsg': "Unsupported OP_QUERY command: getnonce. "
                "The client driver may require an upgrade. For more details "
                "see https://dochub.mongodb.org/core/legacy-opcode-removal",
            'code': 352,
            'codeName': 'UnsupportedOpQueryCommand'
          };

          dynamic err;

          try {
            await db.open();
          } on MongoDartError {
            // 6.0 does not connect with MongoDbCr
            return;
          } catch (e) {
            err = e;
          }

          var result = ((err['ok'] == expectedError['ok']) &&
                  (err['errmsg'] == expectedError['errmsg']) &&
                  (err['code'] == expectedError['code']) &&
                  (err['codeName'] == expectedError['codeName'])) ||
              ((err['ok'] == expectedError2['ok']) &&
                  (err['errmsg'] == expectedError2['errmsg']) &&
                  (err['code'] == expectedError2['code']) &&
                  (err['codeName'] == expectedError2['codeName'])) ||
              ((err['ok'] == expectedError3['ok']) &&
                  (err['errmsg'] == expectedError3['errmsg']) &&
                  (err['code'] == expectedError3['code']) &&
                  (err['codeName'] == expectedError3['codeName'])) ||
              ((err['ok'] == expectedError4['ok']) &&
                  (err['errmsg'] == expectedError4['errmsg']) &&
                  (err['code'] == expectedError4['code']) &&
                  (err['codeName'] == expectedError4['codeName']));

          expect(result, true);
        }
      }, skip: isNoMoreMongodbCR);

      test('Setting mongodb-cr with selectAuthenticationMechanisn', () async {
        if (serverRequiresAuth) {
          var db = Db(mongoDbUri);

          var expectedError = {
            'ok': 0.0,
            'errmsg': 'auth failed',
            'code': 18,
            'codeName': 'AuthenticationFailed',
          };
          var expectedError2 = {
            'ok': 0.0,
            'errmsg': 'Auth mechanism not specified',
            'code': 2,
            'codeName': 'BadValue',
          };
          var expectedError3 = {
            'ok': 0.0,
            'errmsg': "BSON field 'authenticate.nonce' is an unknown field.",
            'code': 40415,
            'codeName': 'Location40415'
          };
          var expectedError4 = {
            'ok': 0.0,
            'errmsg': "Unsupported OP_QUERY command: getnonce. "
                "The client driver may require an upgrade. For more details "
                "see https://dochub.mongodb.org/core/legacy-opcode-removal",
            'code': 352,
            'codeName': 'UnsupportedOpQueryCommand'
          };

          dynamic err;

          try {
            db.selectAuthenticationMechanism('MONGODB-CR');
            await db.open();
          } on MongoDartError catch (error) {
            // 6.0 does not connect with MongoDbCr
            print(error);
            return;
          } catch (e) {
            err = e;
          }

          var result = ((err['ok'] == expectedError['ok']) &&
                  (err['errmsg'] == expectedError['errmsg']) &&
                  (err['code'] == expectedError['code']) &&
                  (err['codeName'] == expectedError['codeName'])) ||
              ((err['ok'] == expectedError2['ok']) &&
                  (err['errmsg'] == expectedError2['errmsg']) &&
                  (err['code'] == expectedError2['code']) &&
                  (err['codeName'] == expectedError2['codeName'])) ||
              ((err['ok'] == expectedError3['ok']) &&
                  (err['errmsg'] == expectedError3['errmsg']) &&
                  (err['code'] == expectedError3['code']) &&
                  (err['codeName'] == expectedError3['codeName'])) ||
              ((err['ok'] == expectedError4['ok']) &&
                  (err['errmsg'] == expectedError4['errmsg']) &&
                  (err['code'] == expectedError4['code']) &&
                  (err['codeName'] == expectedError4['codeName']));

          expect(result, true);
        }
      }, skip: !serverRequiresAuth && isNoMoreMongodbCR);

      test("Throw exception when auth mechanism isn't supported", () async {
        if (serverRequiresAuth) {
          final authMechanism = 'Anything';
          var db = Db('$mongoDbUri?authMechanism=$authMechanism');

          dynamic sut() async => await db.open();

          expect(
              sut(),
              throwsA(predicate((MongoDartError e) =>
                  e.message ==
                  'Provided authentication scheme is not supported : $authMechanism')));
        }
      });
    });
    group('RandomStringGenerator', () {
      test("Shouldn't produce twice the same string", () {
        var generator = CryptoStrengthStringGenerator();

        var results = {};

        for (var i = 0; i < 100000; ++i) {
          var generatedString = generator.generate(20);
          if (results.containsKey(generatedString)) {
            fail("Shouldn't have generated 2 identical strings");
          } else {
            results[generatedString] = 1;
          }
        }
      });
    });
  });
}
