import Foundation
import UIKit
import FacebookCore
import AppTrackingTransparency

@MainActor
final class FacebookAnalyticsService {
    static let shared = FacebookAnalyticsService()

    private let registrationPendingUserIDsKey = "facebook.completedRegistration.pendingUserIDs"
    private let registrationLoggedUserIDsKey = "facebook.completedRegistration.loggedUserIDs"
    private let userDefaults: UserDefaults
    private(set) var isInitialized = false

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func initializeIfNeeded() {
        guard !isInitialized else { return }

        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
        updateATTStatus()
        isInitialized = true
        flushPendingRegistrationEvents()
        print("[Facebook] SDK initialized")
    }

    func updateATTStatus() {
        let status = ATTrackingManager.trackingAuthorizationStatus
        let isAuthorized = status == .authorized

        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = isAuthorized

        print("[Facebook] ATT status: \(status.rawValue), advertiser id collection enabled: \(isAuthorized)")
    }

    func activateAppAfterTrackingBoundaryResolved() {
        guard isInitialized else { return }
        AppEvents.shared.activateApp()
    }

    func logCompleteRegistrationOnce(userID: String?) {
        guard let userID, !userID.isEmpty else { return }

        var loggedUserIDs = Set(userDefaults.stringArray(forKey: registrationLoggedUserIDsKey) ?? [])
        guard !loggedUserIDs.contains(userID) else { return }

        guard isInitialized else {
            var pendingUserIDs = Set(userDefaults.stringArray(forKey: registrationPendingUserIDsKey) ?? [])
            pendingUserIDs.insert(userID)
            userDefaults.set(Array(pendingUserIDs), forKey: registrationPendingUserIDsKey)
            return
        }

        AppEvents.shared.logEvent(.completedRegistration)
        loggedUserIDs.insert(userID)
        userDefaults.set(Array(loggedUserIDs), forKey: registrationLoggedUserIDsKey)
        print("[Facebook] logged CompleteRegistration for user: \(userID)")
    }

    private func flushPendingRegistrationEvents() {
        let pendingUserIDs = Set(userDefaults.stringArray(forKey: registrationPendingUserIDsKey) ?? [])
        guard !pendingUserIDs.isEmpty else { return }

        var loggedUserIDs = Set(userDefaults.stringArray(forKey: registrationLoggedUserIDsKey) ?? [])

        for userID in pendingUserIDs where !loggedUserIDs.contains(userID) {
            AppEvents.shared.logEvent(.completedRegistration)
            loggedUserIDs.insert(userID)
            print("[Facebook] flushed pending CompleteRegistration for user: \(userID)")
        }

        userDefaults.set(Array(loggedUserIDs), forKey: registrationLoggedUserIDsKey)
        userDefaults.removeObject(forKey: registrationPendingUserIDsKey)
    }
}
