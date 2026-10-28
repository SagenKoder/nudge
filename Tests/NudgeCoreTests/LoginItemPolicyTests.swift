import Testing
@testable import NudgeCore

@Suite struct LoginItemPolicyTests {
    @Test func readdsTheItemWhenAReinstallRemovedIt() {
        #expect(LoginItemPolicy.shouldRegister(wantsStartAtLogin: true, status: .notRegistered))
        #expect(LoginItemPolicy.shouldRegister(wantsStartAtLogin: true, status: .notFound))
    }

    @Test func leavesAnExistingItemAlone() {
        #expect(!LoginItemPolicy.shouldRegister(wantsStartAtLogin: true, status: .enabled))
    }

    @Test func respectsTheUserSwitchingItOffInSystemSettings() {
        #expect(!LoginItemPolicy.shouldRegister(wantsStartAtLogin: true, status: .requiresApproval))
    }

    @Test func neverRegistersWhenTheUserTurnedItOffInNudge() {
        for status in [LoginItemPolicy.Status.notRegistered, .notFound, .enabled, .requiresApproval] {
            #expect(!LoginItemPolicy.shouldRegister(wantsStartAtLogin: false, status: status))
        }
    }
}
