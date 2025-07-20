//
//  BridgeWebView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/19/25.
//

import SwiftUI
import WebKit

struct BridgeWebView: UIViewRepresentable {
    let url: URL
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // 메시지 핸들러 등록
        userContentController.add(context.coordinator, name: "click_attendance_button")
        userContentController.add(context.coordinator, name: "complete_attendance")
        
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        var request = URLRequest(url: url)
        request.setValue(Key.ShutterLink.apiKey.rawValue, forHTTPHeaderField: APIConstants.Header.sesacKey)
        
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 업데이트 X
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: BridgeWebView
        private let tokenManager = TokenManager.shared
        
        init(_ parent: BridgeWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("🌐 BridgeWebView: 메시지 수신 - \(message.name)")
            
            switch message.name {
            case "click_attendance_button":
                handleAttendanceButtonClick(webView: message.webView)
                
            case "complete_attendance":
                handleAttendanceComplete(message: message)
                
            default:
                print("⚠️ BridgeWebView: 알 수 없는 메시지 - \(message.name)")
            }
        }
        
        // MARK: - 출석 버튼 클릭 처리
        private func handleAttendanceButtonClick(webView: WKWebView?) {
            print("🔵 BridgeWebView: 출석 버튼 클릭 처리")
            
            guard let accessToken = tokenManager.accessToken else {
                print("❌ BridgeWebView: 액세스 토큰이 없습니다")
                return
            }
            
            // 웹으로 액세스 토큰 전달
            webView?.evaluateJavaScript("requestAttendance('\(accessToken)')") { result, error in
                if let error = error {
                    print("❌ BridgeWebView: JavaScript 실행 실패 - \(error)")
                } else {
                    print("✅ BridgeWebView: 액세스 토큰 전달 성공")
                }
            }
        }
        
        // MARK: - 출석 완료 처리
        private func handleAttendanceComplete(message: WKScriptMessage) {
            print("🎉 BridgeWebView: 출석 완료")
            
            if let attendanceCount = message.body as? Int {
                print("📊 출석 횟수: \(attendanceCount)")
                
                // NotificationCenter를 통해 HomeView에 알림 발송
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    print("📢 BridgeWebView: NotificationCenter 알림 발송 시작")
                    print("   - 알림 이름: AttendanceCompleted")
                    print("   - 출석 횟수: \(attendanceCount)")
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AttendanceCompleted"),
                        object: nil,
                        userInfo: ["attendanceCount": attendanceCount]
                    )
                    
                    print("✅ BridgeWebView: NotificationCenter 알림 발송 완료")
                }
            } else {
                print("⚠️ BridgeWebView: 출석 횟수 파싱 실패")
                
                // 출석 횟수가 없어도 완료 알림
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AttendanceCompleted"),
                        object: nil,
                        userInfo: ["attendanceCount": 0]
                    )
                }
            }
        }
        
        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🌐 BridgeWebView: 웹페이지 로딩 시작")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ BridgeWebView: 웹페이지 로딩 완료")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ BridgeWebView: 웹페이지 로딩 실패 - \(error)")
        }
    }
}

// MARK: - BridgeWebView 시트
struct BridgeWebViewSheet: View {
    let url: URL
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            BridgeWebView(url: url, isPresented: $isPresented, onDismiss: onDismiss)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("닫기") {
                            onDismiss()
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
