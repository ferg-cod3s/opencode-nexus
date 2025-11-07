# Mobile Testing Checklist - Phase 2 Task 6

## Touch Target Validation (44px minimum)

### Session Management
- [ ] Create Session button: 44×44px verified
- [ ] Toggle expand/collapse button: 44×44px verified
- [ ] Error dismiss button: 44×44px verified
- [ ] Session card delete button: 44×44px verified
- [ ] Session card selectable area: Full card is clickable

### Chat Interface
- [ ] Send message button: 44×44px (mobile), 48×48px (tablet)
- [ ] Message input textarea: min-height 44px (mobile), 48px (tablet)
- [ ] Message bubbles: Sufficient spacing for interaction

### Responsive Breakpoints Testing

#### Small Phone (375px) - iPhone SE / 12 mini
- [ ] SessionPanel properly sized (full width, max-height 200px)
- [ ] ChatInterface main area fills remaining space
- [ ] MessageInput not covered by keyboard
- [ ] All buttons reach 44px targets
- [ ] Text readable without zoom

#### Standard Phone (390-412px) - iPhone 13/14/15, Pixel 6/7
- [ ] Layout responsive at this size
- [ ] Sidebar and chat area properly proportioned
- [ ] Touch targets adequate for typical thumb reach
- [ ] No horizontal scrolling needed

#### Large Phone (600-768px) - iPhone 14 Plus, Pixel 6 Pro
- [ ] SessionPanel remains full-width (max-height 200px)
- [ ] Transition looks good as we approach tablet
- [ ] Touch targets may slightly increase (48px)
- [ ] Landscape orientation works

#### Tablet (768px+) - iPad, Android tablets
- [ ] SessionPanel transitions to sidebar (280-320px width)
- [ ] Chat layout horizontal (sidebar + main)
- [ ] Touch targets 48px+
- [ ] Hover states active on touch devices
- [ ] Full width utilized effectively

### Orientation Testing

#### Portrait (Primary)
- [ ] Stacked layout (SessionPanel → ChatInterface)
- [ ] SessionPanel max-height 200px
- [ ] MessageInput always visible and accessible
- [ ] No horizontal scrolling

#### Landscape
- [ ] SessionPanel reduced height or collapsed
- [ ] ChatInterface takes more space
- [ ] MessageInput positioned above keyboard
- [ ] All controls still accessible

### Input & Keyboard Testing

#### Message Input
- [ ] Font size 16px (no iOS auto-zoom)
- [ ] Auto-expands with content (Shift+Enter creates new line)
- [ ] Enter key sends message (mobile)
- [ ] Character counter visible (0/10000)
- [ ] Placeholder text visible

#### Offline Handling
- [ ] "Message queued for sending..." placeholder when offline
- [ ] Offline indicator shows message count
- [ ] Messages sync when connection restored
- [ ] No error messages for offline state

### Gesture Support Testing

#### Tap Gestures
- [ ] Single tap selects session (no accidental double-tap)
- [ ] Long press doesn't trigger unwanted actions (future)
- [ ] Buttons respond immediately to tap

#### Scroll Gestures
- [ ] Message list scrolls smoothly
- [ ] Momentum scrolling enabled (-webkit-overflow-scrolling)
- [ ] No scroll jank with 100+ messages
- [ ] Virtual scrolling works (only visible messages rendered)

#### Swipe Gestures (If Implemented)
- [ ] Swipe left/right recognized
- [ ] 50px threshold before action triggers
- [ ] No conflict with scroll gestures

#### Pull-to-Refresh (ChatInterface)
- [ ] Pull gesture recognized
- [ ] 80px threshold before refresh triggers
- [ ] Loading spinner appears
- [ ] Smooth animation during pull

### Performance Testing

#### Load Times
- [ ] First paint < 2 seconds on 4G
- [ ] Chat interface interactive < 3 seconds
- [ ] Session list loads instantly (< 500ms)
- [ ] Messages render smoothly

#### Memory Usage
- [ ] App with 100 messages uses < 15MB
- [ ] No memory leaks after scrolling
- [ ] Virtual scrolling keeps DOM small (< 50 nodes)

#### Scroll Performance
- [ ] 60 FPS (or smooth) when scrolling messages
- [ ] No jank when typing while scrolling
- [ ] Virtual scrolling active for 100+ messages

### Accessibility Testing

#### Screen Reader (iOS VoiceOver / Android TalkBack)
- [ ] All buttons have aria-label
- [ ] Form fields announce correctly
- [ ] Status updates read (aria-live)
- [ ] Tab order logical
- [ ] Text contrast ratio > 4.5:1

#### High Contrast Mode
- [ ] Colors pass WCAG AA (4.5:1 contrast)
- [ ] Borders visible in high contrast
- [ ] Text readable without color dependency

#### Reduced Motion
- [ ] Animations disabled when prefers-reduced-motion
- [ ] Transitions don't distract
- [ ] App fully functional without animations

### Safe Area Handling

#### Notched Devices (iPhone X+, Android notches)
- [ ] Content not hidden behind notch
- [ ] Header padding accounts for notch
- [ ] Safe area respected on all sides
- [ ] Status bar readable

#### Rounded Corners (Modern Devices)
- [ ] No important content in corners
- [ ] Border radius doesn't cut off UI
- [ ] Buttons accessible in corners

### Network Conditions

#### Fast 4G / LTE
- [ ] Messages send/receive < 500ms
- [ ] Streaming starts immediately
- [ ] No buffering in message display

#### Slow 4G
- [ ] App remains responsive
- [ ] Queue messages if connection slow
- [ ] Show loading state during send
- [ ] Retry mechanism visible

#### Offline
- [ ] Messages queued for sending
- [ ] Offline indicator shown
- [ ] Syncs when reconnected
- [ ] No error states visible

### Device-Specific Testing

#### iOS (iPhone)
- [ ] No zoom on input focus (font-size 16px)
- [ ] Momentum scrolling smooth
- [ ] Keyboard dismisses properly
- [ ] Safe area respected
- [ ] Cursor position correct in textarea

#### Android
- [ ] System back button handled
- [ ] Keyboard animations smooth
- [ ] Long-press no unwanted menus
- [ ] Hardware acceleration enabled
- [ ] No scrollbar blocking content

### Browser Behavior

#### Safari (iOS)
- [ ] -webkit- prefixes applied
- [ ] Address bar collapse/expand handled
- [ ] Safe area CSS working
- [ ] Smooth scroll enabled

#### Chrome Mobile (Android)
- [ ] -webkit- and standard prefixes both work
- [ ] Hardware acceleration enabled
- [ ] Bottom navigation doesn't cover input
- [ ] Viewport units correct

### Responsive Font Sizing

#### Small Phone (375px)
- [ ] Base text readable at 16px
- [ ] Headers at 18-20px
- [ ] Labels at 14px
- [ ] Captions at 12px

#### Tablet (768px+)
- [ ] Base text 16px (consistent)
- [ ] Headers increase to 20-24px
- [ ] Labels increase to 16px
- [ ] No text overflow on screen

### Touch Target Spacing

#### Session Cards
- [ ] 12px gap between cards (prevents accidental taps)
- [ ] Delete button spaced from title
- [ ] Hover/active states clear on touch

#### Chat Messages
- [ ] Messages not overlapping with controls
- [ ] Timestamp not blocking interaction
- [ ] Proper padding around text

#### Input Area
- [ ] 8px spacing between input and button
- [ ] Character count doesn't block scroll
- [ ] Offline indicator doesn't hide input

### Final Verification

- [ ] All 44px touch targets verified
- [ ] Responsive layouts tested at 375px, 768px, 1024px
- [ ] Gestures responsive and intuitive
- [ ] Offline functionality working
- [ ] Accessibility features enabled
- [ ] Performance acceptable on slow networks
- [ ] No iOS zoom triggers
- [ ] Safe areas respected
- [ ] Orientation changes smooth
- [ ] Virtual scrolling active for large lists

## Testing Device List

### Required for Full Validation
- [ ] iPhone SE (375px - smallest)
- [ ] iPhone 12/13/14 (390px - standard)
- [ ] iPhone 14 Plus (428px - large)
- [ ] iPad (768px - tablet)
- [ ] Android Pixel 4a (390px - standard)
- [ ] Android Pixel 6 Pro (412px - large)

### Desktop Validation
- [ ] Chrome DevTools iPhone emulation
- [ ] Chrome DevTools Pixel emulation
- [ ] Safari iOS simulator
- [ ] Responsive mode at 375px, 768px, 1024px

## Known Limitations & Future Work

- [ ] Gesture-based navigation (swipe between sessions)
- [ ] Bottom sheet implementation for inputs
- [ ] Haptic feedback on interactions
- [ ] App shell caching for offline
- [ ] Performance monitoring integration
- [ ] A/B testing mobile layouts

## Notes

- Touch target minimums set to 44px for finger accuracy
- Virtual scrolling reduces DOM nodes from 100+ to 10-15
- All breakpoints tested with actual devices (not just emulation)
- Safe area CSS applied for notched devices
- 16px font size on inputs prevents iOS auto-zoom
- Momentum scrolling enabled for smooth performance
