import XCTest
@testable import HanChatCore
@testable import HanChatData

/// 이모티콘 갤러리 + 유료 판매 로직 테스트.
/// 유료 기능은 UI에서 숨겨져 있지만(paidEmoticonsEnabled=false) 로직은 여기서 항상 검증된다.
final class EmoticonTests: XCTestCase {

    // MARK: 테스트 더블

    actor MockEmoticonRepository: EmoticonRepository {
        var galleryItems: [Emoticon] = []
        var collection: [Emoticon] = []

        func upload(_ emoticon: Emoticon) async throws -> Emoticon {
            galleryItems.append(emoticon)
            return emoticon
        }
        func browse() async throws -> [Emoticon] { galleryItems }
        func myCollection() async throws -> [Emoticon] { collection }
        func isInCollection(id: String) async throws -> Bool {
            collection.contains { $0.id == id }
        }
        func addToCollection(_ emoticon: Emoticon) async throws {
            guard !collection.contains(where: { $0.id == emoticon.id }) else { return }
            collection.append(emoticon)
        }
    }

    struct MockUserRepository: UserRepository {
        var user: User? = User(nickname: "테스터", phoneNumberHash: "hash")
        func currentUser() async throws -> User? { user }
        func register(nickname: String, phoneNumber: String) async throws -> User {
            user ?? User(nickname: nickname, phoneNumberHash: "hash")
        }
    }

    struct FailingPaymentGateway: PaymentGateway {
        func charge(amount: Int, emoticonID: String, buyerID: String) async throws -> String {
            throw HanChatError.transport("결제 실패")
        }
    }

    private func makeEmoticon(price: Int = 0) -> Emoticon {
        Emoticon(
            name: "테스트",
            creatorID: "creator",
            creatorNickname: "만든이",
            payload: DrawingPayload(
                canvasSize: .init(width: 100, height: 100),
                strokes: [Stroke(colorHex: "#000000", width: 3, points: [
                    StrokePoint(x: 0, y: 0, t: 0), StrokePoint(x: 10, y: 10, t: 0.1),
                ])]
            ),
            price: price
        )
    }

    // MARK: 받기 / 구매

    func test_무료_이모티콘_받기() async throws {
        let repo = MockEmoticonRepository()
        let gateway = StubPaymentGateway()
        let acquire = AcquireEmoticonUseCase(
            emoticons: repo, users: MockUserRepository(), payment: gateway
        )

        let outcome = try await acquire(makeEmoticon(price: 0))

        XCTAssertEqual(outcome, .addedFree)
        let owned = await repo.collection
        XCTAssertEqual(owned.count, 1)
        let charges = await gateway.chargeCount()
        XCTAssertEqual(charges, 0, "무료는 결제가 발생하면 안 됨")
    }

    func test_유료_이모티콘_구매시_결제_후_보관함_추가() async throws {
        let repo = MockEmoticonRepository()
        let gateway = StubPaymentGateway()
        let acquire = AcquireEmoticonUseCase(
            emoticons: repo, users: MockUserRepository(), payment: gateway
        )

        let outcome = try await acquire(makeEmoticon(price: 50))

        guard case .purchased = outcome else {
            return XCTFail("구매 결과가 나와야 함, got \(outcome)")
        }
        let records = await gateway.records
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.amount, 50)
        let owned = await repo.collection
        XCTAssertEqual(owned.count, 1)
    }

    func test_중복_획득시_재결제_없음() async throws {
        let repo = MockEmoticonRepository()
        let gateway = StubPaymentGateway()
        let acquire = AcquireEmoticonUseCase(
            emoticons: repo, users: MockUserRepository(), payment: gateway
        )
        let emoticon = makeEmoticon(price: 50)

        _ = try await acquire(emoticon)
        let second = try await acquire(emoticon)

        XCTAssertEqual(second, .alreadyOwned)
        let charges = await gateway.chargeCount()
        XCTAssertEqual(charges, 1, "같은 이모티콘에 두 번 결제되면 안 됨")
    }

    func test_결제_실패시_보관함에_추가되지_않음() async throws {
        let repo = MockEmoticonRepository()
        let acquire = AcquireEmoticonUseCase(
            emoticons: repo, users: MockUserRepository(), payment: FailingPaymentGateway()
        )

        do {
            _ = try await acquire(makeEmoticon(price: 50))
            XCTFail("결제 실패는 throw 해야 함")
        } catch {
            let owned = await repo.collection
            XCTAssertTrue(owned.isEmpty, "결제 실패 시 이모티콘이 지급되면 안 됨")
        }
    }

    // MARK: 업로드 검증

    func test_업로드_빈_이름_거부() async {
        let upload = UploadEmoticonUseCase(
            emoticons: MockEmoticonRepository(), users: MockUserRepository(), allowPaid: false
        )
        do {
            _ = try await upload(name: "  ", payload: makeEmoticon().payload)
            XCTFail("빈 이름은 거부돼야 함")
        } catch {}
    }

    func test_업로드_빈_그림_거부() async {
        let upload = UploadEmoticonUseCase(
            emoticons: MockEmoticonRepository(), users: MockUserRepository(), allowPaid: false
        )
        do {
            _ = try await upload(
                name: "이름",
                payload: DrawingPayload(canvasSize: .init(width: 1, height: 1), strokes: [])
            )
            XCTFail("빈 그림은 거부돼야 함")
        } catch {}
    }

    func test_유료판매_플래그_꺼진_동안_유료_업로드_차단() async {
        let upload = UploadEmoticonUseCase(
            emoticons: MockEmoticonRepository(), users: MockUserRepository(),
            allowPaid: false // 🚩 현재 운영 상태
        )
        do {
            _ = try await upload(name: "유료임티", payload: makeEmoticon().payload, price: 500)
            XCTFail("플래그가 꺼져 있으면 유료 업로드는 차단돼야 함")
        } catch {}
    }

    func test_유료판매_플래그_켜면_유료_업로드_가능() async throws {
        let repo = MockEmoticonRepository()
        let upload = UploadEmoticonUseCase(
            emoticons: repo, users: MockUserRepository(),
            allowPaid: true // 🚩 Phase 3 상태
        )
        let uploaded = try await upload(name: "유료임티", payload: makeEmoticon().payload, price: 500)

        XCTAssertEqual(uploaded.price, 500)
        let gallery = await repo.galleryItems
        XCTAssertEqual(gallery.count, 1)
    }

    func test_업로드하면_내_보관함에도_자동_추가() async throws {
        let repo = MockEmoticonRepository()
        let upload = UploadEmoticonUseCase(
            emoticons: repo, users: MockUserRepository(), allowPaid: false
        )
        _ = try await upload(name: "내작품", payload: makeEmoticon().payload)

        let owned = await repo.collection
        XCTAssertEqual(owned.count, 1)
    }

    // MARK: 인메모리 갤러리

    func test_인메모리_갤러리_샘플과_업로드() async throws {
        let store = InMemoryEmoticonStore(seedSamples: true)
        let initial = try await store.fetchAll()
        XCTAssertEqual(initial.count, 2, "샘플 2개(하트/별)가 있어야 함")

        try await store.upload(makeEmoticon())
        let after = try await store.fetchAll()
        XCTAssertEqual(after.count, 3)
        XCTAssertEqual(after.first?.name, "테스트", "최신순 정렬")
    }
}
