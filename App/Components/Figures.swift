import SwiftUI

/// 视频风格的圆头小人（听数字场景）
struct ListenerFigure: View {
    var shirt: Color = Palette.blue
    var skin: Color = Color(hex: 0xE3B48A)
    var hair: Color = Color(hex: 0x3B2A20)
    var headphones = true
    var silhouette = false
    var size: CGFloat = 120

    var body: some View {
        let s = size
        ZStack {
            // 身体
            RoundedRectangle(cornerRadius: s * 0.2)
                .fill(silhouette ? AnyShapeStyle(Palette.ink3) :
                        AnyShapeStyle(LinearGradient(colors: [shirt, shirt.opacity(0.65)], startPoint: .top, endPoint: .bottom)))
                .frame(width: s * 0.62, height: s * 0.52)
                .offset(y: s * 0.36)
            if !silhouette {
                // 脖子
                RoundedRectangle(cornerRadius: s * 0.03)
                    .fill(skin.opacity(0.85))
                    .frame(width: s * 0.1, height: s * 0.1)
                    .offset(y: s * 0.11)
            }
            // 头
            Circle()
                .fill(silhouette ? Palette.ink3 : skin)
                .frame(width: s * 0.4, height: s * 0.4)
                .offset(y: -s * 0.06)
            if !silhouette {
                // 头发
                Circle()
                    .trim(from: 0.5, to: 1)
                    .fill(hair)
                    .frame(width: s * 0.42, height: s * 0.42)
                    .offset(y: -s * 0.075)
                // 闭眼微笑
                HStack(spacing: s * 0.09) {
                    ClosedEye().stroke(hair, lineWidth: s * 0.018).frame(width: s * 0.06, height: s * 0.025)
                    ClosedEye().stroke(hair, lineWidth: s * 0.018).frame(width: s * 0.06, height: s * 0.025)
                }
                .offset(y: -s * 0.04)
                ClosedEye()
                    .stroke(Color(hex: 0x9A5B3E), style: StrokeStyle(lineWidth: s * 0.016, lineCap: .round))
                    .frame(width: s * 0.08, height: s * 0.03)
                    .offset(y: s * 0.04)
            }
            if headphones && !silhouette {
                Circle()
                    .trim(from: 0.55, to: 0.95)
                    .stroke(Palette.goldDeep, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                    .frame(width: s * 0.5, height: s * 0.5)
                    .offset(y: -s * 0.05)
                HStack(spacing: s * 0.36) {
                    Capsule().fill(Palette.goldGradient).frame(width: s * 0.09, height: s * 0.17)
                    Capsule().fill(Palette.goldGradient).frame(width: s * 0.09, height: s * 0.17)
                }
                .offset(y: -s * 0.03)
                .shadow(color: Palette.gold.opacity(0.5), radius: 6)
            }
        }
        .frame(width: s * 0.7, height: s)
    }
}

struct ClosedEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        return p
    }
}

/// 嘈杂人群：深色剪影 + 说话气泡
struct CrowdBackdrop: View {
    var active = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 2) {
                    Image(systemName: "bubble.middle.bottom.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Palette.ink3.opacity(active ? 1 : 0.5))
                        .overlay(Image(systemName: "waveform").font(.system(size: 8)).foregroundColor(Palette.faint).offset(y: -1))
                        .offset(x: i % 2 == 0 ? 8 : -8)
                        .opacity(i == 3 ? 0 : 1)
                    ListenerFigure(silhouette: true, size: CGFloat(54 + (i * 13) % 20))
                        .opacity(i == 3 ? 0 : 0.95)
                }
            }
        }
    }
}
