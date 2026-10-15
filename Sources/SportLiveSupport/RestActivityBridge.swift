import ActivityKit

// The SDK's Activity reference is not Sendable. Keep it inside these nonisolated
// operations; only immutable records, content and IDs cross the coordinator boundary.
struct RestActivityRecord: Sendable {
  let id: String
  let attributes: RestActivityAttributes
  let contentState: RestActivityAttributes.ContentState
  let status: ActivityState
}

enum RestActivityBridge {
  static var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

  static func records() -> [RestActivityRecord] {
    Activity<RestActivityAttributes>.activities.map {
      RestActivityRecord(
        id: $0.id, attributes: $0.attributes, contentState: $0.content.state,
        status: $0.activityState)
    }
  }

  static func end(id: String) async {
    guard let activity = Activity<RestActivityAttributes>.activities.first(where: { $0.id == id })
    else {
      return
    }
    await activity.end(nil, dismissalPolicy: .immediate)
  }

  static func update(id: String, content: ActivityContent<RestActivityAttributes.ContentState>)
    async
  {
    guard let activity = Activity<RestActivityAttributes>.activities.first(where: { $0.id == id })
    else {
      return
    }
    await activity.update(content)
  }
}
