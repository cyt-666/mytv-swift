import AppKit
import SwiftUI

struct NativeSegmentedControl<Value: Hashable>: NSViewRepresentable {
    @Binding var selection: Value
    let items: [Value]
    let title: (Value) -> String
    var controlSize: NSControl.ControlSize = .large

    func makeCoordinator() -> NativeSegmentedControlCoordinator {
        NativeSegmentedControlCoordinator()
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: items.map(title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(NativeSegmentedControlCoordinator.selectionChanged(_:))
        )
        configure(control)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.onSelectionChanged = { index in
            guard items.indices.contains(index) else { return }
            selection = items[index]
        }

        if control.segmentCount != items.count {
            control.segmentCount = items.count
        }

        for index in items.indices {
            control.setLabel(title(items[index]), forSegment: index)
            control.setEnabled(true, forSegment: index)
        }

        control.selectedSegment = items.firstIndex(of: selection) ?? -1
        configure(control)
    }

    private func configure(_ control: NSSegmentedControl) {
        control.segmentStyle = .rounded
        control.controlSize = controlSize
        control.font = .systemFont(
            ofSize: NSFont.systemFontSize(for: controlSize),
            weight: .semibold
        )
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

final class NativeSegmentedControlCoordinator: NSObject {
    var onSelectionChanged: (Int) -> Void = { _ in }

    @MainActor
    @objc func selectionChanged(_ sender: NSSegmentedControl) {
        onSelectionChanged(sender.selectedSegment)
    }
}
