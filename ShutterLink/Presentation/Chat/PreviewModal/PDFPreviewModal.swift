//
//  PDFPreviewModal.swift
//  ShutterLink
//
//  Created by 권우석 on 8/2/25.
//

import SwiftUI
import PDFKit
import Foundation

struct PDFPreviewModal: View {
    let pdfPaths: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    @State private var pdfDocuments: [PDFDocument?] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasStartedLoading = false
    
    init(pdfPaths: [String], initialIndex: Int = 0, isPresented: Binding<Bool>) {
        self.pdfPaths = pdfPaths
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    // 단일 PDF를 위한 편의 생성자
    init(pdfPath: String, isPresented: Binding<Bool>) {
        self.init(pdfPaths: [pdfPath], initialIndex: 0, isPresented: isPresented)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(message: errorMessage)
                } else if !pdfDocuments.isEmpty && pdfDocuments.compactMap({ $0 }).count > 0 {
                    pdfContentView()
                } else if hasStartedLoading {
                    emptyView
                } else {
                    initialView
                }
            }
            .navigationTitle("PDF 미리보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                print("👀 PDFPreviewModal onAppear 실행")
                // pdfPaths 확인
                if pdfPaths.isEmpty {
                    print("❌ PDFPreviewModal: pdfPaths가 비어있음")
                    errorMessage = "PDF 경로가 없습니다"
                    return
                }
                setupInitialState()
            }
        }
    }
    
    // MARK: - ✅ 초기 상태 설정
    
    private func setupInitialState() {
        print("🔧 PDFPreviewModal setupInitialState 시작")
        print("   - pdfPaths 개수: \(pdfPaths.count)")
        
        // 문서 배열 초기화
        pdfDocuments = Array(repeating: nil, count: pdfPaths.count)
        
        // ✅ 자동으로 로딩 시작 (UX 개선)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startLoadingPDFs()
        }
    }
    
    // MARK: - ✅ 초기 뷰 (로딩 시작 전)
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("PDF 문서 로딩 준비")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            Button("PDF 로드 시작") {
                startLoadingPDFs()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    // MARK: - 로딩 뷰
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("PDF 로딩 중...")
                .foregroundColor(.white)
                .font(.pretendard(size: 16, weight: .medium))
            
            if pdfPaths.count > 1 {
                Text("\(pdfPaths.count)개 파일 처리 중")
                    .foregroundColor(.gray)
                    .font(.pretendard(size: 14, weight: .regular))
            }
        }
    }
    
    // MARK: - 에러 뷰
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("PDF 로드 실패")
                .font(.pretendard(size: 18, weight: .semiBold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.pretendard(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("다시 시도") {
                startLoadingPDFs()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    // MARK: - 빈 뷰
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("PDF를 표시할 수 없습니다")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Button("다시 시도") {
                startLoadingPDFs()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    // MARK: - ✅ PDF 콘텐츠 뷰 (강제 새로고침 추가)
    
    private func pdfContentView() -> some View {
        VStack {
            // 여러 PDF일 때 페이지 인디케이터
            if pdfPaths.count > 1 {
                HStack {
                    Spacer()
                    Text("\(currentIndex + 1) / \(pdfPaths.count)")
                        .foregroundColor(.white)
                        .font(.pretendard(size: 16, weight: .medium))
                        .padding()
                    Spacer()
                }
            }
            
            // PDF TabView
            TabView(selection: $currentIndex) {
                ForEach(Array(pdfDocuments.enumerated()), id: \.offset) { index, document in
                    if let document = document {
                        PDFKitView(document: document)
                            .background(Color.white)
                            .tag(index)
                            .id("pdf-\(index)-\(Date().timeIntervalSince1970)") // ✅ 강제 새로고침
                    } else {
                        // 로딩 실패한 PDF
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("PDF 로드 실패")
                                .foregroundColor(.white)
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
    
    // MARK: - ✅ PDF 로딩 시작 (수동 트리거)
    
    private func startLoadingPDFs() {
        print("🚀 PDFPreviewModal: PDF 로딩 시작")
        
        guard !pdfPaths.isEmpty else {
            print("❌ PDFPreviewModal: PDF 경로가 비어있음")
            DispatchQueue.main.async {
                self.errorMessage = "표시할 PDF가 없습니다"
                self.isLoading = false
                self.hasStartedLoading = true
            }
            return
        }
        
        isLoading = true
        hasStartedLoading = true
        errorMessage = nil
        pdfDocuments = Array(repeating: nil, count: pdfPaths.count)
        
        Task {
            var loadedDocuments: [PDFDocument?] = Array(repeating: nil, count: pdfPaths.count)
            var hasError = false
            var lastError: Error?
            
            await withTaskGroup(of: (Int, PDFDocument?, Error?).self) { group in
                for (index, path) in pdfPaths.enumerated() {
                    group.addTask {
                        do {
                            print("📥 PDFPreviewModal: PDF[\(index)] 다운로드 시작")
                            let pdfData = try await self.downloadPDFData(from: path)
                            let document = PDFDocument(data: pdfData)
                            print("✅ PDFPreviewModal: PDF[\(index)] 로드 성공")
                            return (index, document, nil)
                        } catch {
                            print("❌ PDFPreviewModal: PDF[\(index)] 로드 실패 - \(error)")
                            return (index, nil, error)
                        }
                    }
                }
                
                for await result in group {
                    let (index, document, error) = result
                    loadedDocuments[index] = document
                    
                    if let error = error {
                        hasError = true
                        lastError = error
                    }
                }
            }
            
            await MainActor.run {
                print("📊 PDFPreviewModal: UI 업데이트 시작")
                self.isLoading = false
                self.pdfDocuments = loadedDocuments
                
                let successCount = loadedDocuments.compactMap { $0 }.count
                print("📊 PDFPreviewModal: PDF 문서 설정 완료")
                print("   - 성공: \(successCount) / \(self.pdfPaths.count)")
                
                if hasError && loadedDocuments.allSatisfy({ $0 == nil }) {
                    self.errorMessage = "PDF 로드 실패: \(lastError?.localizedDescription ?? "알 수 없는 오류")"
                    print("❌ PDFPreviewModal: 모든 PDF 로드 실패")
                } else if hasError {
                    print("⚠️ PDFPreviewModal: 일부 PDF 로드 실패")
                }
                
                // 강제 뷰 업데이트
                self.currentIndex = min(self.currentIndex, max(0, self.pdfDocuments.count - 1))
            }
        }
    }
    
    // MARK: - ✅ PDF 로드 (UI 업데이트 타이밍 개선)
    
    private func loadPDFs() {
        print("📥 PDFPreviewModal: PDF 로드 작업 시작")
        
        Task {
            var loadedDocuments: [PDFDocument?] = Array(repeating: nil, count: pdfPaths.count)
            var hasError = false
            var lastError: Error?
            
            // ✅ 모든 PDF를 병렬로 로드
            await withTaskGroup(of: (Int, PDFDocument?, Error?).self) { group in
                for (index, path) in pdfPaths.enumerated() {
                    group.addTask {
                        do {
                            print("📥 PDFPreviewModal: PDF[\(index)] 다운로드 시작")
                            let pdfData = try await downloadPDFData(from: path)
                            let document = PDFDocument(data: pdfData)
                            print("✅ PDFPreviewModal: PDF[\(index)] 로드 성공")
                            return (index, document, nil)
                        } catch {
                            print("❌ PDFPreviewModal: PDF[\(index)] 로드 실패 - \(error)")
                            return (index, nil, error)
                        }
                    }
                }
                
                for await result in group {
                    let (index, document, error) = result
                    loadedDocuments[index] = document
                    
                    if let error = error {
                        hasError = true
                        lastError = error
                    }
                }
            }
            
            // ✅ UI 업데이트 타이밍 개선
            await MainActor.run {
                print("📊 PDFPreviewModal: UI 업데이트 시작")
                
                // 1단계: 먼저 로딩 완료
                self.isLoading = false
                
                // 2단계: 약간의 지연 후 문서 설정 (UI 렌더링 타이밍 보장)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.pdfDocuments = loadedDocuments
                    
                    let successCount = loadedDocuments.compactMap { $0 }.count
                    print("📊 PDFPreviewModal: PDF 문서 설정 완료")
                    print("   - 성공: \(successCount) / \(self.pdfPaths.count)")
                    
                    if hasError && loadedDocuments.allSatisfy({ $0 == nil }) {
                        // 모든 PDF 로드 실패
                        self.errorMessage = "PDF 로드 실패: \(lastError?.localizedDescription ?? "알 수 없는 오류")"
                        print("❌ PDFPreviewModal: 모든 PDF 로드 실패")
                    } else if hasError {
                        // 일부 PDF 로드 실패
                        print("⚠️ PDFPreviewModal: 일부 PDF 로드 실패")
                    }
                    
                    // ✅ 3단계: 강제 뷰 업데이트
                    self.currentIndex = self.currentIndex // 강제 업데이트 트리거
                    
                    print("✅ PDFPreviewModal: 전체 로드 프로세스 완료")
                }
            }
        }
    }
    
    // MARK: - ✅ PDF 다운로드 (기존과 동일)
    
    private func downloadPDFData(from path: String) async throws -> Data {
        print("🔍 PDFPreviewModal: PDF 다운로드 시작")
        print("   - 입력 경로: '\(path)'")
        
        let fullURL = path.fullImageURL
        print("   - 생성된 fullURL: '\(fullURL)'")
        
        guard !fullURL.isEmpty else {
            print("   ❌ fullURL이 비어있음")
            throw PDFError.downloadFailed
        }
        
        guard let url = URL(string: fullURL) else {
            print("   ❌ URL 생성 실패")
            throw PDFError.downloadFailed
        }
        
        // URLRequest 구성
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30.0
        
        // 인증 헤더 추가
        if let accessToken = TokenManager.shared.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: APIConstants.Header.authorization)
            print("   - Authorization 헤더 추가됨")
        } else {
            print("   - ⚠️ accessToken 없음")
        }
        request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
        print("   - SesacKey 헤더 추가됨")
        
        print("🌐 PDF HTTP 요청 시작: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📨 PDF HTTP 응답:")
                print("   - 상태 코드: \(httpResponse.statusCode)")
                print("   - 데이터 크기: \(data.count) bytes")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    print("   ❌ HTTP 에러 응답: \(httpResponse.statusCode)")
                    throw PDFError.downloadFailed
                }
                
                // PDF 데이터 검증
                if data.count < 100 {
                    print("   ❌ PDF 데이터가 너무 작음: \(data.count) bytes")
                    throw PDFError.invalidFormat
                }
                
                // PDF 헤더 검증
                if let headerString = String(data: data.prefix(4), encoding: .ascii),
                   headerString == "%PDF" {
                    print("   ✅ 유효한 PDF 파일 확인됨")
                } else {
                    print("   ⚠️ PDF 헤더 확인 불가")
                }
                
                print("   ✅ PDF 다운로드 성공: \(data.count) bytes")
                return data
                
            } else {
                print("   ❌ HTTP 응답이 아님: \(response)")
                throw PDFError.downloadFailed
            }
            
        } catch {
            print("   ❌ PDF 다운로드 실패: \(error)")
            throw PDFError.downloadFailed
        }
    }
}

// MARK: - ✅ PDFKit 래퍼 뷰 (iOS 16 호환)

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.backgroundColor = .white
        
        // ✅ iOS 16 호환: 줌 설정
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        pdfView.scaleFactor = 1.0
        
        print("✅ PDFKitView: PDF 뷰 생성됨")
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // PDF 문서가 변경될 때 업데이트
        if pdfView.document != document {
            pdfView.document = document
            print("✅ PDFKitView: PDF 문서 업데이트됨")
        }
    }
}

// MARK: - ✅ PDF 에러 타입

enum PDFError: LocalizedError {
    case fileNotFound
    case downloadFailed
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "PDF 파일을 찾을 수 없습니다"
        case .downloadFailed:
            return "PDF 다운로드에 실패했습니다"
        case .invalidFormat:
            return "올바르지 않은 PDF 형식입니다"
        }
    }
}
