// 신고 (UGC 안전 — 앱스토어 1.2 / EU DSA 요건)
//
// 차단(이미 구현)과 짝을 이룬다. 신고는 서버로 접수되어 운영자가 검토한다.
// 채팅 내용은 24시간 후 사라지므로, 신고 시점에 스냅샷을 함께 첨부해 증거를 남긴다.
import 'errors.dart';

/// 신고 사유.
enum ReportReason {
  spam, // 스팸/광고
  harassment, // 괴롭힘/욕설
  sexual, // 음란물
  illegal, // 불법정보(사기·도박 등)
  other, // 기타
}

/// 신고 대상 종류.
enum ReportTargetType { message, profile }

/// 신고 접수 항목.
class Report {
  final String id;
  final String reporterId;
  final ReportTargetType targetType;

  /// 신고 대상 (메시지 id 또는 사용자 id)
  final String targetId;

  /// 신고당한 사용자 id
  final String reportedUserId;
  final ReportReason reason;

  /// 자유 서술 (선택)
  final String? detail;

  /// 증거 스냅샷 (메시지 내용 등 — 24h 삭제 전에 확보)
  final String? snapshot;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reportedUserId,
    required this.reason,
    this.detail,
    this.snapshot,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporterId': reporterId,
        'targetType': targetType.name,
        'targetId': targetId,
        'reportedUserId': reportedUserId,
        'reason': reason.name,
        'detail': detail,
        'snapshot': snapshot,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 사용자 정지 기록 (운영자가 남기는 사유 메모 포함).
class Suspension {
  final String userId;
  final String reason; // 정지 사유 (운영자 메모)
  final String adminId; // 정지시킨 관리자
  final DateTime suspendedAt;

  const Suspension({
    required this.userId,
    required this.reason,
    required this.adminId,
    required this.suspendedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'reason': reason,
        'adminId': adminId,
        'suspendedAt': suspendedAt.toIso8601String(),
      };

  factory Suspension.fromJson(Map<String, dynamic> json) => Suspension(
        userId: json['userId'] as String,
        reason: json['reason'] as String,
        adminId: json['adminId'] as String? ?? '',
        suspendedAt: DateTime.parse(json['suspendedAt'] as String),
      );
}

/// 신고 접수 + (관리자) 조회·정지 서비스. hanchat_firebase가 Firestore 구현 제공.
abstract interface class ReportService {
  Future<void> submit(Report report);

  /// 관리자: 접수된 신고 목록 (adminToken으로 서버가 권한 확인).
  Future<List<Report>> list({required String adminToken});

  /// 관리자: 유저 정지 (사유 메모 필수). 정지된 유저는 서버가 접근을 막는다.
  Future<void> suspendUser(
      {required String userId,
      required String reason,
      required String adminToken});

  /// 관리자: 정지 목록.
  Future<List<Suspension>> suspensions({required String adminToken});

  /// 관리자: 정지 해제.
  Future<void> unsuspend({required String userId, required String adminToken});
}

/// 신고 접수 UseCase.
class SubmitReportUseCase {
  final ReportService _service;
  const SubmitReportUseCase(this._service);

  Future<void> call({
    required String reporterId,
    required ReportTargetType targetType,
    required String targetId,
    required String reportedUserId,
    required ReportReason reason,
    String? detail,
    String? snapshot,
  }) =>
      _service.submit(Report(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        reporterId: reporterId,
        targetType: targetType,
        targetId: targetId,
        reportedUserId: reportedUserId,
        reason: reason,
        detail: detail,
        snapshot: snapshot,
        createdAt: DateTime.now(),
      ));
}

/// 관리자 신고·정지 관리 UseCase (관리자 토큰 필요).
class AdminModerationUseCase {
  final ReportService _service;
  const AdminModerationUseCase(this._service);

  Future<List<Report>> reports(String adminToken) =>
      _service.list(adminToken: adminToken);

  Future<List<Suspension>> suspensions(String adminToken) =>
      _service.suspensions(adminToken: adminToken);

  Future<void> suspend(
      {required String userId,
      required String reason,
      required String adminToken}) {
    if (reason.trim().isEmpty) {
      throw const ValidationException('error.suspendReasonRequired');
    }
    return _service.suspendUser(
        userId: userId, reason: reason.trim(), adminToken: adminToken);
  }

  Future<void> unsuspend(
          {required String userId, required String adminToken}) =>
      _service.unsuspend(userId: userId, adminToken: adminToken);
}
