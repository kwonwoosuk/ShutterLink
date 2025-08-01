//
//  PostDetailView.swift
//  ShutterLink
//
//  Created by 권우석 on 7/28/25.
//

import SwiftUI

struct PostDetailView: View {
    let postId: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var viewModel = PostDetailViewModel()
    @State private var commentText = ""
    @State private var replyingToComment: PostComment?
    @State private var editingComment: PostComment?
    @State private var showActionSheet = false
    @State private var showCommentActionSheet = false
    @State private var selectedComment: PostComment?
    @State private var isLikeAnimating = false
    
    var body: some View {
        ZStack {
            // 다크 테마 배경
            Color.black.ignoresSafeArea()
            
            if let post = viewModel.post {
                VStack(spacing: 0) {
                    // 게시글 내용
                    ScrollView {
                        VStack(spacing: 0) {
                            // 게시글 헤더
                            postHeaderSection(post: post)
                            
                            // 이미지 섹션
                            if !post.files.isEmpty {
                                imageSection(post: post)
                            }
                            
                            // 액션 버튼들
                            actionButtonsSection(post: post)
                            
                            // 좋아요 수
                            if post.likeCount > 0 {
                                likeCountSection(post: post)
                            }
                            
                            // 게시글 내용
                            contentSection(post: post)
                                                    
                            // 댓글 섹션
                            commentsSection(post: post)
                            
                            // 하단 여백
                            Color.clear.frame(height: 100)
                        }
                    }
                    
                    // 댓글 입력창
                    commentInputSection
                }
            } else if viewModel.isLoading {
                loadingSection
            } else if viewModel.errorMessage != nil {
                errorSection
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showActionSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .onAppear {
            router.hideTabBar()
            viewModel.loadPostDetail(postId: postId)
        }
        .onDisappear {
            router.showTabBar()
        }
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            postActionSheet
        }
        .actionSheet(isPresented: $showCommentActionSheet) {
            commentActionSheet
        }
    }
    
    // MARK: - Post Header Section
    
    private func postHeaderSection(post: Post) -> some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            if let profileImagePath = post.creator.profileImage, !profileImagePath.isEmpty {
                AuthenticatedImageView(
                    imagePath: profileImagePath,
                    contentMode: .fill,
                    targetSize: CGSize(width: 40, height: 40)
                ) {
                    Circle()
                        .fill(Color.gray75)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.6)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray60)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    )
            }
            
            // 사용자 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(post.creator.nick)
                    .font(.pretendard(size: 14, weight: .semiBold))
                    .foregroundColor(.white)
                
                if !post.category.isEmpty {
                    Text(post.category)
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Image Section
    
    private func imageSection(post: Post) -> some View {
        TabView {
            ForEach(Array(post.files.enumerated()), id: \.offset) { index, imagePath in
                AuthenticatedImageView(
                    imagePath: imagePath,
                    contentMode: .fill,
                    targetSize: CGSize(width: UIScreen.main.bounds.width, height: 400)
                ) {
                    Rectangle()
                        .fill(Color.gray90)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .frame(height: 400)
                .clipped()
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: post.files.count > 1 ? .automatic : .never))
        .frame(height: 400)
        .background(Color.gray90)
    }
    
    // MARK: - Action Buttons Section
    
    private func actionButtonsSection(post: Post) -> some View {
        HStack(spacing: 16) {
            // 좋아요 버튼
            Button {
                Task {
                    await viewModel.toggleLike()
                }
                withAnimation(.easeInOut(duration: 0.1)) {
                    isLikeAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isLikeAnimating = false
                }
            } label: {
                Image(systemName: post.isLike ? "heart.fill" : "heart")
                    .foregroundColor(post.isLike ? .red : .white)
                    .font(.system(size: 24, weight: .medium))
                    .scaleEffect(isLikeAnimating ? 1.2 : 1.0)
            }
            
            // 댓글 버튼
            Button {
                // 댓글 입력창으로 포커스
            } label: {
                Image(systemName: "message")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
            }
            
            // 공유 버튼
            Button {
                // 공유 기능
            } label: {
                Image(systemName: "paperplane")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
            }
            
            Spacer()
            
            // 북마크 버튼
            Button {
                // 북마크 기능
            } label: {
                Image(systemName: "bookmark")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Like Count Section
    
    private func likeCountSection(post: Post) -> some View {
        HStack {
            Text("좋아요 \(post.likeCount)개")
                .font(.pretendard(size: 14, weight: .semiBold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    // MARK: - Content Section
    
    private func contentSection(post: Post) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 제목
            if !post.title.isEmpty {
                HStack {
                    Text(post.title)
                        .font(.pretendard(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
            
            // 내용
            if !post.content.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(post.creator.nick)
                        .font(.pretendard(size: 14, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Text(post.content)
                        .font(.pretendard(size: 14, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    
    // MARK: - Comments Section
    
    private func commentsSection(post: Post) -> some View {
        VStack(spacing: 0) {
            // 댓글 헤더
            if !post.comments.isEmpty {
                HStack {
                    Text("댓글 \(post.comments.count)개")
                        .font(.pretendard(size: 16, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            // 댓글 목록
            ForEach(post.comments) { comment in
                commentCell(comment: comment)
            }
        }
    }
    
    private func commentCell(comment: PostComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 댓글 내용
            HStack(alignment: .top, spacing: 12) {
                // 댓글 작성자 프로필 이미지
                if let profileImagePath = comment.creator.profileImage, !profileImagePath.isEmpty {
                    AuthenticatedImageView(
                        imagePath: profileImagePath,
                        contentMode: .fill,
                        targetSize: CGSize(width: 32, height: 32)
                    ) {
                        Circle()
                            .fill(Color.gray75)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.5)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray60)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 댓글 텍스트
                    VStack(alignment: .leading, spacing: 2) {
                        Text(comment.creator.nick)
                            .font(.pretendard(size: 13, weight: .semiBold))
                            .foregroundColor(.white)
                        
                        if editingComment?.commentId == comment.commentId {
                            // 수정 모드
                            TextField("댓글 수정", text: $commentText)
                                .font(.pretendard(size: 14, weight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray75)
                                .cornerRadius(8)
                                .onAppear {
                                    commentText = comment.content
                                }
                        } else {
                            Text(comment.content)
                                .font(.pretendard(size: 14, weight: .regular))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    // 댓글 액션 (시간, 답글)
                    HStack(spacing: 16) {
                        if editingComment?.commentId == comment.commentId {
                            // 수정 모드 버튼들
                            HStack(spacing: 8) {
                                Button("취소") {
                                    editingComment = nil
                                    commentText = ""
                                }
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.gray60)
                                
                                Button("저장") {
                                    saveEditedComment(comment)
                                }
                                .font(.pretendard(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        } else {
                            Button {
                                replyingToComment = comment
                            } label: {
                                Text("답글 달기")
                                    .font(.pretendard(size: 12, weight: .medium))
                                    .foregroundColor(.gray60)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .onLongPressGesture {
                // 본인 댓글만 수정/삭제 가능
                if comment.creator.userId == TokenManager.shared.getCurrentUserId() {
                    selectedComment = comment
                    showCommentActionSheet = true
                }
            }
            
            // 대댓글들
            if !comment.replies.isEmpty {
                VStack(spacing: 8) {
                    ForEach(comment.replies) { reply in
                        replyCell(reply: reply)
                    }
                }
                .padding(.leading, 44) // 프로필 이미지 + 간격만큼 들여쓰기
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func replyCell(reply: PostReply) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 대댓글 작성자 프로필 이미지
            if let profileImagePath = reply.creator.profileImage, !profileImagePath.isEmpty {
                AuthenticatedImageView(
                    imagePath: profileImagePath,
                    contentMode: .fill,
                    targetSize: CGSize(width: 28, height: 28)
                ) {
                    Circle()
                        .fill(Color.gray75)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.4)
                        )
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray60)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 대댓글 텍스트
                VStack(alignment: .leading, spacing: 2) {
                    Text(reply.creator.nick)
                        .font(.pretendard(size: 13, weight: .semiBold))
                        .foregroundColor(.white)
                    
                    if editingComment?.commentId == reply.commentId {
                        // 수정 모드
                        TextField("답글 수정", text: $commentText)
                            .font(.pretendard(size: 13, weight: .regular))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray75)
                            .cornerRadius(8)
                            .onAppear {
                                commentText = reply.content
                            }
                    } else {
                        Text(reply.content)
                            .font(.pretendard(size: 13, weight: .regular))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // 대댓글 시간 및 수정 버튼들
                HStack(spacing: 16) {
                    if editingComment?.commentId == reply.commentId {
                        // 수정 모드 버튼들
                        HStack(spacing: 8) {
                            Button("취소") {
                                editingComment = nil
                                commentText = ""
                            }
                            .font(.pretendard(size: 11, weight: .medium))
                            .foregroundColor(.gray60)
                            
                            Button("저장") {
                                saveEditedReply(reply)
                            }
                            .font(.pretendard(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .onLongPressGesture {
            // 본인 댓글만 수정/삭제 가능
            if reply.creator.userId == TokenManager.shared.getCurrentUserId() {
                // PostReply를 PostComment로 변환하여 선택
                selectedComment = PostComment(
                    id: reply.commentId,
                    commentId: reply.commentId,
                    content: reply.content,
                    createdAt: reply.createdAt,
                    creator: reply.creator,
                    replies: []
                )
                showCommentActionSheet = true
            }
        }
    }
    
    private func saveEditedReply(_ reply: PostReply) {
        let trimmedContent = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        Task {
            do {
                _ = try await viewModel.updateComment(
                    commentId: reply.commentId,
                    content: trimmedContent
                )
                
                await MainActor.run {
                    editingComment = nil
                    commentText = ""
                    
                    viewModel.loadPostDetail(postId: postId)
                }
            } catch {
                await MainActor.run {
                    viewModel.setError("답글 수정에 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Comment Input Section
    
    private var commentInputSection: some View {
        VStack(spacing: 0) {
            // 답글 또는 수정 표시
            if let replyingComment = replyingToComment {
                HStack {
                    Text("\(replyingComment.creator.nick)님에게 답글")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button {
                        replyingToComment = nil
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray90)
            }
            
            if let editingComment = editingComment {
                HStack {
                    Text("댓글 수정 중")
                        .font(.pretendard(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button {
                        self.editingComment = nil
                        commentText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray90)
            }
            
            // 댓글 입력창
            HStack(spacing: 12) {
                TextField(getPlaceholderText(), text: $commentText)
                    .font(.pretendard(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.gray90)
                    .cornerRadius(20)
                
                Button {
                    if editingComment != nil {
                        // 수정 모드에서는 직접 저장
                        if let comment = editingComment {
                            saveEditedComment(comment)
                        }
                    } else {
                        // 일반 댓글/답글 작성
                        postComment()
                    }
                } label: {
                    Text(editingComment != nil ? "수정" : "게시")
                        .font(.pretendard(size: 14, weight: .semiBold))
                        .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)
        }
    }
    
    private func getPlaceholderText() -> String {
        if editingComment != nil {
            return "댓글 수정..."
        } else if replyingToComment != nil {
            return "답글 추가..."
        } else {
            return "댓글 추가..."
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("게시글을 불러오는 중...")
                .font(.pretendard(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.top, 12)
        }
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("게시글을 불러올 수 없습니다")
                .font(.pretendard(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                viewModel.loadPostDetail(postId: postId)
            } label: {
                Text("다시 시도")
                    .font(.pretendard(size: 14, weight: .semiBold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray90)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Action Sheet
    
    private var postActionSheet: ActionSheet {
        let isMyPost = viewModel.post?.creator.userId == TokenManager.shared.getCurrentUserId()
        
        var buttons: [ActionSheet.Button] = []
        
        if isMyPost {
            buttons.append(.default(Text("수정하기")) {
                if let post = viewModel.post {
                    router.pushToEditPost(post: post)
                }
            })
            
            buttons.append(.destructive(Text("삭제하기")) {
                viewModel.deletePost()
            })
        } else {
            buttons.append(.default(Text("신고하기")) {
                // 신고 기능,,,
            })
        }
        
        buttons.append(.cancel(Text("취소")))
        
        return ActionSheet(title: Text("게시글 옵션"), buttons: buttons)
    }
    
    private var commentActionSheet: ActionSheet {
        ActionSheet(
            title: Text("댓글 옵션"),
            buttons: [
                .default(Text("수정하기")) {
                    if let comment = selectedComment {
                        editingComment = comment
                        commentText = comment.content
                    }
                },
                .destructive(Text("삭제하기")) {
                    if let comment = selectedComment {
                        deleteComment(comment)
                    }
                },
                .cancel(Text("취소"))
            ]
        )
    }
    
    // MARK: - Methods
    
    private func postComment() {
        let trimmedComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }
        
        Task {
            do {
                let parentCommentId = replyingToComment?.commentId
                let newComment = try await viewModel.createComment(
                    content: trimmedComment,
                    parentCommentId: parentCommentId
                )
                
                await MainActor.run {
                    commentText = ""
                    replyingToComment = nil
                    
                    // 게시글 다시 로드하여 새 댓글 표시
                    viewModel.loadPostDetail(postId: postId)
                }
            } catch {
                await MainActor.run {
                    viewModel.setError("댓글 작성에 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveEditedComment(_ comment: PostComment) {
        let trimmedContent = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        Task {
            do {
                _ = try await viewModel.updateComment(
                    commentId: comment.commentId,
                    content: trimmedContent
                )
                
                await MainActor.run {
                    editingComment = nil
                    commentText = ""
                    
                    viewModel.loadPostDetail(postId: postId)
                }
            } catch {
                await MainActor.run {
                    viewModel.setError("댓글 수정에 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteComment(_ comment: PostComment) {
        Task {
            do {
                try await viewModel.deleteComment(commentId: comment.commentId)
                
                await MainActor.run {
                    viewModel.loadPostDetail(postId: postId)
                }
            } catch {
                await MainActor.run {
                    viewModel.setError("댓글 삭제에 실패했습니다: \(error.localizedDescription)")
                }
            }
        }
    }
}


