import SwiftUI
import HanChatCore

/// 미니 그림판. 요구사항대로 딱 두 가지만 설정: 펜 색상, 펜 두께.
/// 결과물은 이미지가 아니라 획 벡터(DrawingPayload)로 전송된다.
struct DrawingCanvasView: View {
    let onSend: (DrawingPayload) -> Void

    @State private var strokes: [Stroke] = []
    @State private var currentPoints: [StrokePoint] = []
    @State private var startedAt: Date?

    @State private var penColorHex = "#1C1C1E"
    @State private var penWidth: Double = 4

    @Environment(\.dismiss) private var dismiss

    private let palette = [
        "#1C1C1E", // 검정
        "#FF3B30", // 빨강
        "#FF9500", // 주황
        "#FFCC00", // 노랑
        "#34C759", // 초록
        "#007AFF", // 파랑
        "#AF52DE", // 보라
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                canvas
                controls
            }
            .padding()
            .navigationTitle("그림 그리기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("보내기") { send() }
                        .disabled(strokes.isEmpty && currentPoints.isEmpty)
                }
            }
        }
    }

    // MARK: 캔버스

    private var canvas: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                for stroke in strokes {
                    draw(stroke, in: &context)
                }
                if !currentPoints.isEmpty {
                    draw(
                        Stroke(colorHex: penColorHex, width: penWidth, points: currentPoints),
                        in: &context
                    )
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray4)))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startedAt == nil { startedAt = .now }
                        let t = Date.now.timeIntervalSince(startedAt!)
                        currentPoints.append(
                            StrokePoint(x: value.location.x, y: value.location.y, t: t)
                        )
                    }
                    .onEnded { _ in
                        guard !currentPoints.isEmpty else { return }
                        strokes.append(
                            Stroke(colorHex: penColorHex, width: penWidth, points: currentPoints)
                        )
                        currentPoints = []
                    }
            )
            .onAppear { canvasSize = geometry.size }
            .onChange(of: geometry.size) { _, newSize in canvasSize = newSize }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @State private var canvasSize: CGSize = .zero

    // MARK: 컨트롤 (색상 + 두께만!)

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if hex == penColorHex {
                                Circle().stroke(Color.accentColor, lineWidth: 3).padding(-4)
                            }
                        }
                        .onTapGesture { penColorHex = hex }
                }
                Spacer()
                Button {
                    if !strokes.isEmpty { strokes.removeLast() }
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.title2)
                }
                .disabled(strokes.isEmpty)
            }

            HStack {
                Image(systemName: "pencil.tip")
                Slider(value: $penWidth, in: 1...20)
                Circle()
                    .fill(Color(hex: penColorHex))
                    .frame(width: max(penWidth, 4), height: max(penWidth, 4))
                    .frame(width: 24, height: 24)
            }
        }
    }

    // MARK: 헬퍼

    private func draw(_ stroke: Stroke, in context: inout GraphicsContext) {
        guard stroke.points.count > 1 else {
            if let point = stroke.points.first {
                let dot = Path(ellipseIn: CGRect(
                    x: point.x - stroke.width / 2, y: point.y - stroke.width / 2,
                    width: stroke.width, height: stroke.width
                ))
                context.fill(dot, with: .color(Color(hex: stroke.colorHex)))
            }
            return
        }
        var path = Path()
        path.move(to: CGPoint(x: stroke.points[0].x, y: stroke.points[0].y))
        for point in stroke.points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.y))
        }
        context.stroke(
            path,
            with: .color(Color(hex: stroke.colorHex)),
            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        )
    }

    private func send() {
        var allStrokes = strokes
        if !currentPoints.isEmpty {
            allStrokes.append(Stroke(colorHex: penColorHex, width: penWidth, points: currentPoints))
        }
        let payload = DrawingPayload(
            canvasSize: .init(
                width: Double(max(canvasSize.width, 1)),
                height: Double(max(canvasSize.height, 1))
            ),
            strokes: allStrokes
        )
        onSend(payload)
    }
}

extension Color {
    /// "#RRGGBB" → Color
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
