import 'package:bcrypt/bcrypt.dart';

String hashPassword(String password) {
  return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));
}

bool verifyPassword(String password, String hash) {
  return BCrypt.checkpw(password, hash);
}
