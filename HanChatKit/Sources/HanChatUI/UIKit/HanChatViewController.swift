import UIKit
import SwiftUI

/// UIKit 호스트 앱용 래퍼. 이 뷰컨트롤러 하나만 present/push 하면 된다.
///
/// ```swift
/// let chatVC = HanChatViewController()
/// navigationController?.pushViewController(chatVC, animated: true)
/// ```
public final class HanChatViewController: UIViewController {

    private var hostingController: UIHostingController<HanChatRootView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        let hosting = UIHostingController(rootView: HanChatRootView())
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }
}
