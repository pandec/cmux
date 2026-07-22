import Foundation
import Testing
@testable import CmuxWorkspaces

@MainActor
@Suite("SurfaceCycleModel")
struct SurfaceCycleModelTests {
    private let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private let c = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!
    private let scope = SurfaceCycleScope.pane(
        UUID(uuidString: "10000000-0000-0000-0000-000000000000")!
    )

    @Test("A held cycle freezes MRU order and ignores preview focus")
    func frozenRingIgnoresPreviewFocus() throws {
        let model = SurfaceCycleModel()
        model.recordFocus(a)
        model.recordFocus(b)
        model.recordFocus(c)
        model.recordFocus(a)

        #expect(model.cycle(
            candidates: [a, b, c],
            currentSurfaceID: a,
            scope: scope,
            direction: .forward,
            requiredModifiers: 1
        ) == c)
        model.recordFocus(c)
        #expect(model.cycle(
            candidates: [a, b, c],
            currentSurfaceID: c,
            scope: scope,
            direction: .forward,
            requiredModifiers: 1
        ) == b)
    }

    @Test("Committing makes the surface being left the first candidate next time")
    func freshCycleReturnsToPreviousSurface() throws {
        let model = SurfaceCycleModel()
        model.recordFocus(a)
        model.recordFocus(b)
        model.recordFocus(c)
        model.recordFocus(a)

        #expect(model.cycle(
            candidates: [a, b, c],
            currentSurfaceID: a,
            scope: scope,
            direction: .forward,
            requiredModifiers: 1
        ) == c)
        #expect(model.commit() == c)
        #expect(model.cycle(
            candidates: [a, b, c],
            currentSurfaceID: c,
            scope: scope,
            direction: .forward,
            requiredModifiers: 1
        ) == a)
    }

    @Test("Forward and backward steps share one frozen ring")
    func reverseWithinActiveCycle() throws {
        let model = SurfaceCycleModel()
        model.recordFocus(c)
        model.recordFocus(b)
        model.recordFocus(a)

        #expect(model.cycle(
            candidates: [a, b, c],
            currentSurfaceID: a,
            scope: scope,
            direction: .forward,
            requiredModifiers: 1
        ) == b)
        #expect(model.cycle(
            candidates: [a, b, c],
            currentSurfaceID: b,
            scope: scope,
            direction: .forward,
            requiredModifiers: 1
        ) == c)
        #expect(model.cycle(
            candidates: [a, b, c],
            currentSurfaceID: c,
            scope: scope,
            direction: .backward,
            requiredModifiers: 1
        ) == b)
    }

    @Test("Never-focused surfaces remain reachable after remembered surfaces")
    func includesNeverFocusedCandidatesInTabOrder() {
        let model = SurfaceCycleModel()
        model.recordFocus(c)
        #expect(model.cycleOrder(candidates: [a, b, c]) == [c, a, b])
    }

    @Test("Cancelling restores the original without changing recency")
    func cancelPreservesLedger() throws {
        let model = SurfaceCycleModel()
        model.recordFocus(b)
        model.recordFocus(a)
        #expect(model.cycle(
            candidates: [a, b],
            currentSurfaceID: a,
            scope: scope,
            direction: .forward,
            requiredModifiers: 1
        ) == b)
        #expect(model.cancel() == a)
        #expect(model.cycleOrder(candidates: [a, b]) == [a, b])
    }
}
