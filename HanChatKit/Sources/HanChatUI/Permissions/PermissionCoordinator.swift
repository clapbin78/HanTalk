import Foundation
import UserNotifications
import Contacts
import AppTrackingTransparency
import HanChatCore

/// 최초 설치 시 권한 요청 순서를 관리한다.
///
/// 순서 원칙 (허용률을 높이는 순서):
/// 1. 약관/개인정보 동의 (법적 필수 — 권한 아님)
/// 2. 알림 권한 — "메시지 도착을 알려드려요" 맥락 설명 후 요청
/// 3. 연락처 권한 — 친구 찾기 시점에 요청 (설치 직후 X)
/// 4. ATT — 추적 SDK를 쓸 때만. 기본 비활성 (한톡은 광고/추적 없음)
@MainActor
public final class PermissionCoordinator: ObservableObject {

    @Published public private(set) var notificationsGranted = false
    @Published public private(set) var contactsGranted = false

    public init() {}

    // MARK: 알림

    public func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        notificationsGranted = granted
        return granted
    }

    // MARK: 연락처

    public func requestContacts() async -> Bool {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        contactsGranted = granted
        return granted
    }

    /// 연락처 읽기 → 도메인 모델로 변환. (권한 승인 후 호출)
    public nonisolated func readContacts() async throws -> [DeviceContact] {
        try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
                as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var contacts: [DeviceContact] = []
            try store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.familyName)\(contact.givenName)"
                let numbers = contact.phoneNumbers.map { $0.value.stringValue }
                guard !numbers.isEmpty else { return }
                contacts.append(DeviceContact(
                    name: name.isEmpty ? (numbers.first ?? "") : name,
                    phoneNumbers: numbers
                ))
            }
            return contacts
        }.value
    }

    // MARK: ATT (앱 추적 투명성)

    /// 광고·분석 SDK로 사용자를 추적할 때만 필요. 추적 안 하면 요청하지 말 것
    /// (불필요한 요청은 심사 리젝 사유가 될 수 있다).
    public func requestTrackingIfNeeded(enabled: Bool) async {
        guard enabled else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}
