import 'package:firebase_auth/firebase_auth.dart';

class FakeFirebaseAuth implements FirebaseAuth {
  final String? uid;
  FakeFirebaseAuth(this.uid);

  @override
  User? get currentUser => uid == null ? null : FakeUser(uid!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUser implements User {
  final String _uid;
  FakeUser(this._uid);

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
