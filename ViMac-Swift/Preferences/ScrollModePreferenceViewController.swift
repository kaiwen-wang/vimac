import Cocoa
import Preferences

/// A small box that displays a single scroll key. Click it and press a key
/// (or keys, e.g. "gg") to rebind it.
final class ScrollKeyCaptureField: NSView {
    var onChange: ((String) -> Void)?
    private(set) var value: String = ""

    private let keyLabel = NSTextField(labelWithString: "")
    private var isRecording = false
    private var capturedThisSession = false

    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false

        keyLabel.alignment = .center
        keyLabel.font = .systemFont(ofSize: 18, weight: .medium)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(keyLabel)

        NSLayoutConstraint.activate([
            keyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            keyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 56),
            heightAnchor.constraint(equalToConstant: 44),
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Set the displayed value without firing onChange (used when loading/resetting).
    func setValue(_ v: String) {
        value = v
        if !isRecording {
            keyLabel.stringValue = v
        }
    }

    // Make the whole box clickable; don't let the centered label swallow clicks.
    override func hitTest(_ point: NSPoint) -> NSView? {
        return bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        capturedThisSession = false
        keyLabel.stringValue = "…"
        updateAppearance()
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        // Nothing was captured this session — restore the previous value.
        keyLabel.stringValue = value
        updateAppearance()
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Escape cancels recording.
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }

        guard let chars = event.characters, let scalar = chars.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar),
              !CharacterSet.whitespacesAndNewlines.contains(scalar) else {
            return
        }

        if capturedThisSession {
            value += chars
        } else {
            value = chars
            capturedThisSession = true
        }

        keyLabel.stringValue = value
        onChange?(value)
    }

    func setInvalid(_ invalid: Bool) {
        if invalid {
            layer?.borderColor = NSColor.systemRed.cgColor
            layer?.borderWidth = 2
        } else {
            updateAppearance()
        }
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        if isRecording {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 2
        } else {
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if !isRecording { updateAppearance() }
    }
}

final class ScrollModePreferenceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.scrollMode
    let preferencePaneTitle = "Scroll Mode"
    let toolbarItemIcon: NSImage

    // Subtitles in the same order as ScrollKeysProperty's format:
    // {left},{down},{up},{right},{half-down},{half-up},{bottom},{top}
    private let keyTitles = ["Left", "Down", "Up", "Right",
                             "Half Down", "Half Up", "Bottom", "Top"]
    private var captureFields: [ScrollKeyCaptureField] = []

    private var grid: NSGridView!
    private var scrollSensitivityView: NSSlider!
    private var revHorizontalScrollView: NSButton!
    private var revVerticalScrollView: NSButton!

    init() {
        if #available(OSX 11.0, *) {
            self.toolbarItemIcon = NSImage(systemSymbolName: "dpad", accessibilityDescription: nil)!
        } else {
            self.toolbarItemIcon = NSImage(named: "NSColorPanel")!
        }

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func loadView() {
        self.view = NSView()
        self.view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        grid = NSGridView(numberOfColumns: 2, rows: 1)
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false

        let scrollKeysLabel = NSTextField(labelWithString: "Scroll Keys:")
        let keysView = buildScrollKeysView()
        grid.addRow(with: [scrollKeysLabel, keysView])
        grid.cell(for: scrollKeysLabel)!.yPlacement = .top

        let scrollKeysHint = NSTextField(wrappingLabelWithString: "Click a box and press a key to rebind it. Press Escape to cancel.")
        scrollKeysHint.font = .labelFont(ofSize: 11)
        scrollKeysHint.textColor = .secondaryLabelColor
        grid.addRow(with: [NSGridCell.emptyContentView, scrollKeysHint])

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(onResetToDefaults))
        resetButton.bezelStyle = .rounded
        grid.addRow(with: [NSGridCell.emptyContentView, resetButton])

        grid.addRow(with: [])

        let scrollSensitivityLabel = NSTextField(labelWithString: "Scroll Sensitivity:")
        scrollSensitivityView = NSSlider()
        scrollSensitivityView.minValue = 0
        scrollSensitivityView.maxValue = 100
        scrollSensitivityView.numberOfTickMarks = 10
        scrollSensitivityView.integerValue = UserPreferences.ScrollMode.ScrollSensitivityProperty.read()
        scrollSensitivityView.target = self
        scrollSensitivityView.action = #selector(onScrollSensitivityFieldEdit)
        grid.addRow(with: [scrollSensitivityLabel, scrollSensitivityView])

        let reverseScrollLabel = NSTextField(labelWithString: "Reverse Scroll:")
        revHorizontalScrollView = NSButton(checkboxWithTitle: "Horizontal", target: self, action: #selector(onRevHorizontalScrollEdit))
        revHorizontalScrollView.state = UserPreferences.ScrollMode.ReverseHorizontalScrollProperty.read() ? .on : .off
        grid.addRow(with: [reverseScrollLabel, revHorizontalScrollView])

        revVerticalScrollView = NSButton(checkboxWithTitle: "Vertical", target: self, action: #selector(onRevVerticalScrollEdit))
        revVerticalScrollView.state = UserPreferences.ScrollMode.ReverseVerticalScrollProperty.read() ? .on : .off
        grid.addRow(with: [NSGridCell.emptyContentView, revVerticalScrollView])


        self.view.addSubview(grid)

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 600),
            grid.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -200),
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            grid.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    /// Builds the grid of per-direction capture boxes, each with a subtitle below it.
    private func buildScrollKeysView() -> NSView {
        let values = currentKeyValues()

        let keysGrid = NSGridView(numberOfColumns: 4, rows: 0)
        keysGrid.translatesAutoresizingMaskIntoConstraints = false
        keysGrid.rowSpacing = 4
        keysGrid.columnSpacing = 12
        for col in 0..<4 {
            keysGrid.column(at: col).xPlacement = .center
        }

        // Lay out as two rows of four boxes; each box has its subtitle directly beneath.
        for rowStart in stride(from: 0, to: keyTitles.count, by: 4) {
            var boxRow: [NSView] = []
            var titleRow: [NSView] = []
            for i in rowStart..<min(rowStart + 4, keyTitles.count) {
                let field = ScrollKeyCaptureField()
                field.setValue(values[i])
                field.onChange = { [weak self] _ in self?.onScrollKeysChanged() }
                captureFields.append(field)
                boxRow.append(field)

                let subtitle = NSTextField(labelWithString: keyTitles[i])
                subtitle.font = .labelFont(ofSize: 11)
                subtitle.textColor = .secondaryLabelColor
                subtitle.alignment = .center
                titleRow.append(subtitle)
            }
            keysGrid.addRow(with: boxRow)
            keysGrid.addRow(with: titleRow)
        }

        return keysGrid
    }

    /// Returns the 8 current key values, falling back to the default for any
    /// position not present in the saved value.
    private func currentKeyValues() -> [String] {
        let defaults = UserPreferences.ScrollMode.ScrollKeysProperty.defaultValue.components(separatedBy: ",")
        let saved = UserPreferences.ScrollMode.ScrollKeysProperty.read().components(separatedBy: ",")
        return (0..<keyTitles.count).map { i in
            i < saved.count && !saved[i].isEmpty ? saved[i] : defaults[i]
        }
    }

    private func currentJoinedValue() -> String {
        captureFields.map { $0.value }.joined(separator: ",")
    }

    func onScrollKeysChanged() {
        let value = currentJoinedValue()
        let isValid = UserPreferences.ScrollMode.ScrollKeysProperty.isValid(value: value)

        // Flag any boxes that duplicate another (the only realistic invalid state
        // now that all eight positions are always filled).
        markDuplicates()

        if isValid {
            UserPreferences.ScrollMode.ScrollKeysProperty.save(value: value)
        }
    }

    private func markDuplicates() {
        var counts: [String: Int] = [:]
        for field in captureFields {
            counts[field.value, default: 0] += 1
        }
        for field in captureFields {
            field.setInvalid((counts[field.value] ?? 0) > 1)
        }
    }

    @objc func onResetToDefaults() {
        let defaults = UserPreferences.ScrollMode.ScrollKeysProperty.defaultValue.components(separatedBy: ",")
        for (i, field) in captureFields.enumerated() where i < defaults.count {
            field.setValue(defaults[i])
            field.setInvalid(false)
        }
        view.window?.makeFirstResponder(nil)
        UserPreferences.ScrollMode.ScrollKeysProperty.save(value: UserPreferences.ScrollMode.ScrollKeysProperty.defaultValue)
    }

    @objc func onScrollSensitivityFieldEdit() {
        let value = scrollSensitivityView.integerValue
        let isValid = UserPreferences.ScrollMode.ScrollSensitivityProperty.isValid(value: value)

        if !isValid {
            return
        }
        UserPreferences.ScrollMode.ScrollSensitivityProperty.save(value: value)
    }

    @objc func onRevHorizontalScrollEdit() {
        let value = revHorizontalScrollView.state == .on
        UserPreferences.ScrollMode.ReverseHorizontalScrollProperty.save(value: value)
    }

    @objc func onRevVerticalScrollEdit() {
        let value = revVerticalScrollView.state == .on
        UserPreferences.ScrollMode.ReverseVerticalScrollProperty.save(value: value)
    }
}
