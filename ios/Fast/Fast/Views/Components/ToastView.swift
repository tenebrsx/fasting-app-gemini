import Observation
import SwiftUI

@MainActor
@Observable
final class ToastCenter {
    var message: String?
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String) {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            message = text
        }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                message = nil
            }
        }
    }
}

struct ToastOverlayModifier: ViewModifier {
    var toastCenter: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = toastCenter.message {
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.surface2, in: Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

extension View {
    func toastOverlay(_ toastCenter: ToastCenter) -> some View {
        modifier(ToastOverlayModifier(toastCenter: toastCenter))
    }
}

struct SyncStatusDot: View {
    let syncState: CloudSyncState

    var body: some View {
        Circle()
            .fill(syncState.isSynced ? Theme.ok : Theme.mist)
            .frame(width: 8, height: 8)
            .opacity(0.85)
            .accessibilityLabel(syncState.label)
    }
}
