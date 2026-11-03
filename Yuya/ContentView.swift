import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let yuyaAccent = Color(nsColor: NSColor(name: "YuyaAccent") { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(calibratedRed: 0.32, green: 0.78, blue: 0.80, alpha: 1)
        : NSColor(calibratedRed: 0.04, green: 0.43, blue: 0.47, alpha: 1)
})

struct ContentView: View {
    @ObservedObject var vm: ArchiveViewModel
    @State private var isTargeted = false
    @State private var showErrorDetail = false
    @State private var sortOrder = [KeyPathComparator(\ArchiveItem.name, comparator: .localizedStandard)]
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                if vm.section == .history { history }
                else {
                    HStack(spacing: 0) {
                        workspace
                        Divider()
                        inspector
                    }
                }
                Divider()
                statusBar
            }
        }
        .tint(yuyaAccent)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $vm.showingPreview, onDismiss: vm.closePreview) { ArchivePreviewView(vm: vm) }
        .sheet(isPresented: $showErrorDetail) {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppCopy.Label.errorTitle).font(.title2.bold())
                ScrollView { Text(vm.statusDetail).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack { Spacer(); Button(AppCopy.Label.close) { showErrorDetail = false }.keyboardShortcut(.cancelAction) }
            }.padding(24).frame(width: 560, height: 300)
        }
        .background {
            Group {
                Button(AppCopy.Label.search) { searchFocused = true }.keyboardShortcut("f")
            }.hidden()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                BrandIcon(size: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Yuya").font(.system(size: 21, weight: .bold, design: .rounded))
                    Text(AppCopy.Description.purpose).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 16).padding(.top, 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(AppCopy.Label.tools).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.bottom, 5)
                ForEach(WorkspaceSection.allCases) { section in
                    Button {
                        vm.section = section; vm.search = ""; vm.selection = []
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.symbol).font(.system(size: 15)).frame(width: 20)
                            Text(section.title).font(.system(size: 12, weight: vm.section == section ? .semibold : .regular))
                            Spacer(minLength: 0)
                            if section == .history && !vm.history.isEmpty {
                                Text("\(vm.history.count)").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(vm.section == section ? yuyaAccent : Color.primary.opacity(0.78))
                        .padding(.horizontal, 12).padding(.vertical, 11)
                        .background(vm.section == section ? yuyaAccent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(vm.busy)
                }
            }.padding(.horizontal, 10)
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                Label(AppCopy.Label.privateFiles, systemImage: "lock.shield").font(.system(size: 11, weight: .medium))
                Text(AppCopy.Description.noUpload).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(17)
        }
        .frame(width: 176)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(vm.section.title).font(.system(size: 21, weight: .semibold))
                Text(vm.section == .compress ? AppCopy.Description.compress : vm.section == .extract ? AppCopy.Description.extract : AppCopy.Description.history)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if vm.section != .history {
                Button(action: vm.pickFiles) { Label(AppCopy.Label.add, systemImage: "plus") }
                    .disabled(vm.busy).keyboardShortcut("o").controlSize(.large)
            } else {
                Button(AppCopy.Label.clearHistory, action: vm.clearHistory).disabled(vm.history.isEmpty || vm.busy).help(AppCopy.Description.clearHistory)
            }
        }.padding(.horizontal, 26).padding(.vertical, 23)
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            if !vm.items.isEmpty {
                HStack {
                    Text(AppCopy.Label.waiting).font(.system(size: 11, weight: .semibold))
                    Text("\(vm.items.count)").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(.quaternary, in: Capsule())
                    Spacer()
                    if !vm.selection.isEmpty {
                        Button(action: vm.removeSelection) { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).help(AppCopy.Description.removeHint).accessibilityLabel(AppCopy.Label.remove).disabled(vm.busy)
                        if vm.selection.count == 1, vm.selection.first.map(ArchiveService.supports) == true {
                            Button(action: previewSelection) { Image(systemName: "eye") }
                                .buttonStyle(.borderless).help(AppCopy.Label.preview).accessibilityLabel(AppCopy.Label.preview).disabled(vm.busy)
                        }
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(AppCopy.Label.search, text: $vm.search).textFieldStyle(.plain).focused($searchFocused)
                    }.font(.system(size: 11)).padding(7).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6)).frame(width: 160)
                }.padding(.horizontal, 20).padding(.vertical, 15)
                fileTable
                if vm.section == .extract && vm.archives.count != vm.items.count {
                    Label(AppCopy.Description.invalidArchive, systemImage: "exclamationmark.circle")
                        .font(.system(size: 11)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                }
                HStack {
                    Text(vm.inputSummary).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Button(AppCopy.Label.clear, action: vm.clear).help(AppCopy.Description.clearList).buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary).disabled(vm.busy)
                }.padding(.horizontal, 20).padding(.vertical, 12)
            } else { emptyWorkspace }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 10).fill(yuyaAccent.opacity(0.08))
                RoundedRectangle(cornerRadius: 10).strokeBorder(yuyaAccent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(8).allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted, perform: vm.handleDrop)
    }

    private var emptyWorkspace: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(yuyaAccent.opacity(0.045)).frame(width: 154, height: 154)
                BrandIcon(size: 142)
            }.padding(.bottom, 23)
            Text(AppCopy.Label.drop)
                .font(.system(size: 24, weight: .semibold))
            Text(vm.section == .compress ? AppCopy.Description.dropFiles : AppCopy.Description.dropArchives)
                .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 11)
            Button(action: vm.pickFiles) { Text(AppCopy.Label.add).frame(minWidth: 106) }
                .controlSize(.large).padding(.top, 24).disabled(vm.busy)
            Text(vm.section == .compress ? AppCopy.Description.multiple : AppCopy.Description.supported)
                .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 18)
            Spacer()
            HStack(spacing: 20) {
                Label(AppCopy.Description.dropHint, systemImage: "cursorarrow.and.square.on.square.dashed")
                Text("⌘ O  \(AppCopy.Label.add)")
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.bottom, 26)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 20)
    }

    private var fileTable: some View {
        Table(vm.filteredItems.sorted(using: sortOrder), selection: $vm.selection, sortOrder: $sortOrder) {
            TableColumn(AppCopy.Label.name, value: \.name) { item in
                HStack(spacing: 9) {
                    Image(nsImage: FileIconCache.image(for: item.url)).resizable().frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.url.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(item.url.deletingLastPathComponent().path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }.padding(.vertical, 6).help(item.url.path)
            }.width(min: 180, ideal: 300)
            TableColumn(AppCopy.Label.size, value: \.size) { item in
                Text(item.sizeDescription).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }.width(min: 60, ideal: 80, max: 110)
        }
        .contextMenu(forSelectionType: URL.self) { urls in
            Button(AppCopy.Label.preview) { if let item = vm.items.first(where: { urls.contains($0.url) }) { vm.preview(item) } }
                .disabled(urls.count != 1 || !urls.contains(where: ArchiveService.supports))
            Button(AppCopy.Label.location) { vm.reveal(Array(urls)) }.disabled(urls.isEmpty)
            Divider()
            Button(AppCopy.Label.remove) { vm.selection = urls; vm.removeSelection() }.help(AppCopy.Description.removeHint).disabled(vm.busy || urls.isEmpty)
        } primaryAction: { urls in
            if let item = vm.items.first(where: { urls.contains($0.url) }), ArchiveService.supports(item.url) { vm.preview(item) }
            else { vm.reveal(Array(urls)) }
        }
        .overlay { if vm.filteredItems.isEmpty { Text(AppCopy.Label.noResults).foregroundStyle(.secondary) } }
        .disabled(vm.busy)
        .onDeleteCommand(perform: vm.removeSelection)
        .onKeyPress(.space) { previewSelection(); return .handled }
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(vm.section == .compress ? AppCopy.Label.compressOptions : AppCopy.Label.extractOptions).font(.system(size: 12, weight: .semibold))
                    if vm.section == .compress {
                        VStack(alignment: .leading, spacing: 10) {
                                optionLabel(AppCopy.Label.format)
                                HStack { Image(systemName: "doc.zipper").foregroundStyle(yuyaAccent); Text("ZIP").fontWeight(.semibold); Spacer(); Text(AppCopy.Label.common).foregroundStyle(.secondary) }
                                    .font(.system(size: 11)).padding(12).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                                Text(AppCopy.Description.common)
                                    .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                optionLabel(AppCopy.Label.preference)
                                Picker(AppCopy.Label.preference, selection: $vm.compressionLevel) {
                                    ForEach(CompressionLevel.allCases) { level in Text(level.title).tag(level) }
                                }.labelsHidden().pickerStyle(.segmented)
                                Text(vm.compressionLevel.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Divider()
                            Toggle(AppCopy.Label.tidy, isOn: $vm.excludeMetadata).font(.system(size: 11)).toggleStyle(.checkbox)
                            Text(AppCopy.Description.tidy)
                                .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true).padding(.top, -14)
                        } else {
                            infoBlock(AppCopy.Label.separate, AppCopy.Description.separate, "folder.badge.plus")
                            infoBlock(AppCopy.Label.keep, AppCopy.Description.keep, "checkmark.shield")
                            infoBlock(AppCopy.Label.inspect, AppCopy.Description.inspect, "eye")
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Toggle(AppCopy.Label.reveal, isOn: $vm.revealWhenDone).font(.system(size: 11)).toggleStyle(.checkbox)
                            Text(AppCopy.Description.autoReveal).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 9) {
                            Text(AppCopy.Label.destination).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                            Text(vm.section == .compress ? AppCopy.Description.compressLocation : AppCopy.Description.extractLocation)
                                .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(21)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 10) {
                Button(action: vm.run) {
                    HStack { Text(vm.section == .compress ? AppCopy.Label.startCompress : AppCopy.Label.startExtract); Spacer(); Image(systemName: "arrow.right") }
                        .font(.system(size: 12, weight: .semibold)).padding(.vertical, 6).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!vm.canRun).keyboardShortcut(.return, modifiers: .command)
                Text("⌘ ↵  \(vm.section == .compress ? AppCopy.Label.startCompress : AppCopy.Label.startExtract)").font(.system(size: 10)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 21).padding(.top, 12).padding(.bottom, 18)
        }
        .frame(width: 232).frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        .disabled(vm.busy)
    }
    private func optionLabel(_ text: String) -> some View { Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary) }
    private func infoBlock(_ title: String, _ detail: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(yuyaAccent)
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
        }
    }
    private var history: some View {
        Group {
            if vm.history.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "clock").font(.system(size: 44, weight: .light)).foregroundStyle(.tertiary)
                    Text(AppCopy.Label.noHistory).font(.title3.weight(.medium))
                    Text(AppCopy.Description.historyEmpty)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.history) { record in
                    HStack(spacing: 14) {
                        Image(systemName: record.action == "压缩" ? "doc.zipper" : "folder")
                            .font(.system(size: 24)).foregroundStyle(yuyaAccent).frame(width: 34)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.name).font(.system(size: 13, weight: .medium))
                            Text(record.output.deletingLastPathComponent().path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("\(record.action)完成 · \(record.duration.formatted(.number.precision(.fractionLength(1)))) 秒")
                            Text(record.date, style: .date)
                        }.font(.system(size: 10)).foregroundStyle(.secondary)
                        Button { vm.revealRecord(record) } label: { Image(systemName: "folder") }
                            .help(AppCopy.Label.location).accessibilityLabel(AppCopy.Label.location)
                    }.padding(.vertical, 12)
                }.listStyle(.inset).scrollContentBackground(.hidden)
            }
        }.background(Color(nsColor: .textBackgroundColor))
    }
    private var statusBar: some View {
        HStack(spacing: 11) {
            if vm.isWorking || vm.isImporting { ProgressView().controlSize(.small) }
            else {
                Image(systemName: vm.statusIsError ? "exclamationmark.circle.fill" : vm.lastOutputs.isEmpty ? "checkmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(vm.statusIsError ? Color.orange : vm.lastOutputs.isEmpty ? Color.secondary : Color.green)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(vm.statusMessage).font(.system(size: 11, weight: .medium))
                    if !vm.batchPosition.isEmpty { Text(vm.batchPosition).font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit() }
                    if let progress = vm.progress {
                        Text("已处理 \(ByteCountFormatter.string(fromByteCount: progress.bytes, countStyle: .file)) · \(progress.count) 项")
                            .font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Text(vm.statusDetail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if vm.statusIsError { Button(AppCopy.Label.details) { showErrorDetail = true }.font(.system(size: 11)) }
            if vm.isWorking { Button(vm.cancelling ? AppCopy.Label.cancelling : AppCopy.Label.cancel, action: vm.cancel).disabled(vm.cancelling).keyboardShortcut(.cancelAction) }
            else if !vm.lastOutputs.isEmpty { Button(AppCopy.Label.location, action: vm.revealResult).font(.system(size: 11)) }
        }.padding(.horizontal, 22).frame(height: 62)
    }
    private func previewSelection() {
        guard let item = vm.items.first(where: { vm.selection.contains($0.url) }) else { return }
        vm.preview(item)
    }
}

private struct ArchivePreviewView: View {
    @ObservedObject var vm: ArchiveViewModel
    @State private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "doc.zipper").font(.system(size: 26)).foregroundStyle(yuyaAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.previewTitle).font(.title3.weight(.semibold)).lineLimit(1)
                    Text(AppCopy.Description.preview).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(AppCopy.Label.close, action: vm.closePreview).keyboardShortcut(.cancelAction)
            }.padding(22)
            Divider()
            if vm.previewLoading { ProgressView(AppCopy.Label.loading).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let error = vm.previewError {
                VStack(alignment: .leading, spacing: 14) {
                    Label(AppCopy.Label.cannotPreview, systemImage: "exclamationmark.circle").font(.headline)
                    Text(error.components(separatedBy: "\n").first ?? error)
                        .textSelection(.enabled).foregroundStyle(.secondary)
                    if error.contains("\n") {
                        DisclosureGroup(AppCopy.Label.systemDetails) {
                            ScrollView {
                                Text(error.components(separatedBy: "\n").dropFirst().joined(separator: "\n"))
                                    .font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(maxHeight: 160)
                        }.font(.caption)
                    }
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let manifest = vm.previewManifest {
                HStack {
                    Text("\(manifest.count) 项 · 解压后 \(manifest.totalBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "大小未知")")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    TextField(AppCopy.Label.search, text: $search).textFieldStyle(.roundedBorder).frame(width: 210)
                }.padding(16)
                Table(manifest.entries.filter { search.isEmpty || $0.path.localizedStandardContains(search) }) {
                    TableColumn(AppCopy.Label.name) { entry in
                        Label(entry.path, systemImage: entry.isDirectory ? "folder" : "doc").font(.system(size: 12)).lineLimit(1).help(entry.path)
                    }.width(min: 350, ideal: 450)
                    TableColumn(AppCopy.Label.size) { entry in
                        Text(entry.isDirectory ? "—" : entry.size < 0 ? AppCopy.Label.unknown : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }.width(100)
                }
                if manifest.isTruncated {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppCopy.Description.previewLimit)
                        Text(AppCopy.Description.previewMore)
                    }.font(.caption).foregroundStyle(.secondary).padding(14)
                }
            }
        }.frame(width: 720, height: 500)
    }
}

@MainActor
private enum FileIconCache {
    static let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 512
        return cache
    }()
    static func image(for url: URL) -> NSImage {
        if let image = cache.object(forKey: url as NSURL) { return image }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

@MainActor
private struct BrandIcon: View {
    let size: CGFloat
    private static let artwork: NSImage = {
        AppIcon.image ?? NSApp.applicationIconImage
    }()
    var body: some View {
        Image(nsImage: Self.artwork).resizable().interpolation(.high)
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}
