/// Tony's logic: domain model, cadence, context builder, planner, consistency
/// and the protocols that system frameworks sit behind.
///
/// This package must not import UIKit, SwiftUI, EventKit or HealthKit
/// (`make check-imports` enforces it).
public enum TonyCore {
    /// App group shared by the app and the widget extension.
    public static let appGroupIdentifier = "group.com.mt81.tony"
}
