import AppKit
import SwiftUI

@main
struct OppoPodsMacApp: App {
    @StateObject private var viewModel = EarbudsViewModel()

    init() {
        BluetoothMonitor.shared.start()
        Self.configureApplicationIcon()
    }

    var body: some Scene {
        WindowGroup("", id: "main") {
            MainWindowView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.start()
                }
        }
        .defaultSize(width: 768, height: 720)
        .commands {
            CommandMenu("设备") {
                Button("刷新电量") {
                    Task {
                        await viewModel.refreshBattery()
                    }
                }
                .disabled(!canRefreshBattery)

                Button("重连") {
                    Task {
                        await viewModel.reconnect()
                    }
                }
                .disabled(viewModel.isBusy)

                Button("连接") {
                    Task {
                        await viewModel.connect()
                    }
                }
                .disabled(!canConnect)
            }
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.start()
                }
        } label: {
            Image("oppobuds.bud.large")
                .font(.system(size: 24, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .accessibilityLabel("OppoPodsMac")
        }
        .menuBarExtraStyle(.window)
    }

    private static func configureApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "oppoPods", withExtension: "icns"),
              let iconImage = NSImage(contentsOf: iconURL) else {
            return
        }

        NSApplication.shared.applicationIconImage = iconImage
    }

    private var canRefreshBattery: Bool {
        viewModel.state.connectionStatus == .connected && !viewModel.isBusy
    }

    private var canConnect: Bool {
        guard !viewModel.isBusy else { return false }

        switch viewModel.state.connectionStatus {
        case .disconnected, .error, .handshakeFailed:
            return true
        case .connected, .connecting, .handshaking, .reconnecting:
            return false
        }
    }
}
