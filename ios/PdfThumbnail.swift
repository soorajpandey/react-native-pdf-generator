import PDFKit

@objc(PdfThumbnail)
class PdfThumbnail: NSObject {

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    func getCachesDirectory() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getOutputFilename(filePath: String, page: Int) -> String {
        let components = filePath.components(separatedBy: "/")
        var prefix: String
        if let origionalFileName = components.last {
            prefix = origionalFileName.replacingOccurrences(of: ".", with: "-")
        } else {
            prefix = "pdf"
        }
        let random = Int.random(in: 0 ..< Int.max)
        return "\(prefix)-thumbnail-\(page)-\(random).jpg"
    }

    func generatePage(pdfPage: PDFPage, filePath: String, page: Int) -> Dictionary<String, Any>? {
        let pageRect = pdfPage.bounds(for: .mediaBox)
        let MAX_SIZE : CGFloat = 3000.0;
        var height : CGFloat = pageRect.height
        var width : CGFloat = pageRect.width

        if ( width > height ) {
            if ( width > MAX_SIZE ) {
                height *= MAX_SIZE / width;
                width = MAX_SIZE;
            }
        } else {
            if( height > MAX_SIZE) {
                width *= MAX_SIZE / height;
                height = MAX_SIZE;
            }
        }

        let image = pdfPage.thumbnail(of: CGSize(width: width, height: height), for: .mediaBox)
        let outputFile = getCachesDirectory().appendingPathComponent(getOutputFilename(filePath: filePath, page: page))
        guard let data = image.jpegData(compressionQuality: 80) else {
            return nil
        }
        do {
            try data.write(to: outputFile)
            return [
                "uri": outputFile.absoluteString,
                "width": Int(width),
                "height": Int(height),
            ]
        } catch {
            return nil
        }
    }
    
    @available(iOS 11.0, *)
    @objc(generate:withPage:withResolver:withRejecter:)
    func generate(filePath: String, page: Int, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        guard let fileUrl = URL(string: filePath) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfDocument = PDFDocument(url: fileUrl) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfPage = pdfDocument.page(at: page) else {
            reject("INVALID_PAGE", "Page number \(page) is invalid, file has \(pdfDocument.pageCount) pages", nil)
            return
        }

        if let pageResult = generatePage(pdfPage: pdfPage, filePath: filePath, page: page) {
            resolve(pageResult)
        } else {
            reject("INTERNAL_ERROR", "Cannot write image data", nil)
        }
    }

    @available(iOS 11.0, *)
    @objc(generateAllPages:withResolver:withRejecter:)
    func generateAllPages(filePath: String, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        guard let fileUrl = URL(string: filePath) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfDocument = PDFDocument(url: fileUrl) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }

        var result: [Dictionary<String, Any>] = []
        for page in 0..<pdfDocument.pageCount {
            guard let pdfPage = pdfDocument.page(at: page) else {
                reject("INVALID_PAGE", "Page number \(page) is invalid, file has \(pdfDocument.pageCount) pages", nil)
                return
            }
            if let pageResult = generatePage(pdfPage: pdfPage, filePath: filePath, page: page) {
                result.append(pageResult)
            } else {
                reject("INTERNAL_ERROR", "Cannot write image data", nil)
                return
            }
        }
        resolve(result)
    }
}
