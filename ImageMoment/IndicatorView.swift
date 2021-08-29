import UIKit

fileprivate struct Const {
    static let size: CGFloat = 30
}

class IndicatorView: UIView {
    var position: CGPoint = .zero {
        didSet {
            transform = CGAffineTransform(translationX: position.x, y: position.y)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: -(Const.size / 2),
                                 y: -(Const.size / 2),
                                 width: Const.size,
                                 height: Const.size))
        backgroundColor = .red
        layer.cornerRadius = Const.size / 2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
