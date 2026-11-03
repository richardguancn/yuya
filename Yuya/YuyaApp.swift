import SwiftUI
import AppKit

@main
struct YuyaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var vm = ArchiveViewModel()
    @State private var showingPrivacy = false
    var body: some Scene {
        Window("Yuya", id: "main") {
            ContentView(vm: vm)
                .frame(minWidth: 920, minHeight: 620)
                .onAppear { delegate.viewModel = vm }
                .sheet(isPresented: $showingPrivacy) { PrivacyView() }
                .onReceive(OpenRequestCenter.shared.$revision) { _ in
                    vm.openExternally(OpenRequestCenter.shared.takePending())
                }
        }
        .defaultSize(width: 1080, height: 680)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(AppCopy.Label.privacy) { showingPrivacy = true }
            }
            CommandGroup(replacing: .newItem) {
                Button(AppCopy.Label.add, action: vm.pickFiles).keyboardShortcut("o").disabled(vm.busy)
                Button(AppCopy.Label.compress) { vm.section = .compress }.keyboardShortcut("1").disabled(vm.busy)
                Button(AppCopy.Label.extract) { vm.section = .extract }.keyboardShortcut("2").disabled(vm.busy)
                Button(AppCopy.Label.history) { vm.section = .history }.keyboardShortcut("3").disabled(vm.busy)
            }
            CommandMenu(AppCopy.Label.tools) {
                Button(AppCopy.Label.start, action: vm.run).keyboardShortcut(.return, modifiers: .command).disabled(!vm.canRun)
                Button(AppCopy.Label.cancel, action: vm.cancel).keyboardShortcut(".").disabled(!vm.isWorking)
                Divider()
                Button(AppCopy.Label.location, action: vm.revealResult).disabled(vm.lastOutputs.isEmpty)
                Button(AppCopy.Label.clear, action: vm.clear).disabled(vm.busy || vm.items.isEmpty)
            }
        }
    }
}

@MainActor
final class OpenRequestCenter: ObservableObject {
    static let shared = OpenRequestCenter()
    @Published private(set) var revision = 0
    private var pendingURLs: [URL] = []
    func enqueue(_ urls: [URL]) {
        pendingURLs.append(contentsOf: urls)
        revision &+= 1
    }
    func takePending() -> [URL] {
        let urls = pendingURLs
        pendingURLs.removeAll()
        return urls
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: ArchiveViewModel?
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppIcon.apply(to: NSApp)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        NSApp.setActivationPolicy(.regular)
        AppIcon.apply(to: NSApp)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func extractService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        let archives = urls.filter(ArchiveService.supports)
        guard !archives.isEmpty else { error.pointee = AppCopy.Description.service as NSString; return }
        NSApp.activate(ignoringOtherApps: true)
        OpenRequestCenter.shared.enqueue(archives)
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        NSApp.activate(ignoringOtherApps: true)
        OpenRequestCenter.shared.enqueue(urls)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let viewModel, viewModel.isWorking else { return .terminateNow }
        Task {
            await viewModel.finishBeforeTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
