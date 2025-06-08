//
//  EditingStateManager.swift
//  ShutterLink
//
//  Created by 권우석 on 6/7/25.
//

import Foundation
import SwiftUI

final class EditingStateManager: ObservableObject {
    private var undoStack: [EditingState] = []
    private var redoStack: [EditingState] = []
    
    @Published var currentState: EditingState = EditingState.defaultState
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    private let maxHistoryCount = 50
    
    init() {
        updateButtonStates()
        print("🎛️ EditingStateManager: 초기화됨")
    }
    
    // MARK: - 최적화된 상태 저장 (드래그 완료 시에만 호출)
    func saveStateToUndoStack(_ state: EditingState) {
        // 현재 상태와 동일하면 저장하지 않음
        if state == currentState {
            return
        }
        
        // 이전 상태를 undo 스택에 저장
        undoStack.append(state)
        
        // redo 스택 초기화 (새로운 변경이 있으면 redo 불가)
        redoStack.removeAll()
        
        // 히스토리 크기 제한
        if undoStack.count > maxHistoryCount {
            undoStack.removeFirst()
        }
        
        updateButtonStates()
        
        print("🎛️ EditingStateManager: 상태 저장됨 - Undo: \(undoStack.count), Redo: \(redoStack.count)")
    }
    
    // MARK: - 기존 저장 메서드 (호환성 유지)
    func saveState(_ state: EditingState) {
        saveStateToUndoStack(currentState)
        currentState = state
    }
    
    func undo() {
        guard let previousState = undoStack.popLast() else {
            print("⚠️ EditingStateManager: Undo 스택이 비어있음")
            return
        }
        
        // 현재 상태를 redo 스택에 저장
        redoStack.append(currentState)
        currentState = previousState
        
        updateButtonStates()
        
        print("🔄 EditingStateManager: Undo 실행 - Undo: \(undoStack.count), Redo: \(redoStack.count)")
    }
    
    func redo() {
        guard let nextState = redoStack.popLast() else {
            print("⚠️ EditingStateManager: Redo 스택이 비어있음")
            return
        }
        
        // 현재 상태를 undo 스택에 저장
        undoStack.append(currentState)
        currentState = nextState
        
        updateButtonStates()
        
        print("🔄 EditingStateManager: Redo 실행 - Undo: \(undoStack.count), Redo: \(redoStack.count)")
    }
    
    func resetToDefault() {
        print("🔄 EditingStateManager: 기본값으로 리셋 시작")
        
        // 현재 상태가 기본 상태가 아니라면 undo 스택에 저장
        if currentState != EditingState.defaultState {
            saveStateToUndoStack(currentState)
        }
        
        currentState = EditingState.defaultState
        
        print("✅ EditingStateManager: 기본값으로 리셋 완료 - Undo: \(undoStack.count), Redo: \(redoStack.count)")
    }
    
    private func updateButtonStates() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    // MARK: - 디버깅 메서드
    func printCurrentState() {
        print("🎛️ EditingStateManager 현재 상태:")
        print("   Undo 스택: \(undoStack.count)개")
        print("   Redo 스택: \(redoStack.count)개")
        print("   Undo 가능: \(canUndo)")
        print("   Redo 가능: \(canRedo)")
    }
}

// MARK: - CoreImage 호환 확장
extension EditingStateManager {
    func getCurrentStateForCoreImage() -> EditingState {
        return currentState
    }
    
    func updateCurrentState(_ state: EditingState) {
        currentState = state
    }
}
