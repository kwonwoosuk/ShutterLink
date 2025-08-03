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
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasAppeared = false
    
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
                
                if hasAppeared {
                    if isLoading {
                        loadingView
                    } else if let errorMessage = errorMessage {
                        errorView(message: errorMessage)
                    } else if !pdfDocuments.isEmpty {
                        pdfContentView()
                    } else {
                        emptyView
                    }
                } else {
                    // 초기 로딩 상태
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("PDF 준비 중...")
                            .foregroundColor(.white)
                            .font(.pretendard(size: 16, weight: .medium))
                    }
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
                        print("🖱️ PDF 닫기 버튼 탭됨")
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasAppeared && !isLoading && pdfDocuments.indices.contains(currentIndex),
                       let pdfDocument = pdfDocuments[currentIndex] {
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
                loadPDFs()
                print("✅ PDFPreviewModal 로딩 시작")
            }
        }
        .onDisappear {
            print("👋 PDFPreviewModal onDisappear")
            hasAppeared = false
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
                print("🔄 PDF 다시 시도 버튼 탭됨")
                loadPDFs()
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
        }
    }
    
    // MARK: - ✅ PDF 콘텐츠 뷰
    
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
                    } else {
                        // 로딩 실패한 PDF
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            
                            Text("PDF 로드 실패")
                                .foregroundColor(.white)
                                .font(.pretendard(size: 16, weight: .medium))
                            
                            Button("다시 시도") {
                                retryLoadPDF(at: index)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentIndex) { newIndex in
                print("📄 PDF 페이지 변경됨: \(newIndex)")
            }
        }
    }
    
    // MARK: - ✅ PDF 로드 (강화된 에러 처리)
    
    private func loadPDFs() {
        guard !pdfPaths.isEmpty else {
            print("❌ pdfPaths가 비어있음!")
            errorMessage = "표시할 PDF가 없습니다"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        pdfDocuments = Array(repeating: nil, count: pdfPaths.count)
        
        Task {
            var loadedDocuments: [PDFDocument?] = Array(repeating: nil, count: pdfPaths.count)
            var hasError = false
            var lastError: Error?
        
            await withTaskGroup(of: (Int, PDFDocument?, Error?).self) { group in
                for (index, pdfPath) in pdfPaths.enumerated() {
                    group.addTask {
                        print("📄 PDF 로딩 시작 [\(index)]: \(pdfPath)")
                        
                        do {
                            let data = try await downloadPDFData(from: pdfPath)
                            
                            guard let document = PDFDocument(data: data) else {
                                print("❌ PDF 문서 생성 실패 [\(index)]: \(pdfPath)")
                                throw PDFError.invalidFormat
                            }
                            
                            print("✅ PDF 로딩 성공 [\(index)]: \(pdfPath)")
                            return (index, document, nil)
                            
                        } catch {
                            print("❌ PDF 로딩 실패 [\(index)]: \(error)")
                            return (index, nil, error)
                        }
                    }
                }
                
                // 결과
                for await (index, document, error) in group {
                    loadedDocuments[index] = document
                    if let error = error {
                        hasError = true
                        lastError = error
                    }
                }
            }
            
            await MainActor.run {
                self.pdfDocuments = loadedDocuments
                
                // 에러 처리
                if loadedDocuments.allSatisfy({ $0 == nil }) {
                    // 모든 PDF 로드 실패
                    self.errorMessage = "PDF 로드에 실패했습니다: \(lastError?.localizedDescription ?? "알 수 없는 오류")"
                    print("❌ 모든 PDF 로드 실패")
                } else if hasError {
                    // 일부 PDF 로드 실패
                    print("⚠️ 일부 PDF 로드 실패")
                }
                
                self.isLoading = false
                print("✅ PDF 로드 완료 - \(loadedDocuments.compactMap { $0 }.count)/\(pdfPaths.count)")
            }
        }
    }
    
    // MARK: - ✅ 개별 PDF 재시도 로딩
    
    private func retryLoadPDF(at index: Int) {
        guard pdfPaths.indices.contains(index) else { return }
        
        print("🔄 PDF 재시도 로딩 [\(index)]: \(pdfPaths[index])")
        
        Task {
            do {
                let data = try await downloadPDFData(from: pdfPaths[index])
                
                guard let document = PDFDocument(data: data) else {
                    throw PDFError.invalidFormat
                }
                
                await MainActor.run {
                    self.pdfDocuments[index] = document
                    print("✅ PDF 재시도 성공 [\(index)]")
                }
                
            } catch {
                print("❌ PDF 재시도 실패 [\(index)]: \(error)")
            }
        }
    }
    
    // MARK: - ✅ PDF 다운로드
    
    private func downloadPDFData(from path: String) async throws -> Data {
        print("🔍 PDF 다운로드 시작:")
        print("   - 입력 경로: '\(path)'")
        
        let fullURL = path.fullImageURL
        print("   - 생성된 fullURL: '\(fullURL)'")
        
        guard let url = URL(string: fullURL) else {
            print("   ❌ URL 생성 실패")
            throw PDFError.downloadFailed
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30.0
        
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
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("   - 응답 내용: \(responseString.prefix(200))")
                    }
                    throw PDFError.downloadFailed
                }
                
                if data.count < 100 {
                    print("   ❌ PDF 데이터가 너무 작음: \(data.count) bytes")
                    throw PDFError.invalidFormat
                }
                
                if let headerString = String(data: data.prefix(4), encoding: .ascii),
                   headerString == "%PDF" {
                    print("   ✅ 유효한 PDF 파일 확인됨")
                } else {
                    print("   ⚠️ PDF 헤더 확인 불가, 하지만 계속 진행")
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

// MARK: - ✅ PDFKit 래퍼 뷰 

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
        
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        pdfView.scaleFactor = 1.0
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // PDF 문서가 변경될 때 업데이트
        if pdfView.document != document {
            pdfView.document = document
            print("🔄 PDFKitView 업데이트됨")
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
