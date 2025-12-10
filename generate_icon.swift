import AppKit

// 配置
let size = 1024.0
let iconSize = 824.0 // macOS 标准图标视觉尺寸
let cornerRadius = 175.0 // 对应的圆角半径
let outputPath = "generated_icon.png"

// 创建画布
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// 获取上下文以进行高指绘图
let context = NSGraphicsContext.current?.cgContext

// 1. 定义图标形状路径 (居中)
let rect = NSRect(x: (size - iconSize) / 2,
                  y: (size - iconSize) / 2,
                  width: iconSize,
                  height: iconSize)
let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

// 2. 绘制投影
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -8) // 向下偏移
shadow.shadowBlurRadius = 25
shadow.set()
// 绘制一个填充来产生阴影，稍后会被主图标覆盖，但需要先画阴影
NSColor.white.setFill()
path.fill()
NSGraphicsContext.restoreGraphicsState()

// 3. 绘制渐变背景 (限制在圆角路径内)
path.addClip()
let gradient = NSGradient(starting: NSColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 1.0),
                          ending: NSColor(red: 0.0, green: 0.4, blue: 0.9, alpha: 1.0))
gradient?.draw(in: rect, angle: -45)

// 4. 绘制内部符号 (扫帚)
if let symbolImage = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: nil) {
    // 符号大小相对于 iconSize 的比例 (约 60% 看着舒服，App Store 风格)
    // 之前 360/1024 = 35% 太小了，因为现在背景只有 824 了。
    // 如果背景是 824，符号应该是 824 * 0.6 ≈ 500? 
    // 或者是之前 450 (45%) 左右。
    // 让我们试着让它在 824 的框里居中，大小为 400 (约一半)
    let symbolDimension = 400.0
    let symbolRect = NSRect(x: (size - symbolDimension) / 2,
                            y: (size - symbolDimension) / 2,
                            width: symbolDimension,
                            height: symbolDimension)
    
    let config = NSImage.SymbolConfiguration(pointSize: symbolDimension, weight: .regular)
        .applying(.init(paletteColors: [.white]))
    
    if let coloredSymbol = symbolImage.withSymbolConfiguration(config) {
         coloredSymbol.draw(in: symbolRect)
    }
} else {
    // 文字降级
    let text = "Clean"
    let font = NSFont.systemFont(ofSize: 150, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    let textSize = string.size()
    let textRect = NSRect(x: (size - textSize.width) / 2,
                          y: (size - textSize.height) / 2,
                          width: textSize.width,
                          height: textSize.height)
    string.draw(in: textRect)
}

image.unlockFocus()

// 保存
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    let url = URL(fileURLWithPath: outputPath)
    try? pngData.write(to: url)
    print("Icon generated at \(url.path)")
}
