# Mobile Optimization Guide

This guide documents mobile optimization standards implemented in OpenCode Nexus for iOS and Android platforms.

## Touch Target Standards

### Minimum Touch Target Size: 44×44 pixels
- **Standard**: All interactive elements (buttons, links, form inputs) must have a minimum touch target of 44×44 pixels
- **Rationale**: Apple HIG and Android Material Design recommend 44-48px minimum for accurate finger tapping
- **Implementation**: Use `min-width: 44px; min-height: 44px;` CSS property
- **Padding Strategy**: Add sufficient padding around icons to meet the 44px requirement

### Components with 44px Touch Targets
1. **MessageInput.svelte**
   - Send button: 44×44px (mobile), 48×48px (tablet+)
   - Textarea: min-height 44px (mobile), 48px (tablet+)

2. **SessionPanel.svelte**
   - Create session button: 44×44px (inline in header)
   - Toggle expand/collapse button: 44×44px (was 32px, upgraded)
   - Error dismiss button: 44×44px (was 0px padding, upgraded)

3. **ChatSessionCard.svelte**
   - Delete button: 44×44px (was 0.25rem padding, upgraded)
   - Card itself: Full width clickable area (min 44px height)

4. **ChatInterface.svelte**
   - Virtual scrolling container with proper touch event handling
   - Swipe gesture support (SWIPE_THRESHOLD = 50px)
   - Pull-to-refresh gesture (PULL_THRESHOLD = 80px)

### Spacing Between Touch Targets
- **Minimum Gap**: 8px between interactive elements to prevent accidental taps
- **Recommended**: 12px gap for better thumb accessibility on 6" screens
- **Implementation**: Use `gap` property in flex layouts or `margin` for spacing

## Responsive Layout Strategy

### Mobile First (0-768px)
- Single column layout with stacked elements
- Full-width sidebar for session list (max-height: 200px)
- Touch-friendly bottom sheet for input
- Larger text sizes (16px base font)
- Simplified navigation

**Key Breakpoints**:
- Small phones (<360px): Extra padding reduction
- Standard phones (360-600px): Standard mobile layout
- Large phones (600-768px): Prepare for tablet

### Tablet (768-1024px)
- Split view: 280px sidebar + main content
- Hover states become primary interaction
- Slightly larger touch targets (48px)
- Compact but visible controls

**Layout Changes**:
```css
@media (min-width: 768px) {
  .sessions-sidebar {
    width: 280px;
  }
  .send-btn {
    width: 48px;
    height: 48px;
  }
}
```

### Desktop (1024px+)
- Full sidebar: 320px
- 48px touch targets (sufficient for mouse precision)
- Hover effects enabled
- Keyboard shortcuts available

## Font Sizing for Mobile

### Base Font Size Strategy
- **Mobile**: 16px base font (prevents iOS auto-zoom on input focus)
- **Textarea/Input**: Always 16px to avoid zoom trigger
- **Labels**: 14px (0.875rem)
- **Captions**: 12px (0.75rem)
- **Large text**: 18-20px (headings)

**Important**: Never use font-size < 16px on input elements on mobile

```css
textarea {
  font-size: 16px; /* Prevents iOS zoom on focus */
}
```

## Safe Area & Notch Handling

### Implementation for Native Apps
Use Tauri's safe area insets for notched devices:

```css
/* Use padding/margin with safe-area-inset values */
.chat-container {
  padding-left: max(1rem, env(safe-area-inset-left));
  padding-right: max(1rem, env(safe-area-inset-right));
  padding-top: max(1rem, env(safe-area-inset-top));
  padding-bottom: max(1rem, env(safe-area-inset-bottom));
}
```

### Current Implementation
- Header uses full width with header padding
- Sidebar and main content properly contained
- No fixed elements in safe area

## Orientation & Viewport Handling

### Portrait Orientation (Primary)
- Single column layout
- SessionPanel as expandable header
- ChatInterface takes remaining space
- MessageInput at bottom (above keyboard)

### Landscape Orientation
- Reduced height for landscape viewport
- SessionPanel may collapse to icon-only (future enhancement)
- MessageInput positioned above keyboard

**Implementation**:
```css
@media (orientation: landscape) and (max-height: 500px) {
  .sessions-sidebar {
    max-height: 100px; /* Reduced for landscape */
  }
}
```

### Dynamic Viewport Height
```css
.chat-container {
  height: 100vh;
  height: 100dvh; /* Use dynamic viewport height on mobile */
}
```

## Scroll Performance Optimization

### Virtual Scrolling
- ChatInterface implements virtual scrolling for large conversations
- Only renders visible messages + 5-message buffer
- Estimated item height: 80px per message
- Reduces DOM nodes from 100+ to ~10-15

### Touch Scroll Enhancement
- Native scroll on mobile devices (no interference)
- `-webkit-overflow-scrolling: touch` for smooth momentum scrolling
- Custom scrollbar styling for better UX on tablet

```css
.messages-container {
  overflow-y: auto;
  -webkit-overflow-scrolling: touch; /* Momentum scrolling on iOS */
}

.messages-container::-webkit-scrollbar {
  width: 6px;
}
```

## Gesture Support

### Touch Gestures Implemented
1. **Tap**: Select session, send message
2. **Long Press**: Future - context menus
3. **Swipe**: Navigation between sessions (future)
4. **Pull-to-Refresh**: Reload messages (ChatInterface)
5. **Pinch-to-Zoom**: Browser default (not disabled)

### Gesture Configuration
```typescript
// ChatInterface.svelte
const SWIPE_THRESHOLD = 50;  // Minimum swipe distance
const PULL_THRESHOLD = 80;   // Pull-to-refresh distance
```

## Input Optimization

### Keyboard Handling
- 16px font size prevents iOS auto-zoom
- `autocorrect="off"` disabled for code snippets
- `autocapitalize="off"` for proper casing
- Textarea auto-expands to fit content

### Mobile Keyboard Optimization
```html
<textarea
  placeholder="..."
  inputmode="text"
  autocorrect="off"
  autocapitalize="off"
  spellcheck="false"
/>
```

### Form Inputs
- `inputmode="email"` for email fields
- `inputmode="tel"` for phone fields
- `inputmode="decimal"` for numeric input
- Proper `type` attribute for semantic meaning

## Network Optimization

### Offline Support
- Messages queued when offline (ChatInterface)
- Retry mechanism with exponential backoff
- Offline indicator showing queued message count
- Syncs automatically when connection restored

### Connection State
```typescript
$isOnline // Store subscription
$queuedMessageCount // Messages pending sync
```

## CSS Techniques for Mobile

### Flex Layout for Responsive Design
```css
.chat-layout {
  display: flex;
  flex-direction: column; /* Mobile first */
}

@media (min-width: 768px) {
  .chat-layout {
    flex-direction: row; /* Horizontal on tablet+ */
  }
}
```

### Avoiding Common Mobile CSS Issues

1. **Fixed Positioning with Keyboard**
   - Use `position: sticky` instead of `fixed` for inputs
   - Avoid viewport lock with virtual keyboard

2. **Touch Highlight Color**
   ```css
   button {
     -webkit-tap-highlight-color: transparent;
   }
   ```

3. **Text Selection Prevention**
   ```css
   .no-select {
     user-select: none;
     -webkit-user-select: none;
   }
   ```

4. **Image Rendering**
   ```css
   img {
     image-rendering: -webkit-optimize-contrast; /* Crisp on mobile */
   }
   ```

## Accessibility on Mobile

### Screen Reader Support
- All buttons have `aria-label` attributes
- Form inputs have `aria-describedby` for help text
- Status updates use `aria-live="polite"`
- Semantic HTML (button, input, textarea)

### Keyboard Navigation
- Tab navigation works across all interactive elements
- Enter key sends messages (Shift+Enter for new line)
- Escape key closes modals/panels
- Arrow keys for message navigation (future)

### High Contrast Mode
```css
@media (prefers-contrast: high) {
  /* Enhanced colors for better visibility */
  button {
    border: 2px solid hsl(0, 0%, 0%);
  }
}
```

### Reduced Motion
```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Performance Metrics for Mobile

### Target Performance
- **First Contentful Paint (FCP)**: < 2 seconds
- **Largest Contentful Paint (LCP)**: < 2.5 seconds
- **Cumulative Layout Shift (CLS)**: < 0.1
- **Time to Interactive (TTI)**: < 3.5 seconds

### Bundle Size Targets
- Initial JS: < 500KB (mobile networks)
- CSS: < 50KB
- Images: < 100KB (auto-scaled)

### Memory Usage
- Chat with 100+ messages: < 15MB
- Virtual scrolling keeps DOM < 50 nodes

## Testing Mobile Optimization

### Browser DevTools
1. **Chrome DevTools**
   - Device emulation (iPhone 12, Pixel 6, etc.)
   - Touch simulation
   - Network throttling (Slow 4G)
   - Lighthouse audit

2. **Safari DevTools**
   - iOS simulator
   - Safe area visualization
   - Viewport debugging

### Real Device Testing
- **iOS**: iPhone 12 mini (5.4"), iPhone 14 (6.1"), iPhone 14 Plus (6.7")
- **Android**: Pixel 4a (5.8"), Pixel 6 Pro (6.7")

### Test Checklist
- [ ] All buttons reach 44×44px minimum
- [ ] Form inputs are 16px font size
- [ ] Responsive layout at 375px, 768px, 1024px
- [ ] Landscape orientation works
- [ ] Touch scrolling smooth on device
- [ ] Gestures work (swipe, pull)
- [ ] Offline functionality works
- [ ] Screen reader announces all elements
- [ ] High contrast mode readable
- [ ] No layout shifts during load

## Future Enhancements

- [ ] Web App Install Prompt (PWA)
- [ ] Status bar safe area handling
- [ ] Bottom sheet for inputs (iOS)
- [ ] Haptic feedback for interactions
- [ ] App icon support
- [ ] Splash screen customization
- [ ] Hardware acceleration for scrolling
- [ ] Native context menus
- [ ] Gesture-based navigation
- [ ] App shortcuts on home screen

## References

- [Apple Human Interface Guidelines - Touch](https://developer.apple.com/design/human-interface-guidelines/ios/user-interaction/gestures/)
- [Android Material Design - Touch targets](https://material.io/design/platform-guidance/android-bars.html)
- [Web Content Accessibility Guidelines - Touch](https://www.w3.org/TR/WCAG21/#target-size-enhanced)
- [MDN Web Docs - Mobile Viewports](https://developer.mozilla.org/en-US/docs/Mozilla/Mobile/Viewport_meta_tag)
