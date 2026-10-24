// 스크린샷 헤드라인을 CoreText 로 그린다 (compose_simulator.py 가 부른다).
// Pillow 는 이 맥에서 raqm 없이 돌아 태국어 성조·모음 기호가 깨지고, 띄어쓰기 없는 일본어·중국어를 줄바꿈하지 못한다.
// CoreText 는 언어별 줄바꿈(태국어 사전 포함)과 글자 조합을 제대로 한다.
//
// 사용법: render_text <spec.json>
//   spec.json = [{"text": "...", "font": "Thonburi-Bold", "size": 86, "color": "FFD60A",
//                 "width": 1082, "lineHeight": 104, "lang": "th", "out": "/path/a.png"}, ...]
// 출력: 투명 바탕 PNG, 가로 = width, 줄마다 가운데 정렬. 세로는 줄 수 × lineHeight.
import AppKit

struct Item: Decodable {
    let text: String, font: String, size: CGFloat, color: String
    let width: CGFloat, lineHeight: CGFloat, lang: String, out: String
}

func color(_ hex: String) -> NSColor {
    let v = UInt32(hex, radix: 16) ?? 0xFFFFFF
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
for item in try JSONDecoder().decode([Item].self, from: data) {
    // "system-bold" · "system-regular" = 시스템 글꼴(SF). 라틴 확장 · 키릴 · 그리스 · 베트남어를 다 갖췄다.
    let font: NSFont
    switch item.font {
    case "system-bold": font = .systemFont(ofSize: item.size, weight: .bold)
    case "system-regular": font = .systemFont(ofSize: item.size, weight: .regular)
    default:
        guard let named = NSFont(name: item.font, size: item.size) else {
            FileHandle.standardError.write("글꼴 없음: \(item.font)\n".data(using: .utf8)!); exit(1)
        }
        font = named
    }
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byWordWrapping
    style.minimumLineHeight = item.lineHeight
    style.maximumLineHeight = item.lineHeight
    let text = NSAttributedString(string: item.text, attributes: [
        .font: font, .foregroundColor: color(item.color), .paragraphStyle: style,
        NSAttributedString.Key(rawValue: kCTLanguageAttributeName as String): item.lang,
    ])
    let bounds = text.boundingRect(with: NSSize(width: item.width, height: 10_000),
                                   options: [.usesLineFragmentOrigin])
    let height = ceil(bounds.height / item.lineHeight) * item.lineHeight
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(item.width), pixelsHigh: Int(height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    text.draw(with: NSRect(x: 0, y: 0, width: item.width, height: height),
              options: [.usesLineFragmentOrigin])
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: item.out))
}
