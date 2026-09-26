import AppKit
import Carbon

/// Owns the Carbon registration so failures are observable by the settings UI.
final class RegisteredHotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private(set) var status: OSStatus = noErr
    var keyDownHandler: (() -> Void)?

    init(keyCode: UInt32, modifiers: UInt32) {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID) == noErr,
                  hotKeyID.signature == 0x5344434b else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<RegisteredHotKey>.fromOpaque(context).takeUnretainedValue()
            guard hotKeyID.id == owner.identifier else { return OSStatus(eventNotHandledErr) }
            owner.keyDownHandler?()
            return noErr
        }, 1, &event, pointer, &handler)
        guard status == noErr else { return }
        status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: 0x5344434b, id: identifier),
                                    GetApplicationEventTarget(), 0, &reference)
    }

    private static var nextID: UInt32 = 0
    private let identifier: UInt32 = { RegisteredHotKey.nextID &+= 1; return RegisteredHotKey.nextID }()
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
