//
//  CameraView.swift
//  Robocar
//
//  Created by Daniel Riege on 12.09.22.
//

import SwiftUI

@available(macOS 13.0, *)
public struct ImageView: View {
    @StateObject var cameraViewModel: ImageViewModel
    
    private let label = Text("Camera feed")
    
    public init(cameraViewModel: ImageViewModel) {
        _cameraViewModel = StateObject(wrappedValue: cameraViewModel)
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(cameraViewModel.image, scale: 1.0, label: label)
                .resizable()
                .aspectRatio(contentMode: .fit)
            Text(String(format: "%.0f FPS %@ %@", cameraViewModel.fps, cameraViewModel.resolution, cameraViewModel.pixelFormat))
                .padding(7.0)
                .background(Color(white: 0.0, opacity: 0.7))
                .foregroundColor(.white)
                .font(.footnote)
        }
    }
}

@available(macOS 13.0, *)
public struct CameraView_Previews: PreviewProvider {
    public static var previews: some View {
        ImageView(cameraViewModel: ImageViewModel(channel: 0))
    }
}
