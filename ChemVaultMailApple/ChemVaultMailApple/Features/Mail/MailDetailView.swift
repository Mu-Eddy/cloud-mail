import SwiftUI

struct MailDetailView: View {
    let email: ChemVaultEmail
    var markRead: () -> Void
    var delete: () -> Void
    var toggleStar: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(email.title)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)

                    Text(email.senderLine)
                        .font(.headline)

                    if let sendEmail = email.sendEmail {
                        Text(sendEmail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if let createTime = email.createTime {
                        Text(createTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                if let html = email.content, !html.isEmpty {
                    HTMLMessageView(html: html)
                        .frame(minHeight: 320)
                } else if let text = email.text, !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ContentUnavailableView("No message body", systemImage: "doc.text")
                }

                if let attachments = email.attList, !attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Attachments")
                            .font(.headline)
                        ForEach(attachments) { attachment in
                            AttachmentRowView(attachment: attachment)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Message")
        .toolbar {
            ToolbarItemGroup {
                Button(action: markRead) {
                    Label("Read", systemImage: "envelope.open")
                }
                .disabled(!email.isUnread)
                Button(action: toggleStar) {
                    Label(email.starred ? "Unstar" : "Star", systemImage: email.starred ? "star.slash" : "star")
                }
                Button(role: .destructive, action: delete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .task(id: email.emailId) {
            if email.isUnread {
                markRead()
            }
        }
    }
}

struct AttachmentRowView: View {
    let attachment: ChemVaultAttachment

    var body: some View {
        HStack {
            Image(systemName: "paperclip")
            VStack(alignment: .leading) {
                Text(attachment.filename ?? attachment.key)
                    .lineLimit(1)
                if let size = attachment.size {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
