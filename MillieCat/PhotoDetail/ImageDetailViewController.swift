import Core_Domain
import UIKit

/// 이미지 한 장을 크게 보는 화면입니다.
///
/// 목록은 SwiftUI 로, 이 화면은 UIKit 으로 만들었습니다.
/// 확대·축소는 `UIScrollView` 가 이미 가지고 있는 기능이라, 배율 범위만 정해 주면 됩니다.
final class ImageDetailViewController: UIViewController {
    private let photo: Photo
    private let loader: any PhotoDataLoader
    private let onClose: () -> Void

    let scrollView = UIScrollView()
    let imageView = UIImageView()
    private let indicator = UIActivityIndicatorView(style: .medium)

    /// 화면 크기가 바뀌었는지 판단하는 기준입니다.
    /// 매 배치마다 다시 맞추면 확대해 둔 상태가 풀려 버립니다.
    private var lastLayoutSize: CGSize = .zero

    init(photo: Photo, loader: any PhotoDataLoader, onClose: @escaping () -> Void) {
        self.photo = photo
        self.loader = loader
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        configureHierarchy()
        loadImage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let size = scrollView.bounds.size
        guard size != lastLayoutSize, size != .zero else { return }
        lastLayoutSize = size

        // 화면 크기가 바뀌면 확대는 풀고 다시 화면에 맞춥니다.
        // 회전 전의 배율과 위치를 그대로 두면 엉뚱한 곳을 보게 됩니다.
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        imageView.frame = CGRect(origin: .zero, size: size)
        scrollView.contentSize = size
    }

    private func configureNavigationItem() {
        // 네비게이션 바 가운데에 이미지 id 를 둡니다.
        navigationItem.title = photo.id
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "뒤로",
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
    }

    private func configureHierarchy() {
        view.backgroundColor = .systemBackground

        imageView.contentMode = .scaleAspectFit

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        // 확대는 3배까지입니다.
        scrollView.maximumZoomScale = 3
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.addSubview(imageView)

        // 네비게이션 바가 불투명해서 이 화면의 영역은 이미 바 아래에서 시작합니다.
        // 그래서 이미지는 바를 뺀 나머지 전부를 차지합니다.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        view.addSubview(indicator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func loadImage() {
        indicator.startAnimating()

        Task { [photo, loader] in
            defer { indicator.stopAnimating() }
            // 목록에서 이미 받아 둔 이미지라면 저장된 것을 그대로 씁니다.
            guard let data = try? await loader.data(for: photo.url) else { return }
            imageView.image = UIImage(data: data)
        }
    }

    @objc
    private func closeTapped() {
        onClose()
    }
}

extension ImageDetailViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}
