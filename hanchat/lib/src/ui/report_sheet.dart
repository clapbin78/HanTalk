import 'package:flutter/material.dart';

import '../core/report.dart';
import '../data/client.dart';
import 'l10n.dart';

/// 신고 사유 선택 → 접수 → (선택) 차단 제안.
/// 메시지·프로필 어디서든 재사용.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  required String reportedUserId,
  String? snapshot,
  bool offerBlock = true,
}) async {
  final l10n = HanChatL10n.of(context);

  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    builder: (sheetContext) {
      final l = HanChatL10n.of(sheetContext);
      Widget item(ReportReason r, String key) => ListTile(
            title: Text(l.t(key)),
            onTap: () => Navigator.of(sheetContext).pop(r),
          );
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.t('report.title'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          item(ReportReason.spam, 'report.spam'),
          item(ReportReason.harassment, 'report.harassment'),
          item(ReportReason.sexual, 'report.sexual'),
          item(ReportReason.illegal, 'report.illegal'),
          item(ReportReason.other, 'report.other'),
        ]),
      );
    },
  );
  if (reason == null || !context.mounted) return;

  final me = await HanChat.client.getCurrentUser();
  if (me == null || !context.mounted) return;

  await HanChat.client.submitReport(
    reporterId: me.id,
    targetType: targetType,
    targetId: targetId,
    reportedUserId: reportedUserId,
    reason: reason,
    snapshot: snapshot,
  );
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(l10n.t('report.done')),
    behavior: SnackBarBehavior.floating,
  ));

  // 신고 후 차단 제안 (UGC 안전 — 신고+차단 세트)
  if (offerBlock && context.mounted) {
    final block = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.t('report.alsoBlock')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel'))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('friend.block'))),
        ],
      ),
    );
    if (block == true) {
      await HanChat.client.manageFriends.block(reportedUserId);
    }
  }
}
