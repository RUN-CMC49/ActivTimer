//
//  File.swift
//  ActivTimer
//
//  Created by Katelyn on 2/18/26.
//

import UIKit

class ConfettiType {
    let color: UIColor
    let shape: ConfettiShape
    let position: ConfettiPosition
    
    init(color: UIColor, shape: ConfettiShape, position: ConfettiPosition) {
        self.color = color
        self.shape = shape
        self.position = position
    }
    lazy var image: UIImage = {
        let imageRect: CGRect = {
            switch shape {
            case .rectangle:
                return CGRect(x: 0, y: 0, width: 4, height: 3)
            case .triangle:
                return CGRect(x: 0, y: 0, width: 4, height: 3)
            case .circle:
                return CGRect(x: 0, y: 0, width: 5, height: 5)
            }
        }()
        let renderer = UIGraphicsImageRenderer(size: imageRect.size)
        
        return renderer.image { rendererContext in
            
            let context = rendererContext.cgContext
            
            context.setFillColor(color.cgColor)
            
            switch shape {
            case .rectangle:
                context.fill(imageRect)
                case .triangle:
                let path = CGMutablePath()
                path.move(to: CGPoint(x: imageRect.midX, y: imageRect.minY))
                path.addLine(to: CGPoint(x: imageRect.maxX, y: imageRect.maxY))
                path.addLine(to: CGPoint(x: imageRect.minX, y: imageRect.minY))
                path.closeSubpath()
                
                context.addPath(path)
                context.fillPath()
                
            case .circle:
                context.fillEllipse(in: imageRect)
                
                
            }
            
        }
        
    }()
    
}

enum ConfettiShape: String{
    case rectangle
    case triangle
    case circle
    
    static var allCases: [ConfettiShape] {
        return [.circle, .rectangle, .triangle]
    }
}

enum ConfettiPosition {
    case foreground
    case background
    
    
    static var allCases: [ConfettiPosition] {
        return [.background, .foreground]
    }
}
