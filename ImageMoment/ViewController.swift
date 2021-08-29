import UIKit
import AVFoundation

fileprivate struct Const {
    static let captureImageMargin = 16  // ２倍したときに３２の倍数にすること
    static let initialBinarizeThreshold: Float = 0.2
}

class ViewController: UIViewController {
    // UI
    @IBOutlet weak var glanceView: UIImageView!
    @IBOutlet weak var thresholdSlider: UISlider!
    @IBOutlet weak var thresholdLabel: UILabel!
    private weak var indicatorView: IndicatorView!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    // image capture
    lazy var imageCapture = ImageCapture()
    
    // compute image
    private var imageSize = 0
    private var momentCalculator: MomentCalculator!
    
    private let inFlightSemaphore = DispatchSemaphore(value: 1)
    
    // 二値化閾値
    var binarizeThreshold: Float = Const.initialBinarizeThreshold {
        didSet {
            thresholdLabel.text = String(format: "%.1f", binarizeThreshold)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        
        // 処理する画像のサイズ。モルフォロジー演算で四隅が黒くなるので、その領域を除く。
        imageSize = imageCapture.videoHeight - Const.captureImageMargin * 2    // 448(=480-32)
        momentCalculator = MomentCalculator(imageSize: imageSize)
        
        // キャプチャ開始
        imageCapture.delegate = self
        imageCapture.session.startRunning()
    }
    
    private func setupViews() {
        // 閾値スライダー
        thresholdSlider.value = Const.initialBinarizeThreshold
        binarizeThreshold = Const.initialBinarizeThreshold
        // プレビュー
        glanceView.contentMode = .scaleAspectFit
        // 物体の向きを指し示すビュー
        let indicatorView = IndicatorView()
        indicatorView.isHidden = true
        glanceView.addSubview(indicatorView)
        self.indicatorView = indicatorView
    }
    
    @IBAction func sliderDidChange(_ sender: UISlider) {
        let roundedValue = round(sender.value / 0.1) * 0.1
        sender.value = roundedValue
        binarizeThreshold = roundedValue
    }
}

extension ViewController: ImageCaptureDelegate {
    func captureOutput(ciimage: CIImage) {
        // ビデオ画像内のモーメント特徴の計算範囲
        let calculateFrame = CGRect(x: Const.captureImageMargin,
                                    y: Int(ciimage.extent.width/2) - Int(ciimage.extent.height/2) + Const.captureImageMargin,
                                    width: imageSize,
                                    height: imageSize)
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        // 右回転して向きを縦に直す
        let rotatedImage = ciimage.oriented(.right)
        // 二値化・モルフォロジー変換
        guard let binaryImage = rotatedImage.binarization(threshold: self.binarizeThreshold) else { return }
        // モルフォロジー演算で画像領域が拡大されるので元の位置のサイズを取得し直す
        // なお、モルフォロジー演算で画像の四隅が黒くなってしまうので、少し(32pix=SIMD threadの幅)内側の領域を取得する
        let croppedBinaryImage = binaryImage.cropped(to: calculateFrame)
        // モーメント特徴を計算
        let momentFeature = momentCalculator.perform(ciimage: croppedBinaryImage)
        // 画面表示用に入力画像と二値化画像を合成する
        let compositeImage = rotatedImage
            .cropped(to: calculateFrame)
            .minimumCompositing(ciimage: croppedBinaryImage)
        // 描画用にCGImageに変換しておく
        var cgImage: CGImage?
        if let compositeImage = compositeImage {
            let context = CIContext()
            cgImage = context.createCGImage(compositeImage, from: compositeImage.extent)
        }
        
        inFlightSemaphore.signal()
        
        DispatchQueue.main.async {
            // 画像を表示
            if let cgImage = cgImage {
                self.glanceView.image = UIImage(cgImage: cgImage)
            }
            // 重心を表示
            if momentFeature.centerGravityX > 0, momentFeature.centerGravityY > 0 {
                let x = CGFloat(momentFeature.centerGravityX) / CGFloat(self.imageSize) * self.glanceView.bounds.width
                let y = CGFloat(momentFeature.centerGravityY) / CGFloat(self.imageSize) * self.glanceView.bounds.height
                self.indicatorView.position =  CGPoint(x: x, y: y)
                self.indicatorView.isHidden = false
            } else {
                self.indicatorView.isHidden = true
            }
        }
    }
}
