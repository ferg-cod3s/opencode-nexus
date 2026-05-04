# Session: Built-in Slash Commands (ses_224844d7affeglwuyhftpxufWn)

## Done
- 12 built-in commands: `/sessions`, `/models`, `/export`, `/help`, `/themes`, `/connect`, etc.
- `sendCommand()` routes built-in commands before server API
- 25 new tests + 3 flaky test fixes
- **142 tests, 0 failures**

## Key Files
- `ChatViewModel.swift` — `handleBuiltInCommand()` dispatcher
- `ChatView.swift` — sheet bindings
- `HelpView.swift`, `SessionPickerView.swift`, `ModelPickerView.swift` — new views
- `ChatViewModelTests.swift` — +25 tests

## Next
1. Real `ConnectionSettingsView` UI
2. Actual `/themes` picker
3. More commands: `/undo`, `/redo`
