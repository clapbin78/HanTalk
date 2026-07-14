// 공지사항 · FAQ · 관리자 모드
//
// 비용 설계: 앱은 "버전 번호"만 자주 확인하고, 버전이 바뀌었을 때만 본문을 받아
// 로컬 캐시한다. 2천만 사용자여도 본문 읽기는 공지가 바뀔 때만 → 서버 비용 최소.
// (실서비스는 Firebase Hosting의 정적 JSON으로 두면 Firestore 읽기 과금도 0)

/// 공지 또는 FAQ 항목.
class SupportPost {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  const SupportPost({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SupportPost.fromJson(Map<String, dynamic> json) => SupportPost(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

enum SupportChannel { announcements, faq }

/// 공지/FAQ 조회 + (관리자) 작성. 서버 구현은 hanchat_firebase가 제공.
abstract interface class SupportContentService {
  /// 현재 콘텐츠 버전 (자주 호출해도 저렴한 경량 조회).
  Future<int> version(SupportChannel channel);

  /// 전체 목록 (버전이 바뀌었을 때만 호출).
  Future<List<SupportPost>> fetch(SupportChannel channel);

  /// 관리자 글 작성. adminToken은 AdminService.unlock으로 발급받은 것.
  Future<void> post(SupportChannel channel, SupportPost post,
      {required String adminToken});
}

/// 관리자 모드. 비밀번호 검증은 서버(Cloud Function)에서 하고
/// 앱에는 비번을 절대 두지 않는다. 검증 성공 시 짧은 수명의 토큰을 받는다.
///
/// 관리자 기능은 계속 늘어날 예정이라 토큰 하나로 모든 관리자 API를 게이트한다.
abstract interface class AdminService {
  /// 비밀번호를 서버에 보내 검증. 성공 시 관리자 토큰, 실패 시 null.
  Future<String?> unlock(String password);
}

/// 공지/FAQ 조회 UseCase — 버전 비교로 캐시를 활용.
class GetSupportContentUseCase {
  final SupportContentService _service;
  const GetSupportContentUseCase(this._service);

  Future<int> version(SupportChannel channel) => _service.version(channel);
  Future<List<SupportPost>> fetch(SupportChannel channel) =>
      _service.fetch(channel);
}

/// 관리자 진입 UseCase.
class UnlockAdminUseCase {
  final AdminService _service;
  const UnlockAdminUseCase(this._service);

  Future<String?> call(String password) => _service.unlock(password);
}

/// 관리자 글 작성 UseCase.
class PostSupportUseCase {
  final SupportContentService _service;
  const PostSupportUseCase(this._service);

  Future<void> call(SupportChannel channel, SupportPost post,
          {required String adminToken}) =>
      _service.post(channel, post, adminToken: adminToken);
}
