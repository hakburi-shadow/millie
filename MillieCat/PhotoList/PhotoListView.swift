import Combine
import Core_Domain
import SwiftUI

struct PhotoListView<Repository: PhotoRepository>: View {
    @StateObject private var store: PhotoListStore<Repository>
    private let loader: any PhotoDataLoader

    /// 고른 칸입니다. 값이 있으면 상세 화면이 올라옵니다.
    @State private var selected: Photo?

    init(
        repository: Repository,
        loader: any PhotoDataLoader,
        isOnline: AnyPublisher<Bool, Never>? = nil
    ) {
        _store = StateObject(
            wrappedValue: PhotoListStore(repository: repository, isOnline: isOnline)
        )
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
        .fullScreenCover(item: $selected) { photo in
            ImageDetailScreen(photo: photo, loader: loader) { selected = nil }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func rowView(_ row: PhotoRow, isLandscape: Bool, containerWidth: CGFloat) -> some View {
        let cellSize = GridLayoutSpec.cellSize(isLandscape: isLandscape, containerWidth: containerWidth)

        if isLandscape {
            // 한 줄은 5칸 × 300 이라 화면 폭을 넘습니다. 줄마다 좌우로 넘겨 봅니다.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GridLayoutSpec.spacing) {
                    cells(of: row, size: cellSize)
                }
            }
            .frame(height: cellSize.height)
        } else {
            // 세로에서는 한 줄이 곧 한 칸이라 넘길 것이 없습니다.
            cells(of: row, size: cellSize)
        }
    }

    /// 칸을 만드는 곳은 한 군데뿐입니다.
    /// 방향마다 따로 만들면 한쪽에만 손이 닿아 동작이 갈립니다.
    private func cells(of row: PhotoRow, size: CGSize) -> some View {
        ForEach(row.photos) { photo in
            PhotoCell(photo: photo, size: size, loader: loader)
                .onTapGesture { selected = photo }
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
    ///
    /// **보여줄 것이 있을 때만 나옵니다.** 아무것도 없을 때는 `emptyState` 가 화면 전체를 씁니다.
    /// 그래서 두 갈래 모두 `fallbackMessage` 를 씁니다 — 화면에 이미지가 있는 상황이므로
    /// "아무것도 없다"고 말하는 문구가 여기 올 일은 없어야 합니다.
    /// 지금은 `.failed` 로 여기까지 오는 것이 저장소 실패뿐이지만, 그 사실에 기대지 않고
    /// 문구 쪽에서 막습니다. 도달 불가에 기댄 판단은 조건이 바뀌면 조용히 틀립니다.
    @ViewBuilder
    private var statusBanner: some View {
        if !store.state.isEmpty {
            if case .failed(let error) = store.state.phase {
                banner(text: error.fallbackMessage, showsRetry: error.isRecoverableByRetry)
            } else if let reason = store.state.source.fallbackReason {
                // 무엇 때문에 대체했는지는 `source` 가 나릅니다.
                // 여기서 원인을 짐작하면, 429 를 두고 "연결이 없다"고 말하게 됩니다.
                banner(text: reason.fallbackMessage, showsRetry: reason.isRecoverableByRetry)
            }
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
