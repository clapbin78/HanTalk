import SwiftUI
import HanChatCore

/// 그림 메시지 표시 + "그리는 과정 재생".
///
/// 아이메시지 같은 효과지만 서버 비용은 0에 가깝다:
/// 각 점에 기록된 타임스탬프(t)만으로 수신 기기에서 그리기를 다시 재생하기 때문.
/// (실시간 스트리밍이 아니라 로컬 애니메이션)
struct DrawingReplayView: View {
    let payload: DrawingPayload

    @State private var replayStartedAt: Date?

    var body: some View {
        TimelineView(.animation(paused: replayStartedAt == nil)) { timeline in
            Canvas { context, size in
                let scaleX = size.width / max(payload.canvasSize.width, 1)
                let scaleY = size.height / max(payload.canvasSize.height, 1)
                let elapsed: TimeInterval = {
                    guard let start = replayStartedAt else { return .infinity } // 정지 시 완성본
                    return timeline.date.timeIntervalSince(start)
                }()

                for stroke in payload.strokes {
                    // 재생 중이면 elapsed 시점까지 그려진 점만 표시
                    let visible = stroke.points.filter { $0.t <= elapsed }
                    guard let first = visible.first else { continue }

                    var path = Path()
                    path.move(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
                    for point in visible.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
                    }
                    if visible.count == 1 {
                        let width = stroke.width * min(scaleX, scaleY)
                        path = Path(ellipseIn: CGRect(
                            x: first.x * scaleX - width / 2, y: first.y * scaleY - width / 2,
                            width: width, height: width
                        ))
                        context.fill(path, with: .color(Color(hex: stroke.colorHex)))
                    } else {
                        context.stroke(
                            path,
                            with: .color(Color(hex: stroke.colorHex)),
                            style: StrokeStyle(
                                lineWidth: stroke.width * min(scaleX, scaleY),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                replayStartedAt = .now
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .accessibilityLabel("그리는 과정 재생")
        }
        .onAppear {
            // 도착 직후 1회 자동 재생
            if replayStartedAt == nil {
                replayStartedAt = .now
            }
        }
    }
}
