//
//  ConfettiView.swift
//  ActivTimer
//
//  Created by Katelyn on 2/18/26.
//

import SwiftUI

struct ConfettiView: UIViewRepresentable {
    @Binding var isAnimating: Bool
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        let emitterLayer = CAEmitterLayer()
        emitterLayer.frame = view.bounds
        
        
        //Bounds and coordinates for confetti exploder
        emitterLayer.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: -50)
        emitterLayer.emitterSize = CGSize(width: view.bounds.size.width, height: 1)
        emitterLayer.emitterShape = .line
        
        view.layer.addSublayer(emitterLayer)
        return view
        
        }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        let emitterLayer = uiView.layer.sublayers?.first as? CAEmitterLayer
        
        
        if isAnimating {
            emitterLayer?.scale = 1.0
            emitterLayer?.emitterCells = generateConfettiCells()
            
        } else {
            emitterLayer?.scale = 0.0
            
        }
        
    }
    
    func generateConfettiCells() -> [CAEmitterCell] {
        
        let colors:[UIColor] = [.red, .blue, .yellow, .green, .purple]
        let shapes:[ConfettiShape] = ConfettiShape.allCases
        
        let position: [ConfettiPosition] = ConfettiPosition.allCases
        
        return shapes.flatMap { shape in
            colors.flatMap { color in
                
                position.map { position in
                    
                    
                    //confetti cells properties.
                    let cell = CAEmitterCell()
                    let confetti = ConfettiType(color: color, shape: shape, position: position)
                    cell.contents = confetti.image.cgImage
                    cell.birthRate = 10 // how many confettis explode out at one time
                    cell.lifetime = 6 // duration
                    cell.velocity = 100
                    cell.emissionRange = .pi
                    cell.emissionLongitude = .pi
                    cell.spin = 2
                    cell.spinRange = 3
                    cell.scale = 0.6
                    cell.scaleRange = 0.3
                    cell.yAcceleration = 55
                    return cell
                    
                    
                    }
                }
            }
        }
        
    func startConfetti(){
        isAnimating = true
    }
    func stopConfetti(){
        isAnimating = false
    }
    
    
    }
    
    
    
    
    

    


#Preview {
    ContentView()
}
