/// SDK 공통 예외.
sealed class HanChatException implements Exception {
  final String message;
  const HanChatException(this.message);

  @override
  String toString() => message;
}

/// 사용자 등록 필요.
class NotRegisteredException extends HanChatException {
  const NotRegisteredException() : super('user registration required');
}

/// 채팅방 없음.
class RoomNotFoundException extends HanChatException {
  const RoomNotFoundException(String roomId) : super('room not found: $roomId');
}

/// 네트워크/전송 오류.
class TransportException extends HanChatException {
  const TransportException(super.message);
}

/// 입력 검증 실패 (UI에 그대로 보여줄 수 있는 현지화 키를 담는다).
class ValidationException extends HanChatException {
  const ValidationException(super.message);
}

/// 권한 없음 (관리자 토큰 무효 등).
class UnauthorizedException extends HanChatException {
  const UnauthorizedException() : super('unauthorized');
}

/// 플래그로 숨겨진 기능 접근 (유료 이모티콘, AI 등).
class FeatureDisabledException extends HanChatException {
  const FeatureDisabledException() : super('feature not available yet');
}
