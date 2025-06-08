//
//  NotificationHandler.swift
//  ShutterLink
//
//  Created by 권우석 on 5/18/25.
//


import SwiftUI
import UserNotifications

final class NotificationHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 앱이 포그라운드에 있을 때도 알림 표시
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 알림 탭 시 처리
        completionHandler()
    }
}
