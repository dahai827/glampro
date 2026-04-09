import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var savedTemplatesStore: SavedTemplatesStore

    let openProfile: () -> Void
    let openPreview: () -> Void

    @State private var selectedCategory: FeedCategory = .popular

    var body: some View {
        ScreenContainer(showBrand: false, topSpacing: 18, bottomSpacing: 84) {
            CalmTheme.background
        } content: {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    feedColumns
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CircleIconButton(icon: "plus", action: {})

            HStack(spacing: 18) {
                ForEach(FeedCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 8) {
                            Text(category.rawValue)
                                .font(.calm(16, weight: .heavy))
                                .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.56))
                            Capsule()
                                .fill(selectedCategory == category ? Color.white : Color.clear)
                                .frame(width: 24, height: 2.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            CircleIconButton(icon: "person.fill", action: openProfile)
        }
    }

    private var feedColumns: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(spacing: 16) {
                ForEach(leftColumnItems) { item in
                    feedCard(item)
                }
            }

            VStack(spacing: 16) {
                ForEach(rightColumnItems) { item in
                    feedCard(item)
                }
            }
        }
        .padding(.bottom, 100)
    }

    private func feedCard(_ item: FeedCardModel) -> some View {
        let savedItem = SavedTemplateItem(mockFeedCard: item)

        return ZStack(alignment: .topTrailing) {
            Button(action: openPreview) {
                VStack(alignment: .leading, spacing: 7) {
                    PlaceholderArtwork(paletteIndex: item.paletteIndex, cornerRadius: 16)
                        .frame(height: item.height)
                        .overlay(alignment: .bottomLeading) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.22))
                                    .frame(width: 28, height: 28)
                                HStack(spacing: 1) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Image(systemName: "plus")
                                        .font(.system(size: 7, weight: .heavy))
                                }
                                .foregroundColor(.white)
                            }
                            .padding(8)
                        }

                    Text(item.title)
                        .font(.calm(14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Text(item.author)
                            .font(.calm(12, weight: .medium))
                            .foregroundColor(CalmTheme.secondaryText)
                        Spacer()
                        Image(systemName: "heart")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.88))
                        Text("\(item.likes)")
                            .font(.calm(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                savedTemplatesStore.toggle(savedItem)
            } label: {
                Image(systemName: savedTemplatesStore.isSaved(savedItem) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
            }
            .buttonStyle(.plain)
        }
    }

    private var leftColumnItems: [FeedCardModel] {
        MockData.feedCards.enumerated().compactMap { index, item in
            index.isMultiple(of: 2) ? item : nil
        }
    }

    private var rightColumnItems: [FeedCardModel] {
        MockData.feedCards.enumerated().compactMap { index, item in
            index.isMultiple(of: 2) ? nil : item
        }
    }
}
