//
//  FilterDetail.swift
//  ShutterLink
//
//  Created by 권우석 on 5/26/25.
//

import Foundation

// MARK: - 필터 상세 응답 모델
struct FilterDetailResponse: Decodable {
    let filter_id: String
    let category: String
    let title: String
    let description: String
    let files: [String]
    let price: Int
    let creator: CreatorInfo
    let photoMetadata: PhotoMetadata?
    let filterValues: FilterValues
    var is_liked: Bool
    var is_downloaded: Bool
    var like_count: Int
    var buyer_count: Int
    let comments: [Comment]
    let createdAt: String
    let updatedAt: String
}

// MARK: - 사진 메타데이터 모델
struct PhotoMetadata: Decodable {
    let camera: String?                 // 옵셔널로 변경
    let lens_info: String?              // 옵셔널로 변경
    let focal_length: Float?            // 옵셔널로 변경
    let aperture: Double?               // 옵셔널로 변경
    let iso: Int?                       // 옵셔널로 변경
    let shutter_speed: String?          // 옵셔널로 변경
    let pixel_width: Int
    let pixel_height: Int
    let file_size: Int
    let format: String?                 // 옵셔널로 변경
    let date_time_original: String?     // 옵셔널로 변경
    let latitude: Double?
    let longitude: Double?
}

// MARK: - 필터 값 모델
struct FilterValues: Decodable {
    let brightness: Double
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let sharpness: Double
    let blur: Double
    let vignette: Double
    let noise_reduction: Double
    let highlights: Double
    let shadows: Double
    let temperature: Double
    let black_point: Double
}

// MARK: - 댓글 모델
struct Comment: Decodable, Identifiable {
    let comment_id: String
    let content: String
    let createdAt: String
    let creator: CreatorInfo
    let replies: [Reply]
    
    var id: String { comment_id }
}

// MARK: - 답글 모델
struct Reply: Decodable, Identifiable {
    let comment_id: String
    let content: String
    let createdAt: String
    let creator: CreatorInfo
    
    var id: String { comment_id }
}

// MARK: - 유틸리티 확장
extension PhotoMetadata {
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(file_size))
    }
    
    var formattedDateTime: String {
        guard let dateTimeOriginal = date_time_original else {
            return "알 수 없음"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = formatter.date(from: dateTimeOriginal) {
            formatter.dateFormat = "yyyy.MM.dd HH:mm"
            return formatter.string(from: date)
        }
        return dateTimeOriginal
    }
    
    var resolution: String {
        return "\(pixel_width) × \(pixel_height)"
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
    
    // 카메라 정보 (안전하게 처리)
    var cameraInfo: String {
        return camera ?? "알 수 없는 카메라"
    }
    
    // 렌즈 정보 (안전하게 처리)
    var lensInfo: String {
        return lens_info ?? "알 수 없는 렌즈"
    }
    
    // 초점거리 정보 (안전하게 처리)
    var focalLengthInfo: String {
        guard let focalLength = focal_length else {
            return "알 수 없음"
        }
        return "\(Int(focalLength))mm"
    }
    
    // 조리개 정보 (안전하게 처리)
    var apertureInfo: String {
        guard let aperture = aperture else {
            return "알 수 없음"
        }
        return "f/\(String(format: "%.1f", aperture))"
    }
    
    // ISO 정보 (안전하게 처리)
    var isoInfo: String {
        guard let iso = iso else {
            return "알 수 없음"
        }
        return "ISO \(iso)"
    }
    
    // 셔터 스피드 정보 (안전하게 처리)
    var shutterSpeedInfo: String {
        return shutter_speed ?? "알 수 없음"
    }
}

extension FilterValues {
    var adjustments: [(String, String)] {
        return [
            ("밝기", String(format: "%.1f", brightness)),
            ("노출", String(format: "%.1f", exposure)),
            ("대비", String(format: "%.2f", contrast)),
            ("채도", String(format: "%.2f", saturation)),
            ("선명도", String(format: "%.1f", sharpness)),
            ("블러", String(format: "%.1f", blur)),
            ("비네팅", String(format: "%.1f", vignette)),
            ("노이즈 감소", String(format: "%.1f", noise_reduction)),
            ("하이라이트", String(format: "%.1f", highlights)),
            ("섀도우", String(format: "%.1f", shadows)),
            ("색온도", String(format: "%.0fK", temperature)),
            ("블랙 포인트", String(format: "%.2f", black_point))
        ]
    }
}
