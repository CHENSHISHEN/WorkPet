import AppKit

let app = NSApplication.shared
let delegate = WorkPetApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
