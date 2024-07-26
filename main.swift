import SwiftUI
import AVKit
import Kingfisher

struct CardView: View {
    private let screenSize = UIScreen.main.bounds
    @Binding var videoFile: VideoFile
    @Binding var isExpanded: Bool
    var animationID: Namespace.ID
    var isDetailsView: Bool = false
    
    init(videoFile: Binding<VideoFile>,
         isExpanded: Binding<Bool>,
         animationID: Namespace.ID,
         isDetailsView: Bool = false) {
        
        self._videoFile = videoFile
        self._isExpanded = isExpanded
        self.isDetailsView = isDetailsView
        self.animationID = animationID
    }
    
    var body: some View {
        GeometryReader {
            let size = $0.size

            if let imageURL = videoFile.imageURL {
                KFImage(URL(string: imageURL))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8.0))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8.0)
                            .stroke(.gray, lineWidth: 1.0)
                    }
                    .background(content: {
                        Rectangle()
                            .foregroundColor(.gray).opacity(0.2)
                            .overlay(content: {
                                ProgressView().scaleEffect(1.2)
                            })
                    })
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .scaleEffect(scale)
            } else if let thumbnail = videoFile.thumbnail, let player = videoFile.player {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .opacity(videoFile.playVideo ? 0 : 1)
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        if videoFile.playVideo && isDetailsView {
                            CustomVideoPlayer(player: player)
                                .transition(.identity)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .scaleEffect(scale)
            } else {
                Rectangle()
                    .foregroundColor(.gray).opacity(0.2)
                    .overlay(content: {
                        ProgressView().scaleEffect(1.2)
                    })
                    .onAppear {
                        if let f_url = videoFile.fileURL {
                            extractImageAt(f_url: f_url, time: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)) { thumbnail in
                                videoFile.thumbnail = thumbnail
                            }
                        }
                    }
            }
        }
        .matchedGeometryEffect(id: videoFile.id.uuidString, in: animationID)
        .offset(videoFile.offset)
        .offset(y: videoFile.offset.height * -0.7)
    }
    
    private var scale: CGFloat {
        var yOffset = videoFile.offset.height
        yOffset = yOffset < 0 ? 0 : yOffset
        var progress = yOffset / screenSize.height
        progress = 1 - (progress > 0.4 ? 0.4 : progress)
        return (isExpanded ? progress : 1)
    }
}

struct DetailsView: View {
    @Binding var videoFile: VideoFile
    @Binding var isExpanded: Bool
    var animationID: Namespace.ID
    @GestureState private var isDragging = false
    
    var body: some View {
        ZStack {
            CardView(videoFile: $videoFile, isExpanded: $isExpanded, animationID: animationID, isDetailsView: true)
                .overlay(content: {
                    if isExpanded && videoFile.offset == .zero {
                        Text("Hello world")
                    }
                })
                .ignoresSafeArea()
        }
        .gesture(
            DragGesture()
                .updating($isDragging, body: { _, dragState, _ in
                    dragState = true
                }).onChanged({ value in
                    var translation = value.translation
                    translation = isDragging && isExpanded ? translation : .zero
                    videoFile.offset = translation
                }).onEnded({ value in
                    if value.translation.height > 200 {
                        if !videoFile.isImage {
                            videoFile.player?.pause()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                videoFile.player?.seek(to: .zero)
                                videoFile.playVideo = false
                            }
                        }
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.7)) {
                            videoFile.offset = .zero
                            isExpanded = false
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) {
                            videoFile.offset = .zero
                        }
                    }
                })
        )
        .onAppear {
            if !videoFile.isImage {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.easeInOut) {
                        videoFile.playVideo = true
                        videoFile.player?.play()
                    }
                }
            }
        }
    }
}

struct HomeView: View {
    @State private var videoFiles: [VideoFile] = files
    @State private var isExpanded: Bool = false
    @Namespace private var namespace
    @State private var expandedID: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 10) {
                    ForEach($videoFiles) { $file in
                        if expandedID == file.id.uuidString && isExpanded {
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(height: 300)
                        } else {
                            CardView(videoFile: $file, isExpanded: $isExpanded, animationID: namespace)
                                .frame(height: 300)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.8)) {
                                        expandedID = file.id.uuidString
                                        isExpanded = true
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
        }
        .overlay {
            if let expandedID, isExpanded {
                DetailsView(videoFile: $videoFiles.index(expandedID), isExpanded: $isExpanded, animationID: namespace)
                    .transition(.asymmetric(insertion: .identity, removal: .offset(y: 5)))
            }
        }
    }
}

extension Binding<[VideoFile]> {
    func index(_ id: String) -> Binding<VideoFile> {
        let index = self.wrappedValue.firstIndex { item in
            item.id.uuidString == id
        } ?? 0
        return self[index]
    }
}

var videoURL1: URL = URL(string: "https://firebasestorage.googleapis.com:443/v0/b/hustle-85b6c.appspot.com/o/stories%2F76774B62-12E3-4845-8E58-F7F000934CC9.mp4?alt=media&token=ba6b1909-9ba0-461f-897e-9d8109a8a470")!

var files: [VideoFile] = [
    .init(fileURL: videoURL1, isImage: false, player: AVPlayer(url: videoURL1)),
    .init(fileURL: videoURL1, isImage: false, player: AVPlayer(url: videoURL1)),
    .init(fileURL: videoURL1, isImage: false, player: AVPlayer(url: videoURL1)),
    .init(fileURL: videoURL1, isImage: false, player: AVPlayer(url: videoURL1)),
    .init(fileURL: videoURL1, isImage: false, player: AVPlayer(url: videoURL1)),
    .init(fileURL: videoURL1, isImage: false, player: AVPlayer(url: videoURL1)),
    .init(fileURL: videoURL1, isImage: false, player: AVPlayer(url: videoURL1)),
    .init(isImage: true, imageURL: "https://img.freepik.com/free-photo/abstract-autumn-beauty-multi-colored-leaf-vein-pattern-generated-by-ai_188544-9871.jpg?size=626&ext=jpg&ga=GA1.1.2008272138.1721692800&semt=ais_user"),
    .init(isImage: true, imageURL: "https://letsenhance.io/static/8f5e523ee6b2479e26ecc91b9c25261e/1015f/MainAfter.jpg"),
    .init(isImage: true, imageURL: "https://fps.cdnpk.net/images/home/subhome-ai.webp?w=649&h=649"),
]

struct VideoFile: Identifiable {
    var id: UUID = .init()
    var fileURL: URL?
    var isImage: Bool
    var imageURL: String?
    var thumbnail: UIImage?
    var player: AVPlayer?
    var offset: CGSize = .zero
    var playVideo: Bool = false
}
