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

    @Test("An explicit focus outside the preview ends the held cycle")
    func explicitFocusInterruptsCycle() throws {
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
        model.recordFocus(c)
        #expect(!model.hasActiveSession)
        #expect(model.cycleOrder(candidates: [a, b, c]) == [c, a, b])
    }

    @Test("Interrupting abandons a preview without changing remembered order")
    func interruptAbandonsPreview() throws {
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

        model.interrupt()

        #expect(!model.hasActiveSession)
        #expect(model.cycleOrder(candidates: [a, b, c]) == [a, b, c])
    }

    @Test("Forgetting a closed surface removes it from remembered order")
    func forgetClosedSurface() {
        let model = SurfaceCycleModel()
        model.recordFocus(a)
        model.recordFocus(b)
        model.forget(b)
        #expect(model.cycleOrder(candidates: [a, b, c]) == [a, b, c])
    }

    @Test("Modifier release previews once and then fully activates the selection")
    func modifierReleaseCommitsPreview() throws {
        let host = TestSurfaceCycleHost(scope: scope, candidates: [a, b], current: a)
        host.surfaceCycleModel.recordFocus(b)
        host.surfaceCycleModel.recordFocus(a)

        #expect(host.performSurfaceCycle(direction: .forward, requiredModifiers: 1))
        #expect(host.selections == [.init(surfaceID: b, isPreview: true)])
        #expect(!host.finishSurfaceCycleIfModifiersReleased(1))
        #expect(host.finishSurfaceCycleIfModifiersReleased(0))
        #expect(host.selections == [
            .init(surfaceID: b, isPreview: true),
            .init(surfaceID: b, isPreview: false),
        ])
        #expect(!host.surfaceCycleModel.hasActiveSession)
    }

    @Test("Closing the previewed surface reconciles before commit")
    func closeDuringCycleReconcilesSelection() throws {
        let host = TestSurfaceCycleHost(scope: scope, candidates: [a, b, c], current: a)
        host.surfaceCycleModel.recordFocus(c)
        host.surfaceCycleModel.recordFocus(b)
        host.surfaceCycleModel.recordFocus(a)

        #expect(host.performSurfaceCycle(direction: .forward, requiredModifiers: 1))
        #expect(host.currentSurfaceCycleSurfaceID == b)
        host.candidates.removeAll { $0 == b }
        host.surfaceCycleModel.forget(b)
        host.commitSurfaceCycle()

        #expect(host.selections.last == .init(surfaceID: c, isPreview: false))
        #expect(!host.surfaceCycleModel.hasActiveSession)
    }
}

@MainActor
private final class TestSurfaceCycleHost: SurfaceCycleHosting {
    struct Selection: Equatable {
        let surfaceID: UUID
        let isPreview: Bool
    }

    let surfaceCycleModel = SurfaceCycleModel()
    let scope: SurfaceCycleScope
    var candidates: [UUID]
    var current: UUID
    var selections: [Selection] = []

    init(scope: SurfaceCycleScope, candidates: [UUID], current: UUID) {
        self.scope = scope
        self.candidates = candidates
        self.current = current
    }

    var currentSurfaceCycleScope: SurfaceCycleScope? { scope }
    var currentSurfaceCycleSurfaceID: UUID? { current }

    func surfaceCycleCandidates(in scope: SurfaceCycleScope) -> [UUID] {
        scope == self.scope ? candidates : []
    }

    func selectSurfaceForCycle(_ surfaceID: UUID, in scope: SurfaceCycleScope, isPreview: Bool) {
        current = surfaceID
        selections.append(.init(surfaceID: surfaceID, isPreview: isPreview))
        surfaceCycleModel.recordFocus(surfaceID)
    }
}
