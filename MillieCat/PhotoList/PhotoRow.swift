import Core_Domain

/// 목록의 한 줄입니다.
///
/// 줄이 좌우 스크롤을 각자 맡으므로, 줄 자체가 화면을 구성하는 단위가 됩니다.
/// 순서(몇 번째 줄인지)가 아니라 첫 칸의 id 를 줄의 id 로 씁니다.
/// 순서를 쓰면 뒤에 묶음이 붙을 때 같은 번호가 다른 줄을 가리키게 되어,
/// 화면이 줄을 다시 만들면서 이미 받아 둔 이미지를 놓칩니다.
struct PhotoRow: Identifiable {
    let photos: [Photo]

    var id: String { photos.first?.id ?? "" }

    static func make(from photos: [Photo], isLandscape: Bool) -> [PhotoRow] {
        GridLayoutSpec.rows(photos, isLandscape: isLandscape).map(PhotoRow.init)
    }
}
