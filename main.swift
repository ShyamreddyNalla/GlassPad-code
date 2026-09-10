import Cocoa

enum CodeColors {
    static let comment = NSColor(srgbRed: 0.75, green: 0.79, blue: 0.84, alpha: 1)
    static let keyword = NSColor(srgbRed: 1, green: 0.57, blue: 0.76, alpha: 1)
    static let string = NSColor(srgbRed: 0.66, green: 0.9, blue: 0.62, alpha: 1)
    static let number = NSColor(srgbRed: 1, green: 0.77, blue: 0.52, alpha: 1)
    static let function = NSColor(srgbRed: 0.52, green: 0.85, blue: 1, alpha: 1)
    static let type = NSColor(srgbRed: 0.58, green: 0.91, blue: 0.86, alpha: 1)
    static let annotation = NSColor(srgbRed: 1, green: 0.88, blue: 0.6, alpha: 1)
}

final class TintView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class OrbView: NSView {
    var onClick: (() -> Void)?
    private var start = NSPoint.zero
    private var origin = NSPoint.zero
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.12, alpha: 0.82).setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).fill()
        NSColor.white.withAlphaComponent(0.45).setStroke()
        let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
        ring.lineWidth = 1.5
        ring.stroke()
        let text = "</>" as NSString
        text.draw(at: NSPoint(x: 12, y: 17), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 19, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
    }
    override func mouseDown(with event: NSEvent) {
        start = NSEvent.mouseLocation
        origin = window?.frame.origin ?? .zero
    }
    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(x: origin.x + point.x - start.x, y: origin.y + point.y - start.y))
    }
    override func mouseUp(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        if hypot(point.x - start.x, point.y - start.y) < 4 { onClick?() }
    }
}

final class CodeView: NSTextView {
    override func insertTab(_ sender: Any?) { insertText("    ", replacementRange: selectedRange()) }
    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let location = selectedRange().location
        let line = ns.lineRange(for: NSRange(location: location, length: 0))
        let prefix = ns.substring(with: NSRange(location: line.location, length: location - line.location))
        let indentation = String(prefix.prefix { $0 == " " || $0 == "\t" })
        insertText("\n" + indentation + (prefix.trimmingCharacters(in: .whitespaces).hasSuffix("{") ? "    " : ""), replacementRange: selectedRange())
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "a": selectAll(nil); return
            case "c": copy(nil); return
            case "v": paste(nil); return
            case "x": cut(nil); return
            case "z":
                if event.modifierFlags.contains(.shift) { undoManager?.redo() } else { undoManager?.undo() }
                return
            case "w": window?.orderOut(nil); return
            default: break
            }
        }
        if event.keyCode == 53 { window?.orderOut(nil); return }
        super.keyDown(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var orb: FloatingPanel!
    var pad: FloatingPanel!
    var editor: CodeView!
    var status: NSTextField!
    var language: NSPopUpButton!
    var menuItem: NSStatusItem!
    var highlightTimer: Timer?
    let backgroundTint = TintView()
    let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    let fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GlassPad/note.txt")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makeMenu()
        makePad()
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        orb = FloatingPanel(contentRect: NSRect(x: screen.maxX - 86, y: screen.midY, width: 58, height: 58), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        configure(orb)
        let button = OrbView(frame: NSRect(x: 0, y: 0, width: 58, height: 58))
        button.toolTip = "Click for GlassPad · Drag to move"
        button.onClick = { [weak self] in self?.toggle() }
        orb.contentView = button
        orb.orderFrontRegardless()
        toggle()
    }

    func configure(_ panel: NSPanel) {
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
    }

    func makeMenu() {
        menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuItem.button?.title = "</>"
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide GlassPad", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: "Bring floating button back", action: #selector(resetOrb), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit GlassPad", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        menuItem.menu = menu
    }

    func makePad() {
        pad = FloatingPanel(contentRect: NSRect(x: 200, y: 200, width: 560, height: 420), styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        configure(pad)
        pad.title = "GlassPad"
        pad.titleVisibility = .hidden
        pad.titlebarAppearsTransparent = true
        pad.isMovableByWindowBackground = true
        pad.minSize = NSSize(width: 380, height: 240)
        pad.setFrameAutosaveName("GlassPadEditor")
        pad.standardWindowButton(.miniaturizeButton)?.isHidden = true
        pad.standardWindowButton(.zoomButton)?.isHidden = true
        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 12
        glass.layer?.masksToBounds = true
        glass.appearance = NSAppearance(named: .darkAqua)
        pad.contentView = glass
        pad.appearance = glass.appearance
        backgroundTint.wantsLayer = true
        backgroundTint.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(backgroundTint)
        NSLayoutConstraint.activate([
            backgroundTint.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            backgroundTint.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            backgroundTint.topAnchor.constraint(equalTo: glass.topAnchor),
            backgroundTint.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: "GLASSPAD")
        title.font = .systemFont(ofSize: 11, weight: .semibold)
        title.textColor = .white.withAlphaComponent(0.8)
        language = NSPopUpButton()
        language.addItems(withTitles: ["JavaScript", "TypeScript", "Python", "Swift", "Kotlin", "JSON", "HTML / CSS", "Plain text"])
        language.selectItem(withTitle: UserDefaults.standard.string(forKey: "language") ?? "JavaScript")
        language.target = self
        language.action = #selector(changeLanguage)
        let opacity = NSSlider(value: UserDefaults.standard.object(forKey: "backgroundOpacity") as? Double ?? 0.8, minValue: 0.35, maxValue: 1, target: self, action: #selector(changeOpacity(_:)))
        opacity.toolTip = "Background opacity · Text stays fully visible"
        updateBackground(opacity.doubleValue)
        let opacityLabel = NSTextField(labelWithString: "Opacity")
        opacityLabel.font = .systemFont(ofSize: 10)
        opacityLabel.textColor = CodeColors.comment
        status = NSTextField(labelWithString: "Saved locally · Esc to hide")
        status.font = .systemFont(ofSize: 10)
        status.textColor = CodeColors.comment

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        editor = CodeView(frame: NSRect(x: 0, y: 0, width: 520, height: 300))
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = true
        editor.textContainer?.containerSize = NSSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = false
        editor.textContainerInset = NSSize(width: 16, height: 12)
        editor.isRichText = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.font = font
        editor.textColor = .white
        editor.insertionPointColor = .white
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.delegate = self
        editor.string = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "// Your floating code notepad.\n// Drag the round button anywhere.\n// Notes are saved automatically on this Mac.\n\nfunction hello(name) {\n    return `Hello, ${name}!`;\n}\n"
        scroll.documentView = editor
        for view in [title, language!, scroll, opacityLabel, opacity, status!] {
            view.translatesAutoresizingMaskIntoConstraints = false
            glass.addSubview(view)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: glass.leadingAnchor, constant: 42), title.topAnchor.constraint(equalTo: glass.topAnchor, constant: 15),
            language.trailingAnchor.constraint(equalTo: glass.trailingAnchor, constant: -12), language.centerYAnchor.constraint(equalTo: title.centerYAnchor), language.widthAnchor.constraint(equalToConstant: 130),
            scroll.topAnchor.constraint(equalTo: glass.topAnchor, constant: 45), scroll.leadingAnchor.constraint(equalTo: glass.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: glass.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: glass.bottomAnchor, constant: -36),
            status.leadingAnchor.constraint(equalTo: glass.leadingAnchor, constant: 16), status.bottomAnchor.constraint(equalTo: glass.bottomAnchor, constant: -12),
            opacity.trailingAnchor.constraint(equalTo: glass.trailingAnchor, constant: -14), opacity.centerYAnchor.constraint(equalTo: status.centerYAnchor), opacity.widthAnchor.constraint(equalToConstant: 75),
            opacityLabel.trailingAnchor.constraint(equalTo: opacity.leadingAnchor, constant: -6), opacityLabel.centerYAnchor.constraint(equalTo: opacity.centerYAnchor)
        ])
        highlight()
    }

    @objc func toggle() {
        if pad.isVisible { pad.orderOut(nil); return }
        if let screen = orb.screen {
            let area = screen.visibleFrame
            let x = max(area.minX, min(orb.frame.minX - pad.frame.width - 12, area.maxX - pad.frame.width))
            let y = max(area.minY, min(orb.frame.maxY - pad.frame.height, area.maxY - pad.frame.height))
            pad.setFrameOrigin(NSPoint(x: x, y: y))
        }
        pad.makeKeyAndOrderFront(nil)
        pad.makeFirstResponder(editor)
    }
    @objc func resetOrb() {
        guard let area = NSScreen.main?.visibleFrame else { return }
        orb.setFrameOrigin(NSPoint(x: area.maxX - 86, y: area.midY))
        orb.orderFrontRegardless()
    }
    @objc func changeOpacity(_ sender: NSSlider) {
        updateBackground(sender.doubleValue)
        UserDefaults.standard.set(sender.doubleValue, forKey: "backgroundOpacity")
    }
    func updateBackground(_ value: Double) {
        // Keep enough dark tint for readable code even over a pure-white window.
        let fraction = (min(1, max(0.35, value)) - 0.35) / 0.65
        backgroundTint.layer?.backgroundColor = NSColor(srgbRed: 0.055, green: 0.065, blue: 0.085, alpha: 0.72 + 0.24 * fraction).cgColor
    }
    @objc func changeLanguage() {
        UserDefaults.standard.set(language.titleOfSelectedItem, forKey: "language")
        highlight()
    }
    func textDidChange(_ notification: Notification) {
        save()
        highlightTimer?.invalidate()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in self?.highlight() }
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try editor.string.write(to: fileURL, atomically: true, encoding: .utf8)
            status.stringValue = "Saved locally · Esc to hide"
        } catch { status.stringValue = "Could not save: \(error.localizedDescription)" }
    }
    func highlight() {
        guard let storage = editor.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 1)], range: full)
        if language.titleOfSelectedItem == "Kotlin" {
            highlightKotlin(storage, range: full)
        } else if language.titleOfSelectedItem != "Plain text" {
            let rules: [(String, NSColor)] = [
                (#"\b(?:func|function|let|var|const|class|struct|enum|import|from|def|return|if|else|for|while|in|of|switch|case|break|continue|async|await|try|catch|throw|throws|new|export|default|public|private|static|true|false|null|nil|None|True|False|self|this)\b"#, CodeColors.keyword),
                (#"\b\d+(?:\.\d+)?\b"#, CodeColors.number),
                (#"\b[A-Za-z_][A-Za-z_0-9]*(?=\s*\()"#, CodeColors.function),
                (#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, CodeColors.string),
                (language.titleOfSelectedItem == "Python" ? #"(?m)#.*$"# : #"(?m)//.*$|/\*[\s\S]*?\*/"#, CodeColors.comment)
            ]
            for (pattern, color) in rules {
                guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
                expression.enumerateMatches(in: storage.string, range: full) { match, _, _ in
                    if let match { storage.addAttribute(.foregroundColor, value: color, range: match.range) }
                }
            }
        }
        storage.endEditing()
        editor.typingAttributes = [.font: font, .foregroundColor: NSColor.white]
    }

    func highlightKotlin(_ storage: NSTextStorage, range: NSRange) {
        // Tokenize strings and comments first so their contents keep their color.
        let tokens: [(String, NSColor)] = [
            (#"//[^\n]*|/\*[\s\S]*?(?:\*/|\z)"#, CodeColors.comment),
            (#"\"\"\"[\s\S]*?(?:\"\"\"|\z)|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, CodeColors.string),
            (#"`[^`\n]*`"#, .white),
            (#"@[A-Za-z_][A-Za-z_0-9]*(?::[A-Za-z_][A-Za-z_0-9]*)?"#, CodeColors.annotation),
            (#"\b(?:as|break|class|continue|do|else|false|for|fun|if|in|interface|is|null|object|package|return|super|this|throw|true|try|typealias|typeof|val|var|when|while|by|catch|constructor|delegate|dynamic|field|file|finally|get|import|init|param|property|receiver|set|setparam|where|actual|abstract|annotation|companion|const|crossinline|data|enum|expect|external|final|infix|inline|inner|internal|lateinit|noinline|open|operator|out|override|private|protected|public|reified|sealed|suspend|tailrec|vararg|value)\b"#, CodeColors.keyword),
            (#"\b(?:Any|Unit|Nothing|String|Char|Boolean|Byte|Short|Int|Long|Float|Double|UByte|UShort|UInt|ULong|Array|List|MutableList|Set|MutableSet|Map|MutableMap|Sequence|Pair|Triple)\b"#, CodeColors.type),
            (#"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d[\d_]*)?)[uU]?[lLfF]?\b"#, CodeColors.number),
            (#"\b[A-Za-z_][A-Za-z_0-9]*(?=\s*\()"#, CodeColors.function)
        ]
        let pattern = tokens.map { "(" + $0.0 + ")" }.joined(separator: "|")
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return }
        expression.enumerateMatches(in: storage.string, range: range) { match, _, _ in
            guard let match else { return }
            for (index, token) in tokens.enumerated() where match.range(at: index + 1).location != NSNotFound {
                storage.addAttribute(.foregroundColor, value: token.1, range: match.range)
                break
            }
        }
    }
    @objc func quit() { save(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { save() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
