import Core_Domain
import SwiftUI

/// 이미지 한 장을 그립니다.
///
/// 불러오기는 `PhotoDataLoader` 에 맡깁니다. 저장된 것이 있으면 그것을 쓰고 없을 때만
/// 내려받는 판단은 그쪽에 있어서, 이 화면은 결과만 받아 그리면 됩니다.
struct PhotoCell: View {
    let photo: Photo
    let size: CGSize
    let loader: any PhotoDataLoader

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    // 칸은 가로로 길고(300×120) 이미지는 정사각형에 가까워서,
                    // 여백을 남기는 대신 채우고 잘라냅니다.
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(ProgressView())
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        // 칸 하나를 통째로 하나의 요소로 다룹니다.
        // 안쪽을 열어 두면 화면 자동화가 무엇을 눌러야 할지 특정하지 못합니다.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(AccessibilityID.photoCell)
        .task(id: photo.id) {
            await load()
        }
    }

    private func load() async {
        // 실패해도 자리만 비워 둡니다. 한 장이 안 보이는 것으로 목록 전체를
        // 실패 화면으로 바꾸는 것은 과합니다.
        guard let data = try? await loader.data(for: photo.url) else { return }
        image = UIImage(data: data)
    }
}
