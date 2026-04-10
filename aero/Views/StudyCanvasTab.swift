import SwiftUI
import SwiftData
import Combine

// MARK: - Tab (por estudio)

struct StudyCanvasTab: View {
    @ObservedObject var viewModel: StudyDetailViewModel
    let isLargeCanvas: Bool

    @Environment(\.modelContext) private var modelContext
    @StateObject private var store: StudyCanvasStore

    init(viewModel: StudyDetailViewModel, isLargeCanvas: Bool) {
        self.viewModel = viewModel
        self.isLargeCanvas = isLargeCanvas
        _store = StateObject(wrappedValue: StudyCanvasStore(study: viewModel.study))
    }

    var body: some View {
        StudyBoardCanvasView(store: store, isLargeCanvas: isLargeCanvas)
            .onAppear {
                store.attach(modelContext: modelContext)
            }
    }
}

// MARK: - Store

@MainActor
final class StudyCanvasStore: ObservableObject {
    let study: SDStudy

    @Published var document: BoardDocument = .empty
    @Published var tool: CanvasDrawingTool = .select
    @Published var strokeColor: Color = Color(red: 0.25, green: 0.2, blue: 0.55)
    @Published var strokeWidth: CGFloat = 3
    @Published var selectedId: UUID?

    private var modelContext: ModelContext?
    private var saveTask: Task<Void, Never>?

    init(study: SDStudy) {
        self.study = study
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        if let json = study.board?.documentJSON, let doc = BoardDocument.decode(from: json) {
            document = doc
        } else {
            document = .empty
        }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    func persistImmediately() {
        saveTask?.cancel()
        persist()
    }

    private func persist() {
        guard let ctx = modelContext else { return }
        let json = document.encodedJSON() ?? "{\"elements\":[]}"
        if let board = study.board {
            board.documentJSON = json
            board.updatedAt = Date()
        } else {
            let board = SDStudyBoard(documentJSON: json, study: study)
            study.board = board
            ctx.insert(board)
        }
        try? ctx.save()
    }

    func clearBoard() {
        document = .empty
        selectedId = nil
        persistImmediately()
    }

    func deleteSelected() {
        guard let id = selectedId else { return }
        document.elements.removeAll { $0.id == id }
        selectedId = nil
        scheduleSave()
    }

    func bringForward(_ id: UUID) {
        guard let i = document.elements.firstIndex(where: { $0.id == id }), i < document.elements.count - 1 else { return }
        document.elements.swapAt(i, i + 1)
        scheduleSave()
    }
}

enum CanvasDrawingTool: String, CaseIterable, Identifiable {
    case select
    case hand
    case text
    case rectangle
    case ellipse
    case arrow
    case pen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .select: return "Seleccionar"
        case .hand: return "Mover lienzo"
        case .text: return "Texto"
        case .rectangle: return "Rectángulo"
        case .ellipse: return "Elipse"
        case .arrow: return "Flecha"
        case .pen: return "Lápiz"
        }
    }

    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .hand: return "hand.draw"
        case .text: return "textformat"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .arrow: return "arrow.up.right"
        case .pen: return "pencil.tip"
        }
    }
}

// MARK: - Canvas view

private struct TextEditTarget: Identifiable {
    let id: UUID
}

private struct StudyBoardCanvasView: View {
    @ObservedObject var store: StudyCanvasStore
    let isLargeCanvas: Bool

    @State private var panOffset: CGSize = .zero
    @State private var canvasZoom: CGFloat = 1
    @State private var panGestureAnchor: CGSize?
    @State private var pinchBaseZoom: CGFloat = 1
    @State private var isPinching = false

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var penScratch: [CanvasPoint] = []
    @State private var showClearConfirm = false
    @State private var textEditTarget: TextEditTarget?
    @State private var moveOrigin: [UUID: CGPoint] = [:]

    var body: some View {
        VStack(spacing: 0) {
            canvasToolbar
            GeometryReader { geo in
                let vp = geo.size
                ZStack {
                    Color(.secondarySystemBackground)
                    ZStack(alignment: .topLeading) {
                        Color(red: 0.98, green: 0.98, blue: 0.99)
                        InfiniteViewportGrid(pan: panOffset, zoom: canvasZoom, viewport: vp)
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .frame(width: 1, height: 1)
                                .allowsHitTesting(false)
                            ForEach(store.document.elements) { el in
                                elementLayer(el, zoom: canvasZoom)
                            }
                            if store.tool == .pen, penScratch.count >= 2 {
                                let c = store.strokeColor
                                let w = store.strokeWidth
                                PenStrokePath(points: penScratch, originX: 0, originY: 0)
                                    .stroke(c, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
                                    .allowsHitTesting(false)
                            }
                            if let preview = shapePreviewRect {
                                previewShape(preview)
                                    .allowsHitTesting(false)
                            }
                        }
                        .scaleEffect(canvasZoom, anchor: .topLeading)
                        .offset(x: panOffset.width, y: panOffset.height)
                    }
                    .frame(width: vp.width, height: vp.height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                    .coordinateSpace(name: "boardViewport")
                    .gesture(canvasDragGesture)
                    .simultaneousGesture(magnifyGesture)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .background(Color(.secondarySystemBackground))
        }
        .alert("¿Vaciar la pizarra?", isPresented: $showClearConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Vaciar", role: .destructive) { store.clearBoard() }
        } message: {
            Text("Se borrarán todas las figuras y textos de este estudio.")
        }
        .sheet(item: $textEditTarget) { target in
            if let idx = store.document.elements.firstIndex(where: { $0.id == target.id }),
               store.document.elements[idx].kind == .text {
                TextEditSheet(
                    text: Binding(
                        get: { store.document.elements[idx].text },
                        set: { store.document.elements[idx].text = $0; store.scheduleSave() }
                    ),
                    onDone: { textEditTarget = nil }
                )
            }
        }
    }

    private func screenToWorld(_ screen: CGPoint) -> CGPoint {
        CGPoint(
            x: (screen.x - panOffset.width) / canvasZoom,
            y: (screen.y - panOffset.height) / canvasZoom
        )
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { m in
                if !isPinching {
                    pinchBaseZoom = canvasZoom
                    isPinching = true
                }
                canvasZoom = min(max(pinchBaseZoom * m, 0.12), 6)
            }
            .onEnded { _ in
                isPinching = false
                pinchBaseZoom = canvasZoom
            }
    }

    private var canvasDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("boardViewport"))
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }

    private var shapePreviewRect: CGRect? {
        guard let a = dragStart, let b = dragCurrent,
              store.tool != .pen, store.tool != .select, store.tool != .text, store.tool != .hand else { return nil }
        return normalizeRect(a, b)
    }

    @ViewBuilder
    private func previewShape(_ r: CGRect) -> some View {
        let c = store.strokeColor
        let w = store.strokeWidth
        switch store.tool {
        case .rectangle:
            Rectangle()
                .stroke(c, lineWidth: w)
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
        case .ellipse:
            Ellipse()
                .stroke(c, lineWidth: w)
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
        case .arrow:
            ArrowShape(from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.maxX, y: r.maxY))
                .stroke(c, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        default:
            EmptyView()
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if store.tool == .hand {
            if panGestureAnchor == nil { panGestureAnchor = panOffset }
            if let a = panGestureAnchor {
                panOffset = CGSize(width: a.width + value.translation.width, height: a.height + value.translation.height)
            }
            return
        }

        let p = screenToWorld(value.location)
        switch store.tool {
        case .pen:
            if penScratch.isEmpty {
                penScratch.append(CanvasPoint(x: p.x, y: p.y))
            } else {
                let last = penScratch.last!
                let q = CGPoint(x: last.x, y: last.y)
                if hypot(p.x - q.x, p.y - q.y) > 1.5 {
                    penScratch.append(CanvasPoint(x: p.x, y: p.y))
                }
            }
        case .rectangle, .ellipse, .arrow:
            if dragStart == nil { dragStart = p }
            dragCurrent = p
        case .select, .text, .hand:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        if store.tool == .hand {
            panGestureAnchor = nil
            return
        }

        let p = screenToWorld(value.location)
        let hex = store.strokeColor.toHexRGB()
        let sw = Double(store.strokeWidth)
        let moved = hypot(value.translation.width, value.translation.height)

        if store.tool == .select, moved < 12 {
            if let id = hitTest(screenToWorld(value.startLocation)) {
                store.selectedId = id
            } else {
                store.selectedId = nil
            }
            dragStart = nil
            dragCurrent = nil
            penScratch = []
            return
        }

        if store.tool == .text, moved < 14 {
            let pt = screenToWorld(value.startLocation)
            let el = BoardElement(
                id: UUID(),
                kind: .text,
                x: Double(pt.x - 24),
                y: Double(pt.y - 18),
                width: 280,
                height: 120,
                colorHex: hex,
                strokeWidth: 1,
                text: "",
                points: nil
            )
            store.document.elements.append(el)
            store.selectedId = el.id
            textEditTarget = TextEditTarget(id: el.id)
            store.scheduleSave()
            dragStart = nil
            dragCurrent = nil
            penScratch = []
            return
        }

        switch store.tool {
        case .pen:
            if penScratch.count >= 2 {
                let xs = penScratch.map(\.x)
                let ys = penScratch.map(\.y)
                let minX = xs.min()!
                let minY = ys.min()!
                let maxX = xs.max()!
                let maxY = ys.max()!
                let el = BoardElement(
                    id: UUID(),
                    kind: .pen,
                    x: minX,
                    y: minY,
                    width: max(maxX - minX, 4),
                    height: max(maxY - minY, 4),
                    colorHex: hex,
                    strokeWidth: sw,
                    text: "",
                    points: penScratch
                )
                store.document.elements.append(el)
                store.scheduleSave()
            }
            penScratch = []
        case .rectangle, .ellipse, .arrow:
            guard let a = dragStart else { break }
            let r = normalizeRect(a, p)
            let span = hypot(r.width, r.height)
            guard span > 10 else {
                dragStart = nil
                dragCurrent = nil
                break
            }
            let kind: BoardElement.Kind =
                store.tool == .rectangle ? .rectangle : store.tool == .ellipse ? .ellipse : .arrow
            let el = BoardElement(
                id: UUID(),
                kind: kind,
                x: Double(r.minX),
                y: Double(r.minY),
                width: Double(r.width),
                height: Double(r.height),
                colorHex: hex,
                strokeWidth: sw,
                text: "",
                points: nil
            )
            store.document.elements.append(el)
            store.selectedId = el.id
            store.scheduleSave()
            dragStart = nil
            dragCurrent = nil
        default:
            dragStart = nil
            dragCurrent = nil
            penScratch = []
        }
    }

    private func hitTest(_ point: CGPoint) -> UUID? {
        for el in store.document.elements.reversed() {
            if bounds(of: el).contains(point) { return el.id }
        }
        return nil
    }

    private func bounds(of el: BoardElement) -> CGRect {
        switch el.kind {
        case .text:
            CGRect(
                x: el.x,
                y: el.y,
                width: max(el.width, 80),
                height: max(el.height, 44)
            )
        case .pen:
            CGRect(x: el.x, y: el.y, width: max(el.width, 8), height: max(el.height, 8))
        default:
            CGRect(x: el.x, y: el.y, width: max(el.width, 8), height: max(el.height, 8))
        }
    }

    private func normalizeRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    private var canvasToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CanvasDrawingTool.allCases) { t in
                    Button {
                        store.tool = t
                    } label: {
                        Image(systemName: t.symbol)
                            .font(.body.weight(store.tool == t ? .semibold : .regular))
                            .frame(width: 38, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(store.tool == t ? Color.indigo.opacity(0.22) : Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(t.label)
                }

                Divider().frame(height: 26)

                Group {
                    Button {
                        canvasZoom = min(canvasZoom * 1.2, 6)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Acercar")

                    Button {
                        canvasZoom = max(canvasZoom / 1.2, 0.12)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Alejar")

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            canvasZoom = 1
                            panOffset = .zero
                        }
                    } label: {
                        Image(systemName: "viewfinder")
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Centrar vista")
                }
                .buttonStyle(.plain)

                Divider().frame(height: 26)

                ColorPicker("", selection: $store.strokeColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 36, height: 36)

                Menu {
                    Button("Fino") { store.strokeWidth = 2 }
                    Button("Medio") { store.strokeWidth = 4 }
                    Button("Grueso") { store.strokeWidth = 7 }
                } label: {
                    Image(systemName: "lineweight")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Grosor del trazo")

                if store.selectedId != nil {
                    Button {
                        store.bringForward(store.selectedId!)
                    } label: {
                        Image(systemName: "square.2.layers.3d.top.filled")
                    }
                    .accessibilityLabel("Traer al frente")

                    Button(role: .destructive) {
                        store.deleteSelected()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Eliminar selección")
                }

                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "eraser.line.dashed")
                }
                .accessibilityLabel("Vaciar pizarra")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func elementLayer(_ el: BoardElement, zoom: CGFloat) -> some View {
        let selected = store.selectedId == el.id
        let c = Color(hex: el.colorHex)
        let w = CGFloat(el.strokeWidth)
        let textW = max(CGFloat(el.width), 56)
        let textH = max(CGFloat(el.height), 28)

        Group {
            switch el.kind {
            case .text:
                ZStack(alignment: .topLeading) {
                    if el.text.isEmpty {
                        Text(" ")
                            .font(.system(size: isLargeCanvas ? 19 : 17, weight: .regular, design: .rounded))
                            .foregroundStyle(.clear)
                    } else {
                        Text(el.text)
                            .font(.system(size: isLargeCanvas ? 19 : 17, weight: .regular, design: .rounded))
                            .foregroundStyle(c)
                            .multilineTextAlignment(.leading)
                    }
                    if selected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                Color.accentColor.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1.2 / max(zoom, 0.25), dash: [5, 4])
                            )
                            .frame(width: textW + 6, height: textH + 6)
                            .offset(x: -3, y: -3)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: textW, height: textH, alignment: .topLeading)
                .contentShape(Rectangle())
            case .rectangle:
                Rectangle()
                    .stroke(c, lineWidth: w)
                    .frame(width: CGFloat(el.width), height: CGFloat(el.height))
                    .overlay(
                        Rectangle()
                            .stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
                    )
            case .ellipse:
                Ellipse()
                    .stroke(c, lineWidth: w)
                    .frame(width: CGFloat(el.width), height: CGFloat(el.height))
                    .overlay(
                        Ellipse()
                            .stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
                    )
            case .arrow:
                ArrowShape(
                    from: .zero,
                    to: CGPoint(x: CGFloat(el.width), y: CGFloat(el.height))
                )
                .stroke(c, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
                .frame(width: CGFloat(el.width), height: CGFloat(el.height), alignment: .topLeading)
                .overlay(
                    Rectangle()
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
                        .frame(width: CGFloat(el.width), height: CGFloat(el.height))
                )
            case .pen:
                PenStrokePath(points: el.points ?? [], originX: CGFloat(el.x), originY: CGFloat(el.y))
                    .stroke(c, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
                    .frame(width: CGFloat(el.width), height: CGFloat(el.height))
            }
        }
        .offset(x: CGFloat(el.x), y: CGFloat(el.y))
        .simultaneousGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named("boardViewport"))
                .onChanged { g in
                    guard store.tool == .select, store.selectedId == el.id, el.kind != .pen else { return }
                    applyMove(id: el.id, translation: g.translation, zoom: zoom)
                }
                .onEnded { _ in
                    guard store.tool == .select, store.selectedId == el.id, el.kind != .pen else { return }
                    moveOrigin[el.id] = nil
                    store.scheduleSave()
                }
        )
        .onTapGesture {
            if store.tool == .select {
                store.selectedId = el.id
            } else if store.tool == .text, el.kind == .text {
                textEditTarget = TextEditTarget(id: el.id)
            }
        }
    }

    private func applyMove(id: UUID, translation: CGSize, zoom: CGFloat) {
        guard let i = store.document.elements.firstIndex(where: { $0.id == id }) else { return }
        var el = store.document.elements[i]
        if moveOrigin[id] == nil {
            moveOrigin[id] = CGPoint(x: el.x, y: el.y)
        }
        let o = moveOrigin[id]!
        let z = Double(max(zoom, 0.15))
        el.x = o.x + Double(translation.width) / z
        el.y = o.y + Double(translation.height) / z
        store.document.elements[i] = el
    }
}

// MARK: - Shapes

private struct ArrowShape: Shape {
    var from: CGPoint
    var to: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        let angle = atan2(to.y - from.y, to.x - from.x)
        let head: CGFloat = 13
        let spread = CGFloat.pi / 6
        let a1 = angle + .pi - spread
        let a2 = angle + .pi + spread
        let tip = to
        p.move(to: tip)
        p.addLine(to: CGPoint(x: tip.x + cos(a1) * head, y: tip.y + sin(a1) * head))
        p.move(to: tip)
        p.addLine(to: CGPoint(x: tip.x + cos(a2) * head, y: tip.y + sin(a2) * head))
        return p
    }
}

private struct PenStrokePath: Shape {
    var points: [CanvasPoint]
    var originX: CGFloat
    var originY: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: CGFloat(first.x) - originX, y: CGFloat(first.y) - originY))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: CGFloat(pt.x) - originX, y: CGFloat(pt.y) - originY))
        }
        return p
    }
}

/// Cuadrícula en coordenadas de mundo; se recorta al viewport (estilo lienzo infinito).
private struct InfiniteViewportGrid: View {
    var pan: CGSize
    var zoom: CGFloat
    var viewport: CGSize

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let z = max(zoom, 0.12)
            var stepWorld: CGFloat = 20
            while stepWorld * z < 14 { stepWorld *= 2 }
            while stepWorld * z > 56 { stepWorld /= 2 }

            let tlX = (0 - pan.width) / z
            let tlY = (0 - pan.height) / z
            let brX = (size.width - pan.width) / z
            let brY = (size.height - pan.height) / z

            let x0 = floor(tlX / stepWorld) * stepWorld
            let x1 = ceil(brX / stepWorld) * stepWorld
            let y0 = floor(tlY / stepWorld) * stepWorld
            let y1 = ceil(brY / stepWorld) * stepWorld

            var path = Path()
            var x = x0
            var lineCount = 0
            while x <= x1, lineCount < 220 {
                let sx = x * z + pan.width
                path.move(to: CGPoint(x: sx, y: 0))
                path.addLine(to: CGPoint(x: sx, y: size.height))
                x += stepWorld
                lineCount += 1
            }
            var y = y0
            lineCount = 0
            while y <= y1, lineCount < 220 {
                let sy = y * z + pan.height
                path.move(to: CGPoint(x: 0, y: sy))
                path.addLine(to: CGPoint(x: size.width, y: sy))
                y += stepWorld
                lineCount += 1
            }

            context.stroke(path, with: .color(Color.gray.opacity(0.11)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .frame(width: viewport.width, height: viewport.height)
    }
}

// MARK: - Text sheet

private struct TextEditSheet: View {
    @Binding var text: String
    var onDone: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextField("Escribe aquí", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(6...18)
                .padding()
                .focused($focused)
                .navigationTitle("Texto")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { onDone() }
                    }
                }
                .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
