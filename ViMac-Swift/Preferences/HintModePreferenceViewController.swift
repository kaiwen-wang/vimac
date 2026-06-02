import Cocoa
import Preferences

final class HintModePreferenceViewController: NSViewController, NSTextFieldDelegate, PreferencePane {
    let preferencePaneIdentifier = Preferences.PaneIdentifier.hintMode
    let preferencePaneTitle = "Hint Mode"
    let toolbarItemIcon: NSImage
    
    private var grid: NSGridView!
    private var customCharactersField: NSTextField!
    private var textSizeField: NSTextField!
    private var modifierPopups: [UserPreferences.HintMode.ClickModifier: NSPopUpButton] = [:]
    
    init() {
        if #available(OSX 11.0, *) {
            self.toolbarItemIcon = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: nil)!
        } else {
            self.toolbarItemIcon = NSImage(named: "NSFontPanel")!
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
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        let customCharactersLabel = NSTextField(labelWithString: "Custom Characters:")
        customCharactersField = NSTextField()
        customCharactersField.delegate = self
        customCharactersField.stringValue = UserPreferences.HintMode.CustomCharactersProperty.readUnvalidated() ?? ""
        customCharactersField.placeholderString = UserPreferences.HintMode.CustomCharactersProperty.defaultValue
        let customCharactersRow: [NSView] = [customCharactersLabel, customCharactersField]
        grid.addRow(with: customCharactersRow)
        
        let customCharactersHint1 = NSTextField(wrappingLabelWithString: "The characters placed beside UI Elements when hint mode is activated.")
        customCharactersHint1.font = .labelFont(ofSize: 11)
        customCharactersHint1.textColor = .secondaryLabelColor
        grid.addRow(with: [NSGridCell.emptyContentView, customCharactersHint1])
        
        let customCharactersHint2 = NSTextField(wrappingLabelWithString: "Enter at least 6 unique characters.")
        customCharactersHint2.font = .labelFont(ofSize: 11)
        customCharactersHint2.textColor = .secondaryLabelColor
        grid.addRow(with: [NSGridCell.emptyContentView, customCharactersHint2])
        
        let textSizeLabel = NSTextField(labelWithString: "Text Size:")
        textSizeField = NSTextField()
        textSizeField.delegate = self
        textSizeField.placeholderString = UserPreferences.HintMode.TextSizeProperty.defaultValue
        textSizeField.stringValue = UserPreferences.HintMode.TextSizeProperty.readUnvalidated() ?? ""
        let textSizeRow: [NSView] = [textSizeLabel, textSizeField]
        grid.addRow(with: textSizeRow)
        
        grid.addRow(with: [])

        let clickModifiersLabel = NSTextField(labelWithString: "Click Modifiers:")
        let bindingsView = buildClickModifierBindingsView()
        grid.addRow(with: [clickModifiersLabel, bindingsView])
        grid.cell(for: clickModifiersLabel)!.yPlacement = .top

        let clickModifiersHint = NSTextField(wrappingLabelWithString: "When typing hint characters, use these modifier keys:")
        clickModifiersHint.font = .labelFont(ofSize: 11)
        clickModifiersHint.textColor = .secondaryLabelColor
        grid.addRow(with: [NSGridCell.emptyContentView, clickModifiersHint])

        let noModifierHint = NSTextField(wrappingLabelWithString: "No modifier: Left Click")
        noModifierHint.font = .labelFont(ofSize: 11)
        noModifierHint.textColor = .secondaryLabelColor
        grid.addRow(with: [NSGridCell.emptyContentView, noModifierHint])

        let resetButton = NSButton(title: "Reset Click Modifiers", target: self, action: #selector(onResetClickModifiers))
        resetButton.bezelStyle = .rounded
        grid.addRow(with: [NSGridCell.emptyContentView, resetButton])
        
        self.view.addSubview(grid)
        
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 600),
            grid.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -200),
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            grid.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private enum ClickActionChoice: String, CaseIterable {
        case leftClick
        case rightClick
        case middleClick
        case doubleLeftClick
        case move

        var title: String {
            switch self {
            case .leftClick: return "Left Click"
            case .rightClick: return "Right Click"
            case .middleClick: return "Middle Click"
            case .doubleLeftClick: return "Double Click"
            case .move: return "Move Cursor"
            }
        }

        var action: HintAction {
            switch self {
            case .leftClick: return .leftClick
            case .rightClick: return .rightClick
            case .middleClick: return .middleClick
            case .doubleLeftClick: return .doubleLeftClick
            case .move: return .move
            }
        }

        static func from(action: HintAction) -> ClickActionChoice {
            switch action {
            case .leftClick: return .leftClick
            case .rightClick: return .rightClick
            case .middleClick: return .middleClick
            case .doubleLeftClick: return .doubleLeftClick
            case .move: return .move
            }
        }
    }

    private func buildClickModifierBindingsView() -> NSView {
        let container = NSGridView(numberOfColumns: 2, rows: 0)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.rowSpacing = 6
        container.columnSpacing = 10
        container.column(at: 0).xPlacement = .trailing

        let current = UserPreferences.HintMode.ClickModifierBindingsProperty.readAsMap()

        func makePopup(selected: ClickActionChoice) -> NSPopUpButton {
            let popup = NSPopUpButton()
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.target = self
            popup.action = #selector(onClickModifierPopupChanged)
            popup.wantsLayer = true
            popup.layer?.cornerRadius = 6
            popup.layer?.borderWidth = 1
            popup.layer?.borderColor = NSColor.separatorColor.cgColor
            popup.contentTintColor = .labelColor
            ClickActionChoice.allCases.forEach { popup.addItem(withTitle: $0.title) }
            popup.selectItem(withTitle: selected.title)
            return popup
        }

        let rows: [(UserPreferences.HintMode.ClickModifier, String)] = [
            (.shift, "Shift"),
            (.command, "Command"),
            (.option, "Option"),
            (.control, "Control"),
        ]

        for (modifier, title) in rows {
            let label = NSTextField(labelWithString: "\(title):")
            label.font = .labelFont(ofSize: 12)
            let choice = ClickActionChoice.from(action: current[modifier] ?? .leftClick)
            let popup = makePopup(selected: choice)
            modifierPopups[modifier] = popup
            container.addRow(with: [label, popup])
        }

        markDuplicateClickModifierBindings()
        return container
    }

    @objc private func onClickModifierPopupChanged() {
        let map = currentClickModifierMapFromUI()
        UserPreferences.HintMode.ClickModifierBindingsProperty.save(map: map)
        markDuplicateClickModifierBindings()
    }

    private func currentClickModifierMapFromUI() -> [UserPreferences.HintMode.ClickModifier: HintAction] {
        func selectedChoice(_ modifier: UserPreferences.HintMode.ClickModifier) -> ClickActionChoice {
            guard let title = modifierPopups[modifier]?.titleOfSelectedItem else { return .leftClick }
            return ClickActionChoice.allCases.first(where: { $0.title == title }) ?? .leftClick
        }
        return [
            .shift: selectedChoice(.shift).action,
            .command: selectedChoice(.command).action,
            .option: selectedChoice(.option).action,
            .control: selectedChoice(.control).action,
        ]
    }

    private func markDuplicateClickModifierBindings() {
        let map = currentClickModifierMapFromUI()
        let actions = map.values.map { ClickActionChoice.from(action: $0).rawValue }
        var counts: [String: Int] = [:]
        for a in actions { counts[a, default: 0] += 1 }

        for (modifier, popup) in modifierPopups {
            let choice = ClickActionChoice.from(action: map[modifier] ?? .leftClick).rawValue
            let isDuplicate = (counts[choice] ?? 0) > 1
            popup.layer?.borderColor = (isDuplicate ? NSColor.systemRed : NSColor.separatorColor).cgColor
            popup.layer?.borderWidth = isDuplicate ? 2 : 1
        }
    }

    @objc private func onResetClickModifiers() {
        // Reset UI to defaults (and persist).
        let defaults = UserPreferences.HintMode.ClickModifierBindingsProperty.defaultValue.components(separatedBy: ",")
        let map: [UserPreferences.HintMode.ClickModifier: HintAction] = [
            .shift: ClickActionChoice(rawValue: defaults[0])?.action ?? .rightClick,
            .command: ClickActionChoice(rawValue: defaults[1])?.action ?? .doubleLeftClick,
            .option: ClickActionChoice(rawValue: defaults[2])?.action ?? .middleClick,
            .control: ClickActionChoice(rawValue: defaults[3])?.action ?? .move,
        ]
        UserPreferences.HintMode.ClickModifierBindingsProperty.save(map: map)

        let byModifier: [(UserPreferences.HintMode.ClickModifier, ClickActionChoice)] = [
            (.shift, .from(action: map[.shift] ?? .rightClick)),
            (.command, .from(action: map[.command] ?? .doubleLeftClick)),
            (.option, .from(action: map[.option] ?? .middleClick)),
            (.control, .from(action: map[.control] ?? .move)),
        ]
        for (modifier, choice) in byModifier {
            modifierPopups[modifier]?.selectItem(withTitle: choice.title)
        }
        markDuplicateClickModifierBindings()
    }
    
    func onCustomCharactersFieldChange() {
        let value = customCharactersField.stringValue
        UserPreferences.HintMode.CustomCharactersProperty.save(value: value)
    }
    
    func onCustomCharactersFieldEndEditing() {
        let value = customCharactersField.stringValue
        let isValid = UserPreferences.HintMode.CustomCharactersProperty.isValid(value: value)
        
        if value.count > 0 && !isValid {
            showInvalidValueDialog(value)
        }
    }
    
    func onTextSizeFieldEndEditing() {
        let value = textSizeField.stringValue
        let isValid = UserPreferences.HintMode.TextSizeProperty.isValid(value: value)

        if value.count > 0 && !isValid {
            showInvalidValueDialog(value)
        }
    }
    
    func onTextSizeFieldChange() {
        let value = textSizeField.stringValue
        UserPreferences.HintMode.TextSizeProperty.save(value: value)
    }
    
    func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else {
            return
        }
        
        if textField == customCharactersField {
            onCustomCharactersFieldChange()
            return
        }

        if textField == textSizeField {
            onTextSizeFieldChange()
            return
        }
    }
    
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else {
            return
        }
        
        if textField == customCharactersField {
            onCustomCharactersFieldEndEditing()
            return
        }

        if textField == textSizeField {
            onTextSizeFieldEndEditing()
            return
        }
    }
    
    private func showInvalidValueDialog(_ value: String) {
        let alert = NSAlert()
        alert.messageText = "The value \"\(value)\" is invalid."
        alert.informativeText = "Please provide a valid value."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
