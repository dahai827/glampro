import Foundation
import UIKit
import FacebookCore
import AppTrackingTransparency

@MainActor
final class FacebookAnalyticsService {
    static let shared = FacebookAnalyticsService()

    private let fallbackFacebookAppID = "1261567822843388"
    private let fallbackFacebookClientToken = "7f8164762043d79e0107d264ad591677"
    private let facebookAppIDKey = "FacebookAppID"
    private let facebookClientTokenKey = "FacebookClientToken"
    private let registrationPendingUserIDsKey = "facebook.completedRegistration.pendingUserIDs"
    private let registrationLoggedUserIDsKey = "facebook.completedRegistration.loggedUserIDs"
    private let userDefaults: UserDefaults
    private(set) var isInitialized = false

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func initializeIfNeeded() {
        guard !isInitialized else { return }

        applyFacebookConfigurationFromBundleIfNeeded()
        enableDebugLoggingIfNeeded()
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
        updateATTStatus()
        isInitialized = true
        flushPendingRegistrationEvents()
        let configuredAppID = Settings.shared.appID ?? "<nil>"
        let hasClientToken = !(Settings.shared.clientToken ?? "").isEmpty
        print("[Facebook] SDK initialized, appID=\(configuredAppID), clientToken=\(hasClientToken ? "present" : "missing")")
    }

    func updateATTStatus() {
        let status = ATTrackingManager.trackingAuthorizationStatus
        let isAuthorized = status == .authorized

        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = isAuthorized
        Settings.shared.isAdvertiserTrackingEnabled = isAuthorized

        print("[Facebook] ATT status: \(status.rawValue), advertiser id collection enabled: \(isAuthorized)")
    }

    func activateAppAfterTrackingBoundaryResolved() {
        guard isInitialized else { return }
        AppEvents.shared.activateApp()
        AppEvents.shared.flush()
        print("[Facebook] activateApp + flush (reason=app_active)")
    }

    func logCompleteRegistrationOnce(userID: String?) {
        guard let userID, !userID.isEmpty else { return }

        var loggedUserIDs = Set(userDefaults.stringArray(forKey: registrationLoggedUserIDsKey) ?? [])
        guard !loggedUserIDs.contains(userID) else { return }

        guard isInitialized else {
            var pendingUserIDs = Set(userDefaults.stringArray(forKey: registrationPendingUserIDsKey) ?? [])
            pendingUserIDs.insert(userID)
            userDefaults.set(Array(pendingUserIDs), forKey: registrationPendingUserIDsKey)
            print("[Facebook] queue CompleteRegistration (sdk_not_initialized), user=\(userID)")
            return
        }

        AppEvents.shared.logEvent(.completedRegistration)
        loggedUserIDs.insert(userID)
        userDefaults.set(Array(loggedUserIDs), forKey: registrationLoggedUserIDsKey)
        print("[Facebook] logged event=CompleteRegistration, user=\(userID)")
        AppEvents.shared.flush()
        print("[Facebook] flush (reason=complete_registration)")
    }

    private func flushPendingRegistrationEvents() {
        let pendingUserIDs = Set(userDefaults.stringArray(forKey: registrationPendingUserIDsKey) ?? [])
        guard !pendingUserIDs.isEmpty else { return }

        var loggedUserIDs = Set(userDefaults.stringArray(forKey: registrationLoggedUserIDsKey) ?? [])

        for userID in pendingUserIDs where !loggedUserIDs.contains(userID) {
            AppEvents.shared.logEvent(.completedRegistration)
            loggedUserIDs.insert(userID)
            print("[Facebook] flushed pending event=CompleteRegistration, user=\(userID)")
        }

        userDefaults.set(Array(loggedUserIDs), forKey: registrationLoggedUserIDsKey)
        userDefaults.removeObject(forKey: registrationPendingUserIDsKey)
        if !pendingUserIDs.isEmpty {
            AppEvents.shared.flush()
            print("[Facebook] flush (reason=pending_complete_registration, count=\(pendingUserIDs.count))")
        }
    }

    func logSubscribe(planID: String, value: Double?, currency: String = "USD") {
        guard isInitialized else { return }

        var parameters: [AppEvents.ParameterName: Any] = [
            .contentID: planID,
            .currency: currency
        ]
        if value == nil {
            parameters[.description] = "subscription"
        }

        if let value {
            AppEvents.shared.logEvent(AppEvents.Name("Subscribe"), valueToSum: value, parameters: parameters)
        } else {
            AppEvents.shared.logEvent(AppEvents.Name("Subscribe"), parameters: parameters)
        }
        AppEvents.shared.flush()
        print("[Facebook] logged event=Subscribe, planID=\(planID), value=\(value?.description ?? "nil"), currency=\(currency), params=\(parameters)")
        print("[Facebook] flush (reason=subscribe)")
    }

    private func applyFacebookConfigurationFromBundleIfNeeded() {
        let bundleAppID = stringValue(forInfoDictionaryKey: facebookAppIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleClientToken = stringValue(forInfoDictionaryKey: facebookClientTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedAppID = (bundleAppID?.isEmpty == false ? bundleAppID : nil) ?? fallbackFacebookAppID
        let resolvedClientToken = (bundleClientToken?.isEmpty == false ? bundleClientToken : nil) ?? fallbackFacebookClientToken

        Settings.shared.appID = resolvedAppID
        Settings.shared.clientToken = resolvedClientToken

        print(
            "[Facebook] config from bundle, appID=\(Settings.shared.appID ?? "<nil>"), clientToken=\((Settings.shared.clientToken ?? "").isEmpty ? "missing" : "present")"
        )
    }

    private func stringValue(forInfoDictionaryKey key: String) -> String? {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key)
        if let stringValue = rawValue as? String {
            return stringValue
        }
        if let numberValue = rawValue as? NSNumber {
            return numberValue.stringValue
        }
        return nil
    }

    private func enableDebugLoggingIfNeeded() {
#if DEBUG
        Settings.shared.enableLoggingBehavior(.appEvents)
        Settings.shared.enableLoggingBehavior(.networkRequests)
        Settings.shared.enableLoggingBehavior(.developerErrors)
        Settings.shared.enableLoggingBehavior(.informational)
        print("[Facebook] debug logging enabled (appEvents, networkRequests, developerErrors, informational)")
#endif
    }
}
