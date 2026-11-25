import SwiftUI
import TonyPresentation
import TonyUIKit
import TonyUIModels

/// The sheet that explains a permission before the system asks for it. The permission manager shows and closes it.
public struct PermissionScreen: View {
    private let viewModel: PermissionViewModel

    public init(_ viewModel: PermissionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: TonySpacing.section) {
            ScrollView {
                PermissionExplanation(viewModel: viewModel)
                    .padding(.vertical, TonySpacing.section)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center, for: .alignment)
            PermissionActions(viewModel: viewModel)
        }
        .padding(.horizontal, TonySpacing.page)
        .padding(.bottom, TonySpacing.page)
        .background(TonyColor.canvas)
    }
}

private struct PermissionExplanation: View {
    let viewModel: PermissionViewModel

    var body: some View {
        VStack(spacing: TonySpacing.explanation) {
            Text(viewModel.title)
                .tonyText(.heading)
                .foregroundStyle(TonyColor.ink)
                .accessibilityAddTraits(.isHeader)
            IllustrationView(viewModel.illustration)
            Text(viewModel.explanation)
                .tonyText(.bodyLarge)
                .foregroundStyle(TonyColor.muted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

private struct PermissionActions: View {
    let viewModel: PermissionViewModel

    var body: some View {
        let grant = viewModel.grant
        let notNow = viewModel.notNow
        VStack(spacing: TonySpacing.small) {
            Button {
                grant.action.execute()
            } label: {
                Text(grant.title)
                    .tonyText(.labelLarge)
                    .foregroundStyle(TonyColor.onAccent)
                    .frame(maxWidth: .infinity, minHeight: TonySize.touchTarget)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .accessibilityIdentifier(ifPresent: grant.accessibilityIdentifier)
            Button {
                notNow.action.execute()
            } label: {
                Text(notNow.title)
                    .tonyText(.labelLarge)
                    .foregroundStyle(TonyColor.accent)
                    .frame(maxWidth: .infinity, minHeight: TonySize.touchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(ifPresent: notNow.accessibilityIdentifier)
        }
    }
}

#if DEBUG
#Preview("Permission, calendar") {
    PermissionScreen(.preview())
}

#Preview("Permission, calendar refused") {
    PermissionScreen(.preview(isRefused: true))
}

#Preview("Permission, largest text") {
    PermissionScreen(.preview())
        .dynamicTypeSize(.accessibility5)
}
#endif
