import SwiftUI

struct MotorhomeIcon: View {
    var body: some View {
        MotorhomeShape()
            .fill(.foreground)
    }
}

struct MotorhomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Simple RV silhouette: flat roof box + lower cab + wheels
        let roofY = h * 0.12
        let bodyBottom = h * 0.72
        let cabDivide = w * 0.65
        let cabRoof = h * 0.32

        // Rear box (main living area)
        p.move(to: CGPoint(x: w * 0.04, y: roofY))
        p.addLine(to: CGPoint(x: cabDivide, y: roofY))
        // Step down to cab
        p.addLine(to: CGPoint(x: cabDivide, y: cabRoof))
        // Cab roof + windshield curve
        p.addLine(to: CGPoint(x: w * 0.85, y: cabRoof))
        p.addQuadCurve(to: CGPoint(x: w * 0.93, y: h * 0.50),
                       control: CGPoint(x: w * 0.93, y: cabRoof))
        // Front face down
        p.addLine(to: CGPoint(x: w * 0.93, y: bodyBottom))
        // Bottom
        p.addLine(to: CGPoint(x: w * 0.04, y: bodyBottom))
        p.closeSubpath()

        // Undercarriage
        p.addRect(CGRect(x: w * 0.08, y: bodyBottom, width: w * 0.82, height: h * 0.06))

        // Wheels
        let wheelR = h * 0.12
        let wheelY = bodyBottom + h * 0.06
        // Rear wheel
        p.addEllipse(in: CGRect(x: w * 0.16 - wheelR, y: wheelY, width: wheelR * 2, height: wheelR * 2))
        // Front wheel
        p.addEllipse(in: CGRect(x: w * 0.76 - wheelR, y: wheelY, width: wheelR * 2, height: wheelR * 2))

        return p
    }
}
