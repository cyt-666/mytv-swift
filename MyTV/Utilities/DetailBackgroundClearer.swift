import SwiftUI

#if os(macOS)
import AppKit

/// Walks up the NSView hierarchy from the SwiftUI hosting view
/// and clears backgrounds on all ancestors up to (but not including) the NSSplitView.
/// This makes the detail column transparent so the backdrop shows through the toolbar area.
struct DetailBackgroundClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.configureWindow(from: view)
            self.clearAncestorBackgrounds(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.configureWindow(from: nsView)
            self.clearAncestorBackgrounds(from: nsView)
        }
    }

    private func configureWindow(from view: NSView) {
        guard let window = view.window else { return }
        window.backgroundColor = .clear
        window.isOpaque = false
    }

    private func clearAncestorBackgrounds(from view: NSView) {
        // Walk up from this view, clearing backgrounds on all ancestors.
        // Stop at the NSSplitView to avoid affecting the sidebar column.
        var current = view.superview
        while let v = current {
            if v is NSSplitView { break }

            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.clear.cgColor

            if let effectView = v as? NSVisualEffectView {
                effectView.wantsLayer = true
                effectView.layer?.backgroundColor = NSColor.clear.cgColor
            }

            current = v.superview
        }

        // Also clear the toolbar area backgrounds at the window level
        clearToolbarBackgrounds(from: view)
    }

    private func clearToolbarBackgrounds(from view: NSView) {
        guard let window = view.window,
              let contentView = window.contentView else { return }

        // The toolbar views are siblings of the content view, above it in the window
        for subview in contentView.superview?.subviews ?? [] {
            if subview !== contentView {
                subview.wantsLayer = true
                subview.layer?.backgroundColor = NSColor.clear.cgColor

                if let effectView = subview as? NSVisualEffectView {
                    effectView.wantsLayer = true
                    effectView.layer?.backgroundColor = NSColor.clear.cgColor
                }
            }
        }
    }
}
#else
struct DetailBackgroundClearer: View {
    var body: some View {
        Color.clear
    }
}
#endif
