import 'package:equatable/equatable.dart';

/// Represents either a successful [T] value or a [Failure].
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);
}

// ---------------------------------------------------------------------------
// Failure hierarchy
// ---------------------------------------------------------------------------

abstract class AppFailure extends Equatable {
  final String message;
  const AppFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'تعذّر الاتصال. تحقق من الإنترنت.']);
}

class ServerFailure extends AppFailure {
  final int? statusCode;
  final String? code;
  const ServerFailure({
    String message = 'حدث خطأ في الخادم.',
    this.statusCode,
    this.code,
  }) : super(message);

  @override
  List<Object?> get props => [message, statusCode, code];
}

class AuthFailure extends AppFailure {
  const AuthFailure([super.message = 'خطأ في المصادقة.']);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('البريد أو كلمة المرور غير صحيحة.');
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure() : super('الحساب غير موجود.');
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
    : super('هذا البريد مسجّل مسبقاً. جرّب تسجيل الدخول.');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure()
    : super('كلمة المرور ضعيفة. استخدم 8 أحرف أو أكثر.');
}

class ValidationFailure extends AppFailure {
  const ValidationFailure([super.message = 'بيانات غير صالحة.']);
}

class LocalDatabaseFailure extends AppFailure {
  const LocalDatabaseFailure([
    super.message = 'خطأ في قاعدة البيانات المحلية.',
  ]);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'حدث خطأ غير متوقع.']);
}

class CancelledFailure extends AppFailure {
  const CancelledFailure([super.message = 'تم الإلغاء.']);
}
