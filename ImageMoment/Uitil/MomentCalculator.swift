import UIKit
import Metal
import MetalKit

fileprivate struct Const {
    static let simdGroupSize = 32
}

class MomentCalculator {
    struct Result {
        var centerGravityX: Int
        var centerGravityY: Int
    }
    
    // metal
    private let device = MTLCreateSystemDefaultDevice()!
    private lazy var commandQueue = device.makeCommandQueue()!
    private lazy var textureLoader = MTKTextureLoader(device: device)
    
    private var binarizedTexture: MTLTexture!
    private var momentElementsBuffer: MTLBuffer!
    private var momentElements: UnsafeBufferPointer<MomentElement>!
    private var momentComputeState: MTLComputePipelineState!
    private var threadsPerThreadgroup: MTLSize!
    private var threadsPerGrid: MTLSize!
    
    // image size
    let imageSize: Int
    
    var runnable = false
    
    /// Metalの初期化をする
    /// - Parameters:
    ///   - imageSize: 処理する画像の幅
    ///   - imageHeight: 処理する画像の高さ
    init(imageSize: Int) {
        self.imageSize = imageSize
        
        setupMetal()
    }
    
    /// モーメント特徴を計算する
    /// - Parameter ciimage: 処理対象の画像。二値化されていること。
    /// - Returns: 重心（x,y）
    func perform(ciimage: CIImage) -> Result? {
        guard runnable else { return nil }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let context = CIContext(mtlDevice: device)
        context.render(ciimage,
                       to: binarizedTexture,
                       commandBuffer: commandBuffer,
                       bounds: ciimage.extent,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(self.momentComputeState)
        computeEncoder.setTexture(self.binarizedTexture, index: 0)
        computeEncoder.setBuffer(self.momentElementsBuffer, offset: 0, index: 1)
        computeEncoder.dispatchThreads(self.threadsPerGrid, threadsPerThreadgroup: self.threadsPerThreadgroup)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        var m00 = 0
        var m10 = 0
        var m01 = 0
        for element in self.momentElements {
            m00 += Int(element.m00)
            m10 += Int(element.m10)
            m01 += Int(element.m01)
        }
        var centerGravityX = 0
        var centerGravityY = 0
        if m00 != 0 {
            // 重心
            centerGravityX = m10 / m00
            centerGravityY = m01 / m00
            // CIImageはy軸反転しているので元に戻す
            centerGravityY = imageSize - centerGravityY
        }
        
        return Result(centerGravityX: centerGravityX,
                      centerGravityY: centerGravityY)
    }
}

private extension MomentCalculator { 
    private func setupMetal() {
        if device.supportsFamily(.apple7) {
            runnable = true
        } else {
            // SIMD-scoped reduction operations に対応していない機種
            print("モーメントの計算処理はA14以降の機種でお試しください")
            return
        }

        // モーメント計算コンピュートシェーダー
        let defaultLibrary = device.makeDefaultLibrary()!
        let shader = defaultLibrary.makeFunction(name: "group_max")!
        momentComputeState = try! self.device.makeComputePipelineState(function: shader)
        
        // スレッドサイズ
        threadsPerThreadgroup = MTLSizeMake(Const.simdGroupSize,
                                            momentComputeState.maxTotalThreadsPerThreadgroup / Const.simdGroupSize,
                                            1)
        threadsPerGrid = MTLSizeMake(imageSize, imageSize, 1)
        
        // インプットテクスチャ（二値化画像）バッファ
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                 width: imageSize,
                                                                 height: imageSize,
                                                                 mipmapped: false)
        colorDesc.usage = [.shaderRead, .shaderWrite]
        binarizedTexture = device.makeTexture(descriptor: colorDesc)
        
        // モーメントの計算要素の計算結果格納バッファ
        let momentElementsBufferSize = (imageSize / threadsPerThreadgroup.width) * (imageSize / threadsPerThreadgroup.height)
        momentElementsBuffer = device.makeBuffer(length: MemoryLayout<MomentElement>.stride * momentElementsBufferSize, options: [])!
        
        let pointer = momentElementsBuffer.contents().bindMemory(to: MomentElement.self, capacity: momentElementsBufferSize)
        momentElements = UnsafeBufferPointer<MomentElement>(start: pointer, count: momentElementsBufferSize)
    }
}
