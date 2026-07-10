import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(Color.pawOrange)
            Text("PawMatch")
                .font(.pawHeading(28))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    SplashView()
}
