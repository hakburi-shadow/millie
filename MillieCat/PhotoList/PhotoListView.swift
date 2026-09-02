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
            let rows = PhotoRow.make(from: store.state.photos, isLandscape: isLandscape)

            // 바깥은 위아래로만 움직입니다. 좌우는 줄이 각자 맡습니다.
            // 목록 전체가 대각선으로 움직이면 아래로 내리는 동안 좌우 위치까지
            // 함께 밀려서, 보던 자리를 놓치기 쉽습니다.
            ScrollView(.vertical) {
                LazyVStack(spacing: GridLayoutSpec.spacing) {
                    ForEach(rows) { row in
                        rowView(row, isLandscape: isLandscape, containerWidth: proxy.size.width)
                            .onAppear { loadMoreIfNeeded(after: row, in: rows) }
                    }
                }
                .padding(.vertical, GridLayoutSpec.spacing)
            }
            .overlay(alignment: .top) { statusBanner }
            .overlay { emptyState }
        }
        .task { store.send(.onAppear) }
    }

    @ViewBuilder
    private func rowView(_ row: PhotoRow, isLandscape: Bool, containerWidth: CGFloat) -> some View {
        let cellSize = GridLayoutSpec.cellSize(isLandscape: isLandscape, containerWidth: containerWidth)

        if isLandscape {
            // 한 줄은 5칸 × 300 이라 화면 폭을 넘습니다. 줄마다 좌우로 넘겨 봅니다.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GridLayoutSpec.spacing) {
                    ForEach(row.photos) { photo in
                        PhotoCell(photo: photo, size: cellSize, loader: loader)
                    }
                }
            }
            .frame(height: cellSize.height)
        } else {
            // 세로에서는 한 줄이 곧 한 칸이라 넘길 것이 없습니다.
            ForEach(row.photos) { photo in
                PhotoCell(photo: photo, size: cellSize, loader: loader)
            }
        }
    }

    /// 마지막 줄이 보이면 다음 묶음을 요청합니다.
    ///
    /// 칸이 아니라 줄을 기준으로 봅니다. 가로에서는 줄의 마지막 칸이 화면 밖에 있어서,
    /// 칸을 기준으로 하면 좌우로 끝까지 넘기기 전에는 다음 묶음을 부르지 못합니다.
    ///
    /// 겹쳐 나가는 것을 막는 판단은 `Store` 에 있으므로 여기서는 신호만 보냅니다.
    private func loadMoreIfNeeded(after row: PhotoRow, in rows: [PhotoRow]) {
        guard row.id == rows.last?.id else { return }
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
