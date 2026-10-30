import Foundation
import UserNotifications

// Uses the image_url supplied by our WordPress sender; no extra SDK is needed.
final class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        DispatchQueue.main.async {
            self.handler = contentHandler
            self.content = request.content.mutableCopy() as? UNMutableNotificationContent
            guard self.content != nil,
                  let value = request.content.userInfo["image_url"] as? String,
                  let url = URL(string: value), url.scheme?.lowercased() == "https",
                  ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased()) else {
                self.finish(fallback: request.content)
                return
            }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 20
            let session = URLSession(configuration: configuration)
            self.session = session
            self.task = session.downloadTask(with: url) { location, response, error in
                // Move the temporary download before returning from this callback.
                var attachment: UNNotificationAttachment?
                if error == nil, let location = location,
                   let response = response as? HTTPURLResponse,
                   response.statusCode == 200, response.url?.scheme?.lowercased() == "https",
                   ["image/jpeg", "image/png"].contains(response.mimeType?.lowercased() ?? ""),
                   let size = try? location.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                   size > 0, size <= 1_048_576 {
                    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    let file = directory.appendingPathComponent("news." + url.pathExtension.lowercased())
                    do {
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        try FileManager.default.moveItem(at: location, to: file)
                        attachment = try UNNotificationAttachment(identifier: "news", url: file)
                    } catch {
                        // Keep the original headline and body when the image is unavailable.
                    }
                }
                let downloadedAttachment = attachment
                DispatchQueue.main.async {
                    guard self.handler != nil else { return }
                    if let attachment = downloadedAttachment { self.content?.attachments = [attachment] }
                    self.finish(fallback: request.content)
                }
            }
            self.task?.resume()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        DispatchQueue.main.async {
            if let content = self.content { self.finish(fallback: content) }
        }
    }

    private func finish(fallback: UNNotificationContent) {
        guard let handler = handler else { return }
        self.handler = nil
        task?.cancel()
        session?.invalidateAndCancel()
        handler(content ?? fallback)
    }
}
