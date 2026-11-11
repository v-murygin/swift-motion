import SwiftUI

struct User {
    var name: String
    var email: String
    var avatarURL: URL?
    var followers: Int
    var bio: String?
}

struct ProfileHeaderView: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name).font(.title2.bold())
                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                Text(user.bio!).font(.footnote)
            }

            Spacer()

            VStack {
                Text("\(user.followers)").font(.headline)
                Text("followers").font(.caption)
            }
            .frame(width: 70)
        }
        .padding()
    }
}

#Preview {
    ProfileHeaderView(user: User(name: "Anna Smith", email: "anna@mail.com", avatarURL: nil, followers: 120, bio: "iOS developer"))
}
