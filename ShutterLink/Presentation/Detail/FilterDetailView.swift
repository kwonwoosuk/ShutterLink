//
//  FilterDetailView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/26/25.
//

import SwiftUI

struct FilterDetailView: View {
    let filterId: String
    @StateObject private var viewModel = FilterDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let filterDetail = viewModel.filterDetail {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 이미지 비교 섹션
                        BeforeAfterImageView(
                            imagePath: filterDetail.files.first ?? "",
                            filterValues: filterDetail.filterValues
                        )
                        .frame(height: 300)
                        
                        // 필터 정보 섹션
                        FilterInfoSection(filterDetail: filterDetail)
                        
                        // 크리에이터 정보 섹션
                        CreatorInfoSection(creator: filterDetail.creator)
                        
                        // 액션 버튼 섹션
                        ActionButtonsSection(
                            filterDetail: filterDetail,
                            onLike: { shouldLike in
                                viewModel.input.likeFilter.send((filterId, shouldLike))
                            }
                        )
                        
                        // 사진 메타데이터 섹션
                        PhotoMetadataSection(metadata: filterDetail.photoMetadata)
                        
                        // 필터 값 섹션
                        FilterValuesSection(filterValues: filterDetail.filterValues)
                        
                        // 댓글 섹션
                        CommentsSection(comments: filterDetail.comments)
                        
                        // 하단 여백
                        Color.clear.frame(height: 100)
                    }
                }
            } else if viewModel.isLoading {
                // 로딩 상태
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("필터 정보를 불러오는 중...")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(20)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            } else if let errorMessage = viewModel.errorMessage {
                // 에러 상태
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.pretendard(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Button("다시 시도") {
                        viewModel.input.loadFilterDetail.send(filterId)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(20)
            }
        }
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 커스텀 백버튼
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Gray.gray75)
                }
            }
            
            // 커스텀 타이틀 (필터 이름)
            ToolbarItem(placement: .principal) {
                if let filterDetail = viewModel.filterDetail {
                    Text(filterDetail.title)
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Text("")
                        .font(.hakgyoansim(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // 공유 버튼
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // 공유 기능
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Gray.gray75)
                }
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔵 FilterDetailView: 필터 상세 로딩 시작 - \(filterId)")
                    viewModel.input.loadFilterDetail.send(filterId)
                }
            }
        }
    }
}

// MARK: - Before/After 이미지 비교 뷰
struct BeforeAfterImageView: View {
    let imagePath: String
    let filterValues: FilterValues
    @State private var dividerPosition: CGFloat = 0.5
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Before 이미지 (원본)
                if !imagePath.isEmpty {
                    AuthenticatedImageView(
                        imagePath: imagePath,
                        contentMode: .fill
                    ) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                
                // After 이미지 (필터 적용된 것처럼 보이게 하는 오버레이)
                if !imagePath.isEmpty {
                    AuthenticatedImageView(
                        imagePath: imagePath,
                        contentMode: .fill
                    ) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(
                        // 필터 효과 시뮬레이션 (실제로는 복잡한 이미지 처리 필요)
                        Color.blue.opacity(0.1 + filterValues.saturation * 0.1)
                            .blendMode(.multiply)
                    )
                    .brightness(filterValues.brightness * 0.5)
                    .contrast(filterValues.contrast)
                    .saturation(filterValues.saturation)
                    .clipShape(
                        Rectangle()
                            .size(width: geometry.size.width * dividerPosition,
                                  height: geometry.size.height)
                    )
                }
                
                // 분할선
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: geometry.size.height)
                    .position(x: geometry.size.width * dividerPosition, y: geometry.size.height / 2)
                
                // 드래그 핸들
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .position(x: geometry.size.width * dividerPosition, y: geometry.size.height / 2)
                
                // Before/After 라벨
                VStack {
                    HStack {
                        Text("AFTER")
                            .font(.pretendard(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(.leading, 12)
                            .padding(.top, 12)
                        
                        Spacer()
                        
                        Text("BEFORE")
                            .font(.pretendard(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(.trailing, 12)
                            .padding(.top, 12)
                    }
                    Spacer()
                }
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onChanged { value in
                        let newPosition = dividerPosition + (value.translation.width / geometry.size.width)
                        dividerPosition = max(0.1, min(0.9, newPosition))
                    }
            )
        }
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

// MARK: - 필터 정보 섹션
struct FilterInfoSection: View {
    let filterDetail: FilterDetailResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(filterDetail.title)
                        .font(.hakgyoansim(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("#\(filterDetail.category)")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("₩\(filterDetail.price)")
                        .font(.pretendard(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            Text("\(filterDetail.like_count)")
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "cart.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("\(filterDetail.buyer_count)")
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Text(filterDetail.description)
                .font(.pretendard(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(nil)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 크리에이터 정보 섹션
struct CreatorInfoSection: View {
    let creator: CreatorInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("크리에이터")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                // 프로필 이미지
                if let profileImagePath = creator.profileImage {
                    AuthenticatedImageView(
                        imagePath: profileImagePath,
                        contentMode: .fill
                    ) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(creator.name)
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Text(creator.nick)
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(creator.introduction)
                        .font(.pretendard(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // 해시태그
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(creator.hashTags, id: \.self) { tag in
                        Text(tag)
                            .font(.pretendard(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 액션 버튼 섹션
struct ActionButtonsSection: View {
    let filterDetail: FilterDetailResponse
    let onLike: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 좋아요 버튼
            Button {
                onLike(!filterDetail.is_liked)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: filterDetail.is_liked ? "heart.fill" : "heart")
                        .foregroundColor(filterDetail.is_liked ? .red : .white)
                    Text(filterDetail.is_liked ? "좋아요 취소" : "좋아요")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            
            // 다운로드 버튼
            Button {
                // 다운로드 로직
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: filterDetail.is_downloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .foregroundColor(filterDetail.is_downloaded ? .green : .white)
                    Text(filterDetail.is_downloaded ? "다운로드 완료" : "다운로드")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(filterDetail.is_downloaded ? Color.green.opacity(0.2) : DesignSystem.Colors.Brand.brightTurquoise)
                .cornerRadius(8)
            }
            .disabled(filterDetail.is_downloaded)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 사진 메타데이터 섹션
struct PhotoMetadataSection: View {
    let metadata: PhotoMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("사진 정보")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetadataItem(title: "카메라", value: metadata.camera)
                MetadataItem(title: "렌즈", value: metadata.lens_info)
                MetadataItem(title: "초점거리", value: "\(metadata.focal_length)mm")
                MetadataItem(title: "조리개", value: "f/\(metadata.aperture)")
                MetadataItem(title: "ISO", value: "\(metadata.iso)")
                MetadataItem(title: "셔터속도", value: metadata.shutter_speed)
                MetadataItem(title: "해상도", value: metadata.resolution)
                MetadataItem(title: "파일크기", value: metadata.formattedFileSize)
                MetadataItem(title: "포맷", value: metadata.format)
                MetadataItem(title: "촬영일시", value: metadata.formattedDateTime)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct MetadataItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 필터 값 섹션
struct FilterValuesSection: View {
    let filterValues: FilterValues
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("필터 설정값")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(filterValues.adjustments, id: \.0) { adjustment in
                    FilterValueItem(title: adjustment.0, value: adjustment.1)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct FilterValueItem: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.pretendard(size: 14, weight: .semiBold))
                .foregroundColor(DesignSystem.Colors.Brand.brightTurquoise)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 댓글 섹션
struct CommentsSection: View {
    let comments: [Comment]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("댓글 (\(comments.count))")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            if comments.isEmpty {
                Text("아직 댓글이 없습니다.")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                ForEach(comments) { comment in
                    CommentItem(comment: comment)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct CommentItem: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // 프로필 이미지
                if let profileImagePath = comment.creator.profileImage {
                    AuthenticatedImageView(
                        imagePath: profileImagePath,
                        contentMode: .fill
                    ) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.creator.nick)
                            .font(.pretendard(size: 14, weight: .semiBold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formatCommentDate(comment.createdAt))
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    Text(comment.content)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // 답글
            if !comment.replies.isEmpty {
                VStack(spacing: 8) {
                    ForEach(comment.replies) { reply in
                        HStack(alignment: .top, spacing: 12) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 32)
                                .padding(.leading, 16)
                            
                            if let profileImagePath = reply.creator.profileImage {
                                AuthenticatedImageView(
                                    imagePath: profileImagePath,
                                    contentMode: .fill
                                ) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 14))
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(reply.creator.nick)
                                        .font(.pretendard(size: 12, weight: .semiBold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(formatCommentDate(reply.createdAt))
                                        .font(.pretendard(size: 10, weight: .regular))
                                        .foregroundColor(.gray)
                                }
                                
                                Text(reply.content)
                                    .font(.pretendard(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatCommentDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            let now = Date()
            let timeInterval = now.timeIntervalSince(date)
            
            if timeInterval < 60 {
                return "방금 전"
            } else if timeInterval < 3600 {
                return "\(Int(timeInterval / 60))분 전"
            } else if timeInterval < 86400 {
                return "\(Int(timeInterval / 3600))시간 전"
            } else {
                formatter.dateFormat = "MM.dd"
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}
