//
//  HomeView.swift
//  ShutterLink
//
//  Created by 권우석 on 5/22/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        ZStack {
            // 다크 모드 배경
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 헤더 영역
                    HeaderView()
                    
                    // 콘텐츠 영역
                    LazyVStack(spacing: 32) {
                        // 섹션 1: 오늘의 필터 소개 (필터 정보만)
                        TodayFilterIntroSection(filter: viewModel.todayFilter)
                        
                        // 섹션 2: 광고 배너 (별도 섹션)
                        AdBannerSection()
                        
                        // 섹션 3: 핫트랜드 (무한 스크롤)
                        HotTrendSection(filters: viewModel.hotTrendFilters)
                        
                        // 섹션 4: 오늘의 작가 소개
                        TodayAuthorSection(authorData: viewModel.todayAuthor)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120) // 탭바와 여유 공간
                }
            }
            
            // 로딩 인디케이터
            if viewModel.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("로딩 중...")
                        .font(.pretendard(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadHomeData()
            }
        }
        .refreshable {
            await viewModel.loadHomeData()
        }
    }
}

// MARK: - 헤더 뷰
struct HeaderView: View {
    var body: some View {
        HStack {
            Text("ShutterLink")
                .font(.hakgyoansim(size: 20, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "bell")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

// MARK: - 섹션 1: 오늘의 필터 소개 (필터 정보만)
struct TodayFilterIntroSection: View {
    let filter: TodayFilterResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 타이틀
            HStack {
                Text("오늘의 필터")
                    .font(.hakgyoansim(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // 오늘의 필터 상세 정보
            if let filter = filter {
                VStack(alignment: .leading, spacing: 16) {
                    // 메인 이미지
                    ZStack {
                        if let firstImagePath = filter.files.first {
                            AuthenticatedImageView(
                                imagePath: firstImagePath,
                                contentMode: .fill
                            ) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                            .frame(height: 240)
                            .clipped()
                        }
                        
                        // 그라데이션 오버레이
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.6)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // 텍스트 콘텐츠
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(filter.title)
                                        .font(.hakgyoansim(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(filter.introduction)
                                        .font(.pretendard(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // 필터 상세 설명
                    VStack(alignment: .leading, spacing: 12) {
                        Text("필터 설명")
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.white)
                        
                        Text(filter.description)
                            .font(.pretendard(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(nil)
                        
                        // 생성/수정일
                        HStack {
                            Text("생성일: \(formatDate(filter.createdAt))")
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            Text("수정일: \(formatDate(filter.updatedAt))")
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                // 로딩 상태
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 240)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
                    .padding(.horizontal, 20)
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - 섹션 2: 광고 배너 (독립 섹션)
struct AdBannerSection: View {
    // 광고 배너 데이터
    private let bannerData = [
        BannerMockData(id: 1, title: "새싹을 담은 필터", subtitle: "자연 시장", imageColor: .green),
        BannerMockData(id: 2, title: "도시의 감성", subtitle: "도시 필터", imageColor: .blue),
        BannerMockData(id: 3, title: "따뜻한 햇살", subtitle: "빈티지 필터", imageColor: .orange),
        BannerMockData(id: 4, title: "차가운 밤", subtitle: "블루 필터", imageColor: .indigo),
        BannerMockData(id: 5, title: "꽃잎의 춤", subtitle: "핑크 필터", imageColor: .pink)
    ]
    
    var body: some View {
        // 광고 배너 (Fade 페이징)
        AdBannerCarousel(banners: bannerData)
    }
}

// MARK: - 광고 배너 캐러셀 (수평 스크롤 - iOS 16 호환, 한 셀씩 페이징)
struct AdBannerCarousel: View {
    let banners: [BannerMockData]
    @State private var currentIndex = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width - 40 // 패딩 고려
            let adjustedWidth = screenWidth // 셀 너비를 스크롤 뷰의 페이징 너비와 일치시킴

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                        AdBannerCard(banner: banner)
                            .frame(width: adjustedWidth, height: 100)
                            .id(index)
                    }
                }
                .offset(x: offset)
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: scrollGeometry.frame(in: .named("bannerScrollView")).minX
                        )
                    }
                )
            }
            .coordinateSpace(name: "bannerScrollView")
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation.width - CGFloat(currentIndex) * adjustedWidth
                    }
                    .onEnded { value in
                        let dragOffset = value.translation.width
                        let velocity = value.predictedEndTranslation.width
                        let threshold = adjustedWidth * 0.5
                        var newIndex = currentIndex

                        if dragOffset < -threshold || velocity < -100 {
                            newIndex = min(currentIndex + 1, banners.count - 1)
                        } else if dragOffset > threshold || velocity > 100 {
                            newIndex = max(currentIndex - 1, 0)
                        }

                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentIndex = newIndex
                            offset = -CGFloat(newIndex) * adjustedWidth
                        }
                    }
            )
            .onAppear {
                offset = -CGFloat(currentIndex) * adjustedWidth
            }
        }
        .frame(height: 120)
        .padding(.horizontal, 20)
    }
}


struct AdBannerCard: View {
    let banner: BannerMockData

    var body: some View {
        ZStack {
            // 배경 이미지 (가로로 긴 형태)
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [banner.imageColor, banner.imageColor.opacity(0.6)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // 텍스트 콘텐츠
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(banner.subtitle)
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Text(banner.title)
                        .font(.pretendard(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 섹션 3: 핫트랜드 (무한 스크롤 + 중앙 페이징)
struct HotTrendSection: View {
    let filters: [FilterItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 타이틀
            HStack {
                Text("핫 트렌드")
                    .font(.hakgyoansim(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 20)

            if !filters.isEmpty {
                // 10개 셀만 사용하도록 제한
                let limitedFilters = Array(filters.prefix(10))
                InfiniteCarouselView(filters: limitedFilters)
            } else {
                // 로딩 상태
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .frame(height: 280)
            }
        }
    }
}

// MARK: - 무한 스크롤 캐러셀 뷰 (수평 스크롤만)
struct InfiniteCarouselView: View {
    let filters: [FilterItem]
        @State private var dragOffset: CGFloat = 0
        @State private var currentIndex: Int = 0
        
        var body: some View {
            let cardWidth = UIScreen.main.bounds.width * (200.0 / 390.0)
            let cardHeight = cardWidth * (240.0 / 200.0)
            let spacing: CGFloat = 30
            
            VStack(alignment: .leading, spacing: 0) {
           
                
                VStack(alignment: .leading, spacing: 0) {
                    GeometryReader { geo in
                        HStack(spacing: spacing) {
                            ForEach(filters.indices, id: \.self) { idx in
                                let filter = filters[idx]
                                let isCenter = idx == currentIndex
                                let distance = abs(CGFloat(idx) * (cardWidth + spacing) + dragOffset - CGFloat(currentIndex) * (cardWidth + spacing))
                                let scale = max(0.9, 1 - distance / geo.size.width * 0.2)
                                
                                CarouselCard(
                                    filter: filter,
                                    isCenter: isCenter,
                                    scale: scale,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight
                                )
                            }
                        }
                        .offset(x: -CGFloat(currentIndex) * (cardWidth + spacing) + dragOffset + (geo.size.width - cardWidth) / 2 + 4)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation.width
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = cardWidth / 2
                                    var newIndex = currentIndex
                                    if value.predictedEndTranslation.width < -threshold {
                                        newIndex = min(currentIndex + 1, filters.count - 1)
                                    } else if value.predictedEndTranslation.width > threshold {
                                        newIndex = max(currentIndex - 1, 0)
                                    }
                                    withAnimation(.easeInOut) {
                                        currentIndex = newIndex
                                        dragOffset = 0
                                    }
                                }
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)
                }
                .padding(.horizontal, 0)
                .padding(.bottom, spacing)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
}

// 스크롤 오프셋을 감지하기 위한 PreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CarouselCard: View {
    let filter: FilterItem
       let isCenter: Bool
       let scale: CGFloat
       let cardWidth: CGFloat
       let cardHeight: CGFloat
       
       var body: some View {
           VStack(spacing: 12) {
               // 메인 이미지 영역
               ZStack {
                   if let firstImagePath = filter.files.first {
                       AuthenticatedImageView(
                           imagePath: firstImagePath,
                           contentMode: .fill
                       ) {
                           Rectangle()
                               .fill(Color.gray.opacity(0.3))
                               .overlay(
                                   ProgressView()
                                       .progressViewStyle(CircularProgressViewStyle(tint: .white))
                               )
                       }
                       .scaledToFill()
                       .frame(width: cardWidth, height: cardWidth)
                       .clipped()
                       .cornerRadius(20)
                       .overlay(
                           // 선택되지 않은 카드에 어두운 오버레이
                           Color.black.opacity(isCenter ? 0 : 0.5)
                       )
                       .overlay(
                           // 선택된 카드에 테두리 효과
                           RoundedRectangle(cornerRadius: 20)
                               .stroke(
                                   isCenter ? Color.white : Color.clear,
                                   lineWidth: isCenter ? 2 : 0
                               )
                       )
                   } else {
                       Rectangle()
                           .fill(Color.gray.opacity(0.3))
                           .frame(width: cardWidth, height: cardWidth)
                           .cornerRadius(20)
                   }
                   
                   // 좋아요 카운트 (오른쪽 하단)
                   VStack {
                       Spacer()
                       HStack {
                           Spacer()
                           HStack(spacing: 4) {
                               Image(systemName: "heart.fill")
                                   .foregroundColor(.red)
                                   .font(.system(size: 12))
                               Text("\(filter.like_count)")
                                   .font(.pretendard(size: 12, weight: .medium))
                                   .foregroundColor(.white)
                           }
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(
                               Capsule()
                                   .fill(Color.black.opacity(0.7))
                           )
                           .padding(8)
                       }
                   }
               }
               
               // 카드 정보 (선택된 카드만 표시)
               if isCenter {
                   VStack(spacing: 4) {
                       Text(filter.title)
                           .font(.pretendard(size: 16, weight: .bold))
                           .foregroundColor(.white)
                           .lineLimit(1)
                       
                       Text(filter.creator.nick)
                           .font(.pretendard(size: 12, weight: .medium))
                           .foregroundColor(.gray)
                           .lineLimit(1)
                   }
                   .transition(.opacity.combined(with: .scale))
               }
           }
           .frame(width: cardWidth)
           .scaleEffect(scale)
           .opacity(isCenter ? 1.0 : 0.7)
           .shadow(radius: isCenter ? 10 : 3)
           .animation(.easeInOut(duration: 0.3), value: isCenter)
       }
}

// MARK: - 섹션 4: 오늘의 작가 소개 (왼쪽 정렬)
struct TodayAuthorSection: View {
    let authorData: TodayAuthorResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 타이틀
            HStack {
                Text("오늘의 작가 소개")
                    .font(.hakgyoansim(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if let authorData = authorData {
                VStack(alignment: .leading, spacing: 20) {
                    // 작가 프로필 섹션 (왼쪽 정렬)
                    HStack(alignment: .top, spacing: 16) {
                        // 프로필 이미지
                        if let profileImagePath = authorData.author.profileImage {
                            AuthenticatedImageView(
                                imagePath: profileImagePath,
                                contentMode: .fill
                            ) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 32))
                                )
                        }
                        
                        // 작가 정보 (왼쪽 정렬)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(authorData.author.name)
                                .font(.pretendard(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(authorData.author.nick)
                                .font(.pretendard(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(authorData.author.introduction)
                                .font(.pretendard(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                            
                            // 해시태그 (왼쪽 정렬)
                            if !authorData.author.hashTags.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(authorData.author.hashTags.prefix(3), id: \.self) { tag in
                                        Text(tag)
                                            .font(.pretendard(size: 11, weight: .medium))
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
                                .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // 작가 상세 설명 (왼쪽 정렬)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("작가 소개")
                            .font(.pretendard(size: 16, weight: .semiBold))
                            .foregroundColor(.white)
                        
                        Text(authorData.author.description)
                            .font(.pretendard(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 20)
                    
                    // 작가의 필터 작품들
                    if !authorData.filters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("작가의 작품")
                                .font(.pretendard(size: 16, weight: .semiBold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(authorData.filters) { filter in
                                        AuthorFilterCard(filter: filter)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            } else {
                
                AuthorMockView()
            }
        }
    }
}

// MARK: - 작가 Mock 뷰 (데이터 로딩 실패 시)
struct AuthorMockView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Mock 작가 프로필
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 32))
                    )
                
                VStack(spacing: 8) {
                    Text("새싹 작가")
                        .font(.pretendard(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("SESAC CREATOR")
                        .font(.pretendard(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("자연의 아름다움을 담는 사진작가")
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Mock 해시태그
                HStack(spacing: 8) {
                    Text("#자연")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("#감성")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            
            // Mock 설명
            VStack(alignment: .leading, spacing: 12) {
                Text("작가 소개")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                
                Text("자연의 섬세한 아름다움을 포착하는 데 탁월한 감각을 지닌 사진작가입니다. 새싹이 돋아나는 계절의 생명력과 따뜻함을 렌즈에 담아내며, 보는 이들에게 감동을 전달합니다.")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            
            // Mock 필터 작품들
            VStack(alignment: .leading, spacing: 12) {
                Text("작가의 작품")
                    .font(.pretendard(size: 16, weight: .semiBold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4) { index in
                            MockFilterCard(index: index)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct MockFilterCard: View {
    let index: Int
    private let mockTitles = ["자연 필터", "도시 필터", "빈티지 필터", "모던 필터"]
    private let mockColors: [Color] = [.green, .blue, .orange, .purple]
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(mockColors[index].opacity(0.6))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "camera.filters")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                )
            
            Text(mockTitles[index])
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

struct AuthorFilterCard: View {
    let filter: FilterItem
    
    var body: some View {
        VStack(spacing: 8) {
            if let firstImagePath = filter.files.first {
                AuthenticatedImageView(
                    imagePath: firstImagePath,
                    contentMode: .fill
                ) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            Text(filter.title)
                .font(.pretendard(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 120)
        }
    }
}


struct BannerMockData: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let imageColor: Color
}
