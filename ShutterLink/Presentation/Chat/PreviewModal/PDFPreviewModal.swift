//
//  PDFPreviewModal.swift
//  ShutterLink
//
//  Created by 권우석 on 8/2/25.
//

import SwiftUI
import PDFKit

struct PDFPreviewModal: View {
    let pdfPaths: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    @State private var pdfDocuments: [PDFDocument?] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
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
                } else if !pdfDocuments.isEmpty {
                    pdfContentView()
                } else {
                    emptyView
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if pdfDocuments.indices.contains(currentIndex),
                       let pdfDocument = pdfDocuments[currentIndex] {
                        Menu {
                            Button(action: {
                                sharePDF()
                            }) {
                                Label("공유", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadPDFs()
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
    
    // MARK: - ✅ PDF 콘텐츠 뷰 (여러 PDF 지원)
    
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
    
    // MARK: - ✅ PDF 로드 (여러 PDF 병렬 처리)
    
    private func loadPDFs() {
        isLoading = true
        errorMessage = nil
        pdfDocuments = Array(repeating: nil, count: pdfPaths.count)
        
        Task {
            var loadedDocuments: [PDFDocument?] = Array(repeating: nil, count: pdfPaths.count)
            var hasError = false
            var lastError: Error?
            
            // ✅ 모든 PDF를 병렬로 로드
            await withTaskGroup(of: (Int, PDFDocument?, Error?).self) { group in
                for (index, path) in pdfPaths.enumerated() {
                    group.addTask {
                        do {
                            let pdfData = try await downloadPDFData(from: path)
                            let document = PDFDocument(data: pdfData)
                            return (index, document, nil)
                        } catch {
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
                self.pdfDocuments = loadedDocuments
                
                if hasError && loadedDocuments.allSatisfy({ $0 == nil }) {
                    // 모든 PDF 로드 실패
                    self.errorMessage = "PDF 로드 실패: \(lastError?.localizedDescription ?? "알 수 없는 오류")"
                } else if hasError {
                    // 일부 PDF 로드 실패
                    print("⚠️ PDFPreviewModal: 일부 PDF 로드 실패")
                }
                
                self.isLoading = false
                print("✅ PDFPreviewModal: PDF 로드 완료 - \(loadedDocuments.compactMap { $0 }.count)/\(pdfPaths.count)")
            }
        }
    }
    
    // MARK: - ✅ PDF 다운로드 (임시 구현)
    
    private func downloadPDFData(from path: String) async throws -> Data {
        // TODO: 실제 구현에서는 네트워크 서비스를 통해 PDF 데이터를 가져와야 함
        // 예시: NetworkManager.shared.downloadFile(path)
        
        // 임시 구현 - 번들에서 샘플 PDF 로드
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
              let data = try? Data(contentsOf: url) else {
            throw PDFError.fileNotFound
        }
        
        // 실제 네트워크 지연 시뮬레이션
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5초
        
        return data
    }
    
    // MARK: - ✅ 공유 기능
    
    private func sharePDF() {
        guard pdfDocuments.indices.contains(currentIndex),
              let pdfDocument = pdfDocuments[currentIndex],
              let pdfData = pdfDocument.dataRepresentation() else {
            print("❌ PDFPreviewModal: 공유할 PDF 데이터 없음")
            return
        }
        
        let fileName = pdfPaths[currentIndex].components(separatedBy: "/").last ?? "document.pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
            
        } catch {
            print("❌ PDFPreviewModal: 공유 실패 - \(error)")
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
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // PDF 문서가 변경될 때 업데이트
        if pdfView.document != document {
            pdfView.document = document
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
