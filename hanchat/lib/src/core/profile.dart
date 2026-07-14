// 상대 프로필 보기
//
// 상대의 이름(아이콘)을 누르면 그 사람의 프로필(사진·배경)을 본다.
// 이미지가 상대 기기로 전달되어야 하므로 서버를 거친다. 단, 비용 최소화:
// - 프로필 사진 256px, 배경 1080px로 리사이즈해 수십 KB만 업로드
// - 받는 쪽은 한 번 받아 기기에 캐시 (프로필은 자주 안 바뀌어 트래픽 미미)
// 채팅 메시지의 "서버 미보관" 원칙과 별개 — 프로필은 원래 노출이 목적.

/// 공개 프로필 (닉네임 + 이미지 URL). 서버에 저장/조회된다.
class PublicProfile {
  final String userId;
  final String nickname;

  /// 서버(Storage) 이미지 URL. 없으면 null → 이니셜 아바타 표시.
  final String? profileImageUrl;
  final String? coverImageUrl;
  final String? statusMessage;
  final DateTime updatedAt;

  const PublicProfile({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
    this.coverImageUrl,
    this.statusMessage,
    required this.updatedAt,
  });
}

/// 프로필 발행/조회 서비스. hanchat_firebase가 Firestore+Storage 구현 제공.
abstract interface class ProfileService {
  /// 내 프로필을 서버에 올린다. localProfilePath/localCoverPath는 기기의
  /// 리사이즈된 이미지 파일 경로 (구현체가 Storage에 업로드).
  Future<void> publish({
    required String userId,
    required String nickname,
    String? localProfilePath,
    String? localCoverPath,
    String? statusMessage,
  });

  /// 상대 프로필 조회 (없으면 null).
  Future<PublicProfile?> fetch(String userId);
}

/// 상대 프로필 조회 UseCase.
class GetProfileUseCase {
  final ProfileService _service;
  const GetProfileUseCase(this._service);

  Future<PublicProfile?> call(String userId) => _service.fetch(userId);
}

/// 내 프로필 발행 UseCase (사진 변경 시 호출).
class PublishProfileUseCase {
  final ProfileService _service;
  const PublishProfileUseCase(this._service);

  Future<void> call({
    required String userId,
    required String nickname,
    String? localProfilePath,
    String? localCoverPath,
    String? statusMessage,
  }) =>
      _service.publish(
        userId: userId,
        nickname: nickname,
        localProfilePath: localProfilePath,
        localCoverPath: localCoverPath,
        statusMessage: statusMessage,
      );
}
