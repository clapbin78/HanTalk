import Foundation

// MARK: - 이모티콘 UseCase
// 유료 판매 로직은 완성돼 있지만 allowPaid(=paidEmoticonsEnabled 플래그)가
// false인 동안에는 유료 업로드가 차단되고 UI에도 노출되지 않는다.

public struct UploadEmoticonUseCase: Sendable {
    let emoticons: any EmoticonRepository
    let users: any UserRepository
    /// HanChatConfiguration.paidEmoticonsEnabled 주입
    let allowPaid: Bool

    public init(emoticons: any EmoticonRepository, users: any UserRepository, allowPaid: Bool) {
        self.emoticons = emoticons
        self.users = users
        self.allowPaid = allowPaid
    }

    @discardableResult
    public func callAsFunction(name: String, payload: DrawingPayload, price: Int = 0) async throws -> Emoticon {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HanChatError.storage("이모티콘 이름을 입력해 주세요.")
        }
        guard !payload.strokes.isEmpty else {
            throw HanChatError.storage("그림을 먼저 그려주세요.")
        }
        guard price >= 0 else {
            throw HanChatError.storage("가격은 0 이상이어야 해요.")
        }
        guard price == 0 || allowPaid else {
            throw HanChatError.storage("유료 이모티콘 판매는 아직 열리지 않았어요.")
        }
        guard let me = try await users.currentUser() else {
            throw HanChatError.notRegistered
        }

        let emoticon = Emoticon(
            name: trimmed,
            creatorID: me.id,
            creatorNickname: me.nickname,
            payload: payload,
            price: price
        )
        let uploaded = try await emoticons.upload(emoticon)
        // 내가 만든 건 자동으로 내 보관함에
        try await emoticons.addToCollection(uploaded)
        return uploaded
    }
}

public struct BrowseEmoticonsUseCase: Sendable {
    let emoticons: any EmoticonRepository
    public init(emoticons: any EmoticonRepository) { self.emoticons = emoticons }

    public func callAsFunction() async throws -> [Emoticon] {
        try await emoticons.browse()
    }
}

public struct GetMyEmoticonsUseCase: Sendable {
    let emoticons: any EmoticonRepository
    public init(emoticons: any EmoticonRepository) { self.emoticons = emoticons }

    public func callAsFunction() async throws -> [Emoticon] {
        try await emoticons.myCollection()
    }
}

/// 이모티콘 받기(무료) / 구매(유료 — 플래그 뒤에 숨겨진 경로).
public struct AcquireEmoticonUseCase: Sendable {
    let emoticons: any EmoticonRepository
    let users: any UserRepository
    let payment: any PaymentGateway

    public init(
        emoticons: any EmoticonRepository,
        users: any UserRepository,
        payment: any PaymentGateway
    ) {
        self.emoticons = emoticons
        self.users = users
        self.payment = payment
    }

    public enum Outcome: Equatable, Sendable {
        case alreadyOwned
        case addedFree
        case purchased(paymentID: String)
    }

    @discardableResult
    public func callAsFunction(_ emoticon: Emoticon) async throws -> Outcome {
        // 1) 중복 획득/중복 결제 방지
        if try await emoticons.isInCollection(id: emoticon.id) {
            return .alreadyOwned
        }
        guard let me = try await users.currentUser() else {
            throw HanChatError.notRegistered
        }

        // 2) 유료면 결제 먼저 (실패 시 보관함에 추가되지 않음)
        var outcome: Outcome = .addedFree
        if !emoticon.isFree {
            let paymentID = try await payment.charge(
                amount: emoticon.price,
                emoticonID: emoticon.id,
                buyerID: me.id
            )
            outcome = .purchased(paymentID: paymentID)
        }

        // 3) 보관함 추가
        try await emoticons.addToCollection(emoticon)
        return outcome
    }
}
