import SwiftUI

struct ReviewGenerationDisclosureModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .alert(ReviewGenerationDisclosure.title, isPresented: $isPresented) {
                Button("Continue", role: .cancel) {}
            } message: {
                Text(ReviewGenerationDisclosure.message)
            }
    }
}

extension View {
    func reviewGenerationDisclosure(isPresented: Binding<Bool>) -> some View {
        modifier(ReviewGenerationDisclosureModifier(isPresented: isPresented))
    }
}
