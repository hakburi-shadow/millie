import Core_Domain
import SwiftUI

struct PhotoListView<Repository: PhotoRepository>: View {
    @StateObject private var store: PhotoListStore<Repository>
    private let loader: any PhotoDataLoader

    init(repository: Repository, loader: any PhotoDataLoader) {
        _store = StateObject(wrappedValue: PhotoListStore(repository: repository))
        self.loader = loader
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = GridLayoutSpec.isLandscape(containerSize: proxy.size)

            ScrollView(isLandscape ? [.horizontal, .vertical] : .vertical) {
                grid(isLandscape: isLandscape, containerWidth: proxy.size.width)
            }
            .overlay(alignment: .top) { statusBanner }
            .overlay { emptyState }
        }
        .task { store.send(.onAppear) }
    }

    private func grid(isLandscape: Bool, containerWidth: CGFloat) -> some View {
        let cellSize = GridLayoutSpec.cellSize(isLandscape: isLandscape, containerWidth: containerWidth)
        let columns = Array(
            repeating: GridItem(.fixed(cellSize.width), spacing: GridLayoutSpec.spacing),
            count: GridLayoutSpec.columnCount(isLandscape: isLandscape)
        )

        return LazyVGrid(columns: columns, spacing: GridLayoutSpec.spacing) {
            ForEach(store.state.photos) { photo in
                PhotoCell(photo: photo, size: cellSize, loader: loader)
                    .onAppear { loadMoreIfNeeded(after: photo) }
            }
        }
        // 가로일 때는 5칸 × 300 이 화면 폭을 넘으므로, 화면에 맞추지 않고
        // 격자 본래 너비를 그대로 두어 좌우로도 스크롤되게 합니다.
        .frame(width: GridLayoutSpec.contentWidth(isLandscape: isLandscape, containerWidth: containerWidth))
        .padding(.vertical, GridLayoutSpec.spacing)
    }

    /// 마지막 칸이 보이면 다음 묶음을 요청합니다.
    ///
    /// 겹쳐 나가는 것을 막는 판단은 `Store` 에 있으므로 여기서는 신호만 보냅니다.
    private func loadMoreIfNeeded(after photo: Photo) {
        guard photo.id == store.state.photos.last?.id else { return }
        store.send(.reachedBottom)
    }

    /// 저장된 데이터를 보고 있거나 실패했을 때 위쪽에 띄우는 안내입니다.
    @ViewBuilder
    private var statusBanner: some View {
        if case .failed(let error) = store.state.phase, !store.state.isEmpty {
            banner(text: error.message, showsRetry: error.isRecoverableByRetry)
        } else if store.state.source == .cache, !store.state.isEmpty {
            banner(text: "연결이 없어 저장된 이미지를 보여주고 있어요.", showsRetry: true)
        }
    }

    private func banner(text: String, showsRetry: Bool) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsRetry {
                Button("다시 시도") { store.send(.retry) }
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    /// 보여줄 것이 하나도 없을 때만 화면 전체를 차지합니다.
    @ViewBuilder
    private var emptyState: some View {
        if store.state.isEmpty {
            switch store.state.phase {
            case .loading:
                ProgressView()
            case .failed(let error):
                VStack(spacing: 12) {
                    Text(error.message)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    if error.isRecoverableByRetry {
                        Button("다시 시도") { store.send(.retry) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(32)
            default:
                EmptyView()
            }
        }
    }
}
