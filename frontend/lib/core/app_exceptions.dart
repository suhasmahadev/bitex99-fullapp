/// Typed API error hierarchy — replaces Firebase exception handling.
class ApiException implements Exception {
  final String message;
  final String? errorCode;
  final int? statusCode;

  ApiException({
    required this.message,
    this.errorCode,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Thrown when the user requests a new OTP before the cooldown expires.
class OtpCooldownException extends ApiException {
  final int secondsRemaining;
  OtpCooldownException(this.secondsRemaining)
      : super(
          message: 'Wait ${secondsRemaining}s before resending',
          errorCode: 'OTP_COOLDOWN',
        );
}

/// Thrown when the user enters a wrong OTP.
class InvalidOtpException extends ApiException {
  final int attemptsRemaining;
  InvalidOtpException(this.attemptsRemaining)
      : super(
          message: 'Invalid OTP. $attemptsRemaining attempts left',
          errorCode: 'INVALID_OTP',
        );
}

/// Thrown when there is no network connectivity.
class NetworkException extends ApiException {
  NetworkException()
      : super(message: 'No internet connection. Please try again.');
}
