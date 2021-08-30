import UIKit
import CoreImage.CIFilterBuiltins

fileprivate struct Const {
    static let morphologyFilterRadius: Float = 10
}

extension CIImage {
    /// 二値化を行う。ノイズを抑えるため二値化後にモルフォロジー変換も行う。
    /// - Parameter threshold: 二値化の閾値
    /// - Returns: 二値画像
    func binarization(threshold: Float) -> CIImage? {
        // グレースケールに変換
        let grayscaleFilter = CIFilter.maximumComponent()
        grayscaleFilter.inputImage = self
        guard let grayscaleImage = grayscaleFilter.outputImage else { return nil }

        // 撮影画像を二値化
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = grayscaleImage
        thresholdFilter.threshold = threshold
        guard let thresholdImage = thresholdFilter.outputImage else { return nil }
        
        // 膨張・収縮処理（クロージング）
        let closingDilateFilter = CIFilter.morphologyMinimum()
        closingDilateFilter.inputImage = thresholdImage
        closingDilateFilter.radius = Const.morphologyFilterRadius
        guard let closingDilateImage = closingDilateFilter.outputImage else { return nil }

        let closingErodeFilter = CIFilter.morphologyMaximum()
        closingErodeFilter.inputImage = closingDilateImage
        closingErodeFilter.radius = Const.morphologyFilterRadius
        guard let closingErodeImage = closingErodeFilter.outputImage else { return nil }
        
        return closingErodeImage
        
        // 収縮・膨張処理（オープニング）
//        let openingErodeFilter = CIFilter.morphologyMaximum()
//        openingErodeFilter.inputImage = closingErodeImage
//        openingErodeFilter.radius = Const.morphologyFilterRadius
//        guard let openingErodeImage = openingErodeFilter.outputImage else { return nil }
//
//        let openingDilateFilter = CIFilter.morphologyMinimum()
//        openingDilateFilter.inputImage = openingErodeImage
//        openingDilateFilter.radius = Const.morphologyFilterRadius
//        guard let openingDilateImage = openingDilateFilter.outputImage else { return nil }
//
//        return openingDilateImage
    }
    
    /// 自身と引数の画像の暗い画素値で画像を合成する。
    /// - Parameter ciimage: 合成する画像
    /// - Returns: 合成画像
    func minimumCompositing(ciimage: CIImage) -> CIImage? {
        guard let composeFilter = CIFilter(name: "CIMinimumCompositing") else { return nil }
        composeFilter.setValue(self, forKey: kCIInputImageKey)
        composeFilter.setValue(ciimage, forKey: kCIInputBackgroundImageKey)
        return composeFilter.outputImage
    }
}
