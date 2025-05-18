//
//  DesignSystem.swift
//  ShutterLink
//
//  Created by 권우석 on 5/18/25.
//

import SwiftUI

enum DesignSystem {
    enum Typography {
        enum FontFamily {
            case pretendard(weight: PretendardWeight)
            case hakgyoansim(weight: HakgyoansimWeight)
            
            enum PretendardWeight {
                case thin, extraLight, light, regular, medium, semiBold, bold, extraBold, black
                
                var value: String {
                    switch self {
                    case .thin: return "Pretendard-Thin"
                    case .extraLight: return "Pretendard-ExtraLight"
                    case .light: return "Pretendard-Light"
                    case .regular: return "Pretendard-Regular"
                    case .medium: return "Pretendard-Medium"
                    case .semiBold: return "Pretendard-SemiBold"
                    case .bold: return "Pretendard-Bold"
                    case .extraBold: return "Pretendard-ExtraBold"
                    case .black: return "Pretendard-Black"
                    }
                }
            }
            
            enum HakgyoansimWeight {
                case regular, bold
                
                var value: String {
                    switch self {
                    case .regular: return "TTHakgyoansimMulgyeolR"
                    case .bold: return "TTHakgyoansimMulgyeolB"
                    }
                }
            }
            
            var fontName: String {
                switch self {
                case .pretendard(let weight): return weight.value
                case .hakgyoansim(let weight): return weight.value
                }
            }
        }
        
        enum TextStyle {
            // Pretendard 스타일
            case title1
            case body1, body2, body3
            case caption1, caption2, caption3
            
            // 학교안심 물결체 스타일
            case mulgyeolTitle1
            case mulgyeolBody1
            case mulgyeolCaption1
            
            func font() -> Font {
                switch self {
                // Pretendard
                case .title1: return .custom(FontFamily.pretendard(weight: .bold).fontName, size: 20)
                case .body1: return .custom(FontFamily.pretendard(weight: .regular).fontName, size: 16)
                case .body2: return .custom(FontFamily.pretendard(weight: .regular).fontName, size: 14)
                case .body3: return .custom(FontFamily.pretendard(weight: .regular).fontName, size: 13)
                case .caption1: return .custom(FontFamily.pretendard(weight: .regular).fontName, size: 12)
                case .caption2: return .custom(FontFamily.pretendard(weight: .regular).fontName, size: 10)
                case .caption3: return .custom(FontFamily.pretendard(weight: .regular).fontName, size: 8)
                    
                // 학교안심 물결체
                case .mulgyeolTitle1: return .custom(FontFamily.hakgyoansim(weight: .bold).fontName, size: 32)
                case .mulgyeolBody1: return .custom(FontFamily.hakgyoansim(weight: .regular).fontName, size: 20)
                case .mulgyeolCaption1: return .custom(FontFamily.hakgyoansim(weight: .regular).fontName, size: 14)
                }
            }
        }
    }
    
    enum Colors {
        enum Brand {
            static let blackTurquoise = Color("BlackTurquoiseColor")
            static let deepTurquoise = Color("DeepTurquoiseColor")
            static let brightTurquoise = Color("BrightTurquoiseColor")
        }
        
        enum Gray {
            static let gray0 = Color("Gray0Color")
            static let gray15 = Color("Gray15Color")
            static let gray30 = Color("Gray30Color")
            static let gray45 = Color("Gray45Color")
            static let gray60 = Color("Gray60Color")
            static let gray75 = Color("Gray75Color")
            static let gray90 = Color("Gray90Color")
            static let gray100 = Color("Gray100Color")
        }
    }
    
    enum Icons {
        // 탭바 아이콘
        enum TabBar {
            static let homeEmpty = Image("Home_Empty")
            static let homeFill = Image("Home_Fill")
            static let profileEmpty = Image("Profile_Empty")
            static let profileFill = Image("Profile_Fill")
            static let feedEmpty = Image("Feed_Empty")
            static let feedFill = Image("Feed_Fill")
            static let searchEmpty = Image("Search_Empty")
            static let searchFill = Image("Search_Fill")
            static let filterEmpty = Image("Filter_Empty")
            static let filterFill = Image("Filter_Fill")
        }
        
        enum Action {
            static let add = Image("Add")
            static let likeEmpty = Image("Like_Empty")
            static let likeFill = Image("Like_Fill")
            static let save = Image("Save")
            static let message = Image("Message")
            static let undo = Image("Undo")
            static let redo = Image("Redo")
            static let lock = Image("Lock")
        }
        
        enum Editor {
            static let brightness = Image("Brightness")
            static let contrast = Image("Contrast")
            static let exposure = Image("Exposure")
            static let highlights = Image("Highlights")
            static let shadows = Image("Shadows")
            static let saturation = Image("Saturation")
            static let temperature = Image("Temperature")
            static let sharpness = Image("Sharpness")
            static let vignette = Image("Vignette")
            static let blur = Image("Blur")
            static let noise = Image("Noise")
            static let compare = Image("Compare")
        }
        
        enum Category {
            static let landscape = Image("Landscape")
            static let people = Image("People")
            static let food = Image("Food")
            static let night = Image("Night")
        }
        
        enum UI {
            static let blackPoint = Image("BlackPoint")
            static let chevron = Image("chevron")
            static let noLocation = Image("NoLocation")
            static let star = Image("Star")
        }
    }
}
