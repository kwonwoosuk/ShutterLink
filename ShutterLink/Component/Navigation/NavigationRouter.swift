//
//  NavigationRouter.swift
//  ShutterLink
//
//  Created by 권우석 on 6/3/25.
//

import SwiftUI
import Combine

// MARK: - 네비게이션 라우터
class NavigationRouter: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedTab: Tab = .home
    @Published var homePath: [FilterRoute] = []
    @Published var feedPath: [FilterRoute] = []
    @Published var searchPath: [UserRoute] = []
    @Published var profilePath: [ProfileRoute] = []
    @Published var makePath: [MakeRoute] = []
    
    // MARK: - Sheet States
    @Published var presentedSheet: PresentedSheet?
    
    // MARK: - Scroll to Top Subjects
    let homeScrollToTop = PassthroughSubject<Void, Never>()
    let feedScrollToTop = PassthroughSubject<Void, Never>()
    let searchScrollToTop = PassthroughSubject<Void, Never>()
    let profileScrollToTop = PassthroughSubject<Void, Never>()
    let makeScrollToTop = PassthroughSubject<Void, Never>()
    
    // MARK: - Singleton
    static let shared = NavigationRouter()
    private init() {}
    
    // MARK: - Tab Management
    func selectTab(_ tab: Tab) {
        if selectedTab == tab {
            // 같은 탭을 다시 선택한 경우 - 초기화
            popToRootForCurrentTab()
            triggerScrollToTopForCurrentTab()
        } else {
            // 다른 탭으로 이동
            selectedTab = tab
        }
    }
    
    private func popToRootForCurrentTab() {
        print("🔄 NavigationRouter: \(selectedTab.title) 탭 초기화")
        
        switch selectedTab {
        case .home:
            homePath.removeAll()
        case .feed:
            feedPath.removeAll()
        case .search:
            searchPath.removeAll()
        case .profile:
            profilePath.removeAll()
        case .filter:
            makePath.removeAll()
        }
    }
    
    private func triggerScrollToTopForCurrentTab() {
        switch selectedTab {
        case .home:
            homeScrollToTop.send()
        case .feed:
            feedScrollToTop.send()
        case .search:
            searchScrollToTop.send()
        case .profile:
            profileScrollToTop.send()
        case .filter:
            makeScrollToTop.send()
        }
    }
    
    // MARK: - Navigation Actions for Filter Routes (Home/Feed)
    func pushToFilterDetail(filterId: String, from tab: Tab = .home) {
        let route = FilterRoute.filterDetail(filterId: filterId)
        
        switch tab {
        case .home:
            homePath.append(route)
        case .feed:
            feedPath.append(route)
        default:
            print("⚠️ NavigationRouter: 잘못된 탭에서 필터 라우트 호출")
        }
        
        print("🧭 NavigationRouter: 필터 상세로 이동 - \(filterId)")
    }
    
    func popFilterRoute(from tab: Tab = .home) {
        switch tab {
        case .home:
            if !homePath.isEmpty {
                homePath.removeLast()
            }
        case .feed:
            if !feedPath.isEmpty {
                feedPath.removeLast()
            }
        default:
            break
        }
    }
    
    func popToRootFilter(from tab: Tab = .home) {
        switch tab {
        case .home:
            homePath.removeAll()
        case .feed:
            feedPath.removeAll()
        default:
            break
        }
    }
    
    // MARK: - Navigation Actions for User Routes (Search)
    func pushToUserDetail(userId: String, userInfo: UserInfo?) {
        // 중복 방지를 위한 검사
        if case .userDetail(let currentUserId, _) = searchPath.last {
            if currentUserId == userId {
                print("⚠️ NavigationRouter: 이미 같은 유저 상세 화면에 있음 - \(userId)")
                return
            }
        }
        
        let route = UserRoute.userDetail(userId: userId, userInfo: userInfo)
        searchPath.append(route)
        print("🧭 NavigationRouter: 유저 상세로 이동 - \(userId)")
    }
    
    func pushToUserFilters(userId: String, userNick: String) {
        let route = UserRoute.userFilters(userId: userId, userNick: userNick)
        searchPath.append(route)
        print("🧭 NavigationRouter: 유저 필터 목록으로 이동 - \(userId)")
    }
    
    func pushToUserDetailFromFilter(userId: String, userInfo: CreatorInfo, from tab: Tab = .home) {
        // 중복 방지를 위한 검사
        let currentPath = tab == .home ? homePath : feedPath
        if case .userDetail(let currentUserId, _) = currentPath.last {
            if currentUserId == userId {
                print("⚠️ NavigationRouter: 이미 같은 유저 상세 화면에 있음 - \(userId)")
                return
            }
        }
        
        let route = FilterRoute.userDetail(userId: userId, userInfo: userInfo)
        
        switch tab {
        case .home:
            homePath.append(route)
        case .feed:
            feedPath.append(route)
        default:
            print("⚠️ NavigationRouter: 잘못된 탭에서 유저 라우트 호출")
        }
        
        print("🧭 NavigationRouter: 유저 상세로 이동 - \(userId)")
    }
    
    func popUserRoute() {
        if !searchPath.isEmpty {
            searchPath.removeLast()
        }
    }
    
    func popToRootUser() {
        searchPath.removeAll()
    }
    
    // MARK: - Navigation Actions for Profile Routes (추가)
    func pushToEditProfile() {
        let route = ProfileRoute.editProfile
        profilePath.append(route)
        print("🧭 NavigationRouter: 프로필 편집으로 이동")
    }
    
    func pushToLikedFilters() {
        let route = ProfileRoute.likedFilters
        profilePath.append(route)
        print("🧭 NavigationRouter: 좋아요한 필터 목록으로 이동")
    }
    
    func pushToLikedFilterDetail(filterId: String) {
        let route = ProfileRoute.filterDetail(filterId: filterId)
        profilePath.append(route)
        print("🧭 NavigationRouter: 좋아요한 필터 상세로 이동 - \(filterId)")
    }
    
    func popProfileRoute() {
        if !profilePath.isEmpty {
            profilePath.removeLast()
        }
    }
    
    func popToRootProfile() {
        profilePath.removeAll()
    }
    
    // MARK: - Sheet Management
    func presentSheet(_ sheet: PresentedSheet) {
        presentedSheet = sheet
        print("🧭 NavigationRouter: Sheet 표시 - \(sheet)")
    }
    
    func dismissSheet() {
        presentedSheet = nil
        print("🧭 NavigationRouter: Sheet 닫기")
    }
    
    // MARK: - Utility Methods
    func getCurrentPathCount() -> Int {
        switch selectedTab {
        case .home:
            return homePath.count
        case .feed:
            return feedPath.count
        case .search:
            return searchPath.count
        case .profile:
            return profilePath.count
        case .filter:
            return makePath.count
        }
    }
    
    func canGoBack() -> Bool {
        return getCurrentPathCount() > 0
    }
    
    func pushToEditFilter(with originalImage: UIImage? = nil) {
          let route = MakeRoute.editFilter(originalImage: originalImage)
          makePath.append(route)
          print("🧭 NavigationRouter: 필터 편집으로 이동")
      }
      
      func popMakeRoute() {
          if !makePath.isEmpty {
              makePath.removeLast()
          }
      }
      
      func popToRootMake() {
          makePath.removeAll()
          print("🧭 NavigationRouter: Make 루트로 이동")
      }
    
    // MARK: - Debug Methods
    func printCurrentState() {
        print("🧭 NavigationRouter 현재 상태:")
        print("   선택된 탭: \(selectedTab.title)")
        print("   홈 경로: \(homePath.count)개")
        print("   피드 경로: \(feedPath.count)개")
        print("   검색 경로: \(searchPath.count)개")
        print("   프로필 경로: \(profilePath.count)개")
        print("   Sheet: \(presentedSheet?.description ?? "없음")")
    }
}

// MARK: - Sheet Types (기존과 동일)
enum PresentedSheet: Identifiable, CustomStringConvertible, Equatable  {
    case userFilters(userId: String, userNick: String)
    case profileEdit
    case chatView(userId: String)
    
    var id: String {
        switch self {
        case .userFilters(let userId, _):
            return "userFilters_\(userId)"
        case .profileEdit:
            return "profileEdit"
        case .chatView(let userId):
            return "chatView_\(userId)"
        }
    }
    
    var description: String {
        switch self {
        case .userFilters(_, let userNick):
            return "유저 필터 목록 (\(userNick))"
        case .profileEdit:
            return "프로필 편집"
        case .chatView:
            return "채팅 뷰"
        }
    }
}
