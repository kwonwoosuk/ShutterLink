//
//  Font+Extension.swift
//  ShutterLink
//
//  Created by 권우석 on 5/19/25.
//

import SwiftUI

extension Font {
    static func pretendard(size: CGFloat, weight: DesignSystem.Typography.FontFamily.PretendardWeight = .regular) -> Font {
        .custom(DesignSystem.Typography.FontFamily.pretendard(weight: weight).fontName, size: size)
    }
    
    static func hakgyoansim(size: CGFloat, weight: DesignSystem.Typography.FontFamily.HakgyoansimWeight = .regular) -> Font {
        .custom(DesignSystem.Typography.FontFamily.hakgyoansim(weight: weight).fontName, size: size)
    }
}


extension Text {
    func style(_ textStyle: DesignSystem.Typography.TextStyle) -> Text {
        self.font(textStyle.font())
    }
}
