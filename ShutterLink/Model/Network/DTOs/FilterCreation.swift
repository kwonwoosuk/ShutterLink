//
//  FilterCreation.swift
//  ShutterLink
//
//  Created by 권우석 on 6/6/25.
//

import Foundation

// MARK: - 파일 업로드 응답 모델
struct FilterFilesUploadResponse: Decodable {
    let files: [String]
}

// MARK: - 필터 생성 요청 모델
struct FilterCreateRequest: Encodable {
    let category: String
    let title: String
    let price: Int
    let description: String
    let files: [String]
    let photoMetadata: PhotoMetadataRequest?
    let filterValues: FilterValuesRequest
    
    enum CodingKeys: String, CodingKey {
        case category, title, price, description, files
        case photoMetadata = "photo_metadata"
        case filterValues = "filter_values"
    }
}

// MARK: - 사진 메타데이터 요청 모델
struct PhotoMetadataRequest: Encodable {
    let camera: String?
    let lensInfo: String?
    let focalLength: Float?
    let aperture: Double?
    let iso: Int?
    let shutterSpeed: String?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let fileSize: Int?
    let format: String?
    let dateTimeOriginal: String?
    let latitude: Double?
    let longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case camera
        case lensInfo = "lens_info"
        case focalLength = "focal_length"
        case aperture, iso
        case shutterSpeed = "shutter_speed"
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
        case fileSize = "file_size"
        case format
        case dateTimeOriginal = "date_time_original"
        case latitude, longitude
    }
}

// MARK: - 필터 값 요청 모델
struct FilterValuesRequest: Encodable {
    let brightness: Double
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let sharpness: Double
    let blur: Double
    let vignette: Double
    let noiseReduction: Double
    let highlights: Double
    let shadows: Double
    let temperature: Double
    let blackPoint: Double
    
    enum CodingKeys: String, CodingKey {
        case brightness, exposure, contrast, saturation
        case sharpness, blur, vignette
        case noiseReduction = "noise_reduction"
        case highlights, shadows, temperature
        case blackPoint = "black_point"
    }
}

// MARK: - 필터 속성 정의
struct FilterProperty {
    let key: String
    let name: String
    let iconName: String
    let minValue: Double
    let maxValue: Double
    let defaultValue: Double
    let step: Double
    
    static let properties: [FilterProperty] = [
        FilterProperty(key: "brightness", name: "밝기", iconName: "Brightness",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "exposure", name: "노출", iconName: "Exposure",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "contrast", name: "대비", iconName: "Contrast",
                      minValue: 0.0, maxValue: 2.0, defaultValue: 1.0, step: 0.01),
        FilterProperty(key: "saturation", name: "채도", iconName: "Saturation",
                      minValue: 0.0, maxValue: 2.0, defaultValue: 1.0, step: 0.01),
        FilterProperty(key: "sharpness", name: "선명도", iconName: "Sharpness",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "blur", name: "블러", iconName: "Blur",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "vignette", name: "비네팅", iconName: "Vignette",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "noiseReduction", name: "노이즈", iconName: "Noise",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "highlights", name: "하이라이트", iconName: "Highlights",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "shadows", name: "섀도우", iconName: "Shadows",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01),
        FilterProperty(key: "temperature", name: "색온도", iconName: "Temperature",
                      minValue: 2000, maxValue: 10000, defaultValue: 6500, step: 50),
        FilterProperty(key: "blackPoint", name: "블랙포인트", iconName: "BlackPoint",
                      minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.01)
    ]
}

// MARK: - 편집 상태 모델
struct EditingState: Equatable {
    var brightness: Double = 0.0
    var exposure: Double = 0.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var sharpness: Double = 0.0
    var blur: Double = 0.0
    var vignette: Double = 0.0
    var noiseReduction: Double = 0.0
    var highlights: Double = 0.0
    var shadows: Double = 0.0
    var temperature: Double = 6500.0
    var blackPoint: Double = 0.0
    
    static let defaultState = EditingState()
    
    func toFilterValuesRequest() -> FilterValuesRequest {
        return FilterValuesRequest(
            brightness: brightness,
            exposure: exposure,
            contrast: contrast,
            saturation: saturation,
            sharpness: sharpness,
            blur: blur,
            vignette: vignette,
            noiseReduction: noiseReduction,
            highlights: highlights,
            shadows: shadows,
            temperature: temperature,
            blackPoint: blackPoint
        )
    }
    
    mutating func setValue(for key: String, value: Double) {
        switch key {
        case "brightness": brightness = value
        case "exposure": exposure = value
        case "contrast": contrast = value
        case "saturation": saturation = value
        case "sharpness": sharpness = value
        case "blur": blur = value
        case "vignette": vignette = value
        case "noiseReduction": noiseReduction = value
        case "highlights": highlights = value
        case "shadows": shadows = value
        case "temperature": temperature = value
        case "blackPoint": blackPoint = value
        default: break
        }
    }
    
    func getValue(for key: String) -> Double {
        switch key {
        case "brightness": return brightness
        case "exposure": return exposure
        case "contrast": return contrast
        case "saturation": return saturation
        case "sharpness": return sharpness
        case "blur": return blur
        case "vignette": return vignette
        case "noiseReduction": return noiseReduction
        case "highlights": return highlights
        case "shadows": return shadows
        case "temperature": return temperature
        case "blackPoint": return blackPoint
        default: return 0.0
        }
    }
}
