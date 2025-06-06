//
//  ImageFilterProcessor.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

class ImageFilterProcessor: ObservableObject {
    private let context = CIContext()
    private var originalCIImage: CIImage?
    
    func setOriginalImage(_ image: UIImage) {
        originalCIImage = CIImage(image: image)
    }
    
    func applyFilters(with state: EditingState) -> UIImage? {
        guard let originalImage = originalCIImage else { return nil }
        
        var filteredImage = originalImage
        
        // 1. 밝기 (Brightness)
        if state.brightness != 0.0 {
            let brightnessFilter = CIFilter.colorControls()
            brightnessFilter.inputImage = filteredImage
            brightnessFilter.brightness = Float(state.brightness)
            if let output = brightnessFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 2. 노출 (Exposure)
        if state.exposure != 0.0 {
            let exposureFilter = CIFilter.exposureAdjust()
            exposureFilter.inputImage = filteredImage
            exposureFilter.ev = Float(state.exposure * 2.0) // 스케일 조정
            if let output = exposureFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 3. 대비 (Contrast)
        if state.contrast != 1.0 {
            let contrastFilter = CIFilter.colorControls()
            contrastFilter.inputImage = filteredImage
            contrastFilter.contrast = Float(state.contrast)
            if let output = contrastFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 4. 채도 (Saturation)
        if state.saturation != 1.0 {
            let saturationFilter = CIFilter.colorControls()
            saturationFilter.inputImage = filteredImage
            saturationFilter.saturation = Float(state.saturation)
            if let output = saturationFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 5. 선명도 (Sharpness)
        if state.sharpness != 0.0 {
            let sharpnessFilter = CIFilter.sharpenLuminance()
            sharpnessFilter.inputImage = filteredImage
            sharpnessFilter.sharpness = Float(abs(state.sharpness) * 2.0)
            if let output = sharpnessFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 6. 블러 (Blur)
        if state.blur != 0.0 {
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = filteredImage
            blurFilter.radius = Float(abs(state.blur) * 10.0)
            if let output = blurFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 7. 비네팅 (Vignette)
        if state.vignette != 0.0 {
            let vignetteFilter = CIFilter.vignette()
            vignetteFilter.inputImage = filteredImage
            vignetteFilter.intensity = Float(state.vignette * 2.0)
            vignetteFilter.radius = 1.0
            if let output = vignetteFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 8. 노이즈 감소 (Noise Reduction)
        if state.noiseReduction != 0.0 {
            let noiseFilter = CIFilter.noiseReduction()
            noiseFilter.inputImage = filteredImage
            noiseFilter.noiseLevel = Float(state.noiseReduction * 0.02)
            noiseFilter.sharpness = 0.4
            if let output = noiseFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 9. 하이라이트 (Highlights)
        if state.highlights != 0.0 {
            let highlightFilter = CIFilter.highlightShadowAdjust()
            highlightFilter.inputImage = filteredImage
            highlightFilter.highlightAmount = Float(state.highlights + 1.0)
            if let output = highlightFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 10. 섀도우 (Shadows)
        if state.shadows != 0.0 {
            let shadowFilter = CIFilter.highlightShadowAdjust()
            shadowFilter.inputImage = filteredImage
            shadowFilter.shadowAmount = Float(state.shadows + 1.0)
            if let output = shadowFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 11. 색온도 (Temperature)
        if state.temperature != 6500.0 {
            let temperatureFilter = CIFilter.temperatureAndTint()
            temperatureFilter.inputImage = filteredImage
            let neutral = CIVector(x: 6500, y: 0)
            let targetTemp = CIVector(x: state.temperature, y: 0)
            temperatureFilter.neutral = neutral
            temperatureFilter.targetNeutral = targetTemp
            if let output = temperatureFilter.outputImage {
                filteredImage = output
            }
        }
        
        // 12. 블랙 포인트 (Black Point)
        if state.blackPoint != 0.0 {
            let blackPointFilter = CIFilter.colorControls()
            blackPointFilter.inputImage = filteredImage
            blackPointFilter.brightness = Float(state.blackPoint * -0.3) // 블랙포인트 효과
            if let output = blackPointFilter.outputImage {
                filteredImage = output
            }
        }
        
        // CIImage를 UIImage로 변환
        guard let cgImage = context.createCGImage(filteredImage, from: filteredImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func resetFilters() -> UIImage? {
        guard let originalImage = originalCIImage,
              let cgImage = context.createCGImage(originalImage, from: originalImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 이미지 유틸리티 확장
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func jpegData(compressionQuality: CGFloat, maxSizeInBytes: Int = 2 * 1024 * 1024) -> Data? {
        var compression = compressionQuality
        var imageData = self.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxSizeInBytes && compression > 0.1 {
            compression -= 0.1
            imageData = self.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
}
