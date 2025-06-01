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
    let photoMetadata: PhotoMetadata
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
    let camera: String
    let lens_info: String
    let focal_length: Int
    let aperture: Double
    let iso: Int
    let shutter_speed: String
    let pixel_width: Int
    let pixel_height: Int
    let file_size: Int
    let format: String
    let date_time_original: String
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = formatter.date(from: date_time_original) {
            formatter.dateFormat = "yyyy.MM.dd HH:mm"
            return formatter.string(from: date)
        }
        return date_time_original
    }
    
    var resolution: String {
        return "\(pixel_width) × \(pixel_height)"
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
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
