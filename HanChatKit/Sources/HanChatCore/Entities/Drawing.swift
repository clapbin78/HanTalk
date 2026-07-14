import Foundation

/// 그림 메시지 페이로드.
///
/// 이미지가 아니라 **획(stroke) 벡터 데이터**로 저장한다.
/// - 용량이 수 KB 수준이라 전송·저장 비용이 거의 없다.
/// - 수신 측에서 타임스탬프 순서로 다시 그리면 "그리는 과정 재생"이 공짜로 된다.
/// - 나중에 이모티콘 샵의 움직이는 이모티콘 포맷으로 그대로 재사용한다.
public struct DrawingPayload: Codable, Hashable, Sendable {
    /// 그린 캔버스의 논리 크기. 수신 측에서 비율 유지 스케일링에 사용.
    public var canvasSize: Size
    public var strokes: [Stroke]

    public init(canvasSize: Size, strokes: [Stroke]) {
        self.canvasSize = canvasSize
        self.strokes = strokes
    }

    /// 전체 그리는 데 걸린 시간(초). 재생 길이 계산용.
    public var totalDuration: TimeInterval {
        strokes.last?.points.last?.t ?? 0
    }

    public struct Size: Codable, Hashable, Sendable {
        public var width: Double
        public var height: Double
        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }
}

/// 펜 한 획. 설정 가능한 것은 색상과 두께뿐 (요구사항: 미니 그림판).
public struct Stroke: Codable, Hashable, Sendable {
    /// "#RRGGBB"
    public var colorHex: String
    public var width: Double
    public var points: [StrokePoint]

    public init(colorHex: String, width: Double, points: [StrokePoint]) {
        self.colorHex = colorHex
        self.width = width
        self.points = points
    }
}

public struct StrokePoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    /// 그리기 시작 시점 기준 경과 시간(초). 재생용.
    public var t: TimeInterval

    public init(x: Double, y: Double, t: TimeInterval) {
        self.x = x
        self.y = y
        self.t = t
    }

    enum CodingKeys: String, CodingKey { case x, y, t }
}
