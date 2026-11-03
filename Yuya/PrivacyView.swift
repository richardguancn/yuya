import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(AppCopy.Label.privacy).font(.title2.bold())
                Spacer()
                Button(AppCopy.Label.close) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    paragraph("文件留在本机", "Yuya 在你的 Mac 上压缩、查看和解压文件，不上传文件及文件内容，不需要注册或登录，也不需要网络。")
                    paragraph("由你选择文件", "应用只处理你通过选择窗口、拖放或访达打开的文件。结果保存在你选择的位置。压缩不会删除源文件，解压遇到同名文件夹时会另建文件夹。")
                    paragraph("记录保存在本机", "应用保存压缩偏好和最近 30 次完成记录，包括文件名称、保存位置、处理类型、完成时间、耗时及可获取的结果文件大小。应用会保存必要的文件访问凭据，方便你重启后定位结果。")
                    paragraph("随时清空记录", "在“最近记录”中点击“清空记录”，即可删除完成记录及对应访问凭据；这不会删除源文件和结果文件，也不会清除压缩偏好。")
                    paragraph("不收集或跟踪", "当前应用不向开发者传送个人数据，不跟踪用户，不包含广告、统计分析或崩溃上报服务。macOS 与 App Store 自身的数据处理由苹果的政策和你的系统设置决定。")
                    paragraph("联系支持", "如需帮助，请使用 App Store 页面提供的支持入口。请勿主动发送不必要的私密文件或密码。")
                    Text("更新日期：2026 年 10 月 27 日").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
        }
        .padding(24)
        .frame(width: 560, height: 600)
    }
    private func paragraph(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary).lineSpacing(4)
        }
    }
}
