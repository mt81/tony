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
        NavigationStack {
            VStack(spacing: TonySpacing.section) {
                ScrollView {
                    PermissionExplanation(viewModel: viewModel)
                        .padding(.vertical, TonySpacing.section)
                }
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.center, for: .alignment)
                PermissionButton(viewModel: viewModel)
            }
            .padding(.horizontal, TonySpacing.page)
            .padding(.bottom, TonySpacing.page)
            .background(TonyColor.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    PermissionClose(viewModel: viewModel)
                }
            }
        }
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

private struct PermissionButton: View {
    let viewModel: PermissionViewModel

    var body: some View {
        let grant = viewModel.grant
        Button {
            grant.action.execute()
        } label: {
            Text(grant.title)
                .tonyText(.labelLarge)
                .foregroundStyle(TonyColor.onCta)
                .frame(maxWidth: .infinity, minHeight: TonySize.touchTarget)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(TonyColor.cta)
        .accessibilityIdentifier(ifPresent: grant.accessibilityIdentifier)
    }
}

private struct PermissionClose: View {
    let viewModel: PermissionViewModel

    var body: some View {
        ButtonView(viewModel.close)
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
