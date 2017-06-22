import Core
import HTTP
import Transport
import AWSSignatureV4
import Vapor
import Foundation
import AEXML

@_exported import enum AWSSignatureV4.AWSError
@_exported import enum AWSSignatureV4.AccessControlList

public struct S3 {
    public enum Error: Swift.Error {
        case unimplemented
        case invalidResponse(Status)
        case invalidData
    }
    
    var signer: AWSSignatureV4
    private var _host : String
    private var _region : Region
  
    public var host: String {
      get {
        return _host
      }
      set (newVal) {
        _host = newVal
        signer.host = newVal
      }
    }
  
    public var region: Region {
      get {
        return _region
      }
      set (newVal) {
        _region = newVal
        signer.region = newVal.rawValue
      }
    }
  
    public init(
        host: String,
        accessKey: String,
        secretKey: String,
        region: Region
    ) {
        _host = host
        _region = region
        signer = AWSSignatureV4(
            service: "s3",
            host: host,
            region: region,
            accessKey: accessKey,
            secretKey: secretKey
        )
    }

    public func upload(bytes: Bytes, path: String, access: AccessControlList) throws {
        let url = generateURL(for: path)
        let headers = try signer.sign(
            payload: .bytes(bytes),
            method: .put,
            path: path
            //TODO(Brett): headers & AccessControlList
        )

        let response = try EngineClient.factory.put(url, headers, Body.data(bytes))
        try validateResponse(response)
    }

    public func get(path: String) throws -> Bytes {
        let url = generateURL(for: path)
        let headers = try signer.sign(path: path)
        
        let response = try EngineClient.factory.get(url, headers)
        guard response.status == .ok else {
            guard let bytes = response.body.bytes else {
                throw Error.invalidResponse(response.status)
            }
            
            throw try ErrorParser.parse(bytes)
        }
        
        guard let bytes = response.body.bytes else {
            throw Error.invalidResponse(.internalServerError)
        }
        
        return bytes
    }

    public func delete(file: String) throws {
        throw Error.unimplemented
    }
    
    public func listBucket(name: String, prefix: String, maxFiles: Int = 1000, getAllFiles: Bool = false) throws -> [S3File] {
      
        let items = try self.getItemsFromBucket(name: name, prefix: prefix, maxFiles: maxFiles, token: nil, getAllFiles: getAllFiles)
        return items.0
    }
    
    private func getItemsFromBucket(name: String, prefix: String, maxFiles: Int = 1000, token: String?, getAllFiles: Bool = false) throws -> ([S3File], String?) {
        let path = "/\(name)/"
        let url = generateURL(for: path)
        
        var query = Query()
        query.elements["list-type"] = "2"
        query.elements["max-keys"] = String(maxFiles)
        query.elements["prefix"] = prefix
        query.elements["delimiter"] = "/"
        
        let headers = try signer.sign(path: path, query: query.toString())

        let response = try EngineClient.factory.get(url, query: query.elements, headers, nil, through: [])
        
        try validateResponse(response)
        
        guard let bytes = response.body.bytes, let xmlData = String(data: Data(bytes: bytes, count: bytes.count), encoding: .utf8) else {
            throw Error.invalidResponse(.internalServerError)
        }
        
        var data = [S3File]()
        var getToken: String?
        
        do {
            let xmlDoc = try AEXMLDocument(xml: xmlData)
            let prefix = xmlDoc.root["Prefix"].value
            
            if let continuationToken = xmlDoc.root["NextContinuationToken"].value, let truncated = xmlDoc.root["IsTruncated"].value, truncated == "true" {
                getToken = continuationToken
            }
            
            if let contents = xmlDoc.root["Contents"].all {
                for content in contents {
                    if let item = S3File.createFile(fromItem: content), item.path != prefix {
                        data.append(item)
                    }
                }
            }
        }
        catch {
            throw Error.invalidData
        }
        
        if let token = getToken, getAllFiles == true {
            let newData = try self.getItemsFromBucket(name: name, prefix: prefix, maxFiles: maxFiles, token: token, getAllFiles: getAllFiles)
            data.append(contentsOf: newData.0)
        }
        
        return (data, token)
    }
    
    private func validateResponse(_ response: Response) throws {
        guard response.status == .ok else {
            guard let bytes = response.body.bytes else {
                throw Error.invalidResponse(response.status)
            }
            
            throw try ErrorParser.parse(bytes)
        }
    }
}

extension S3 {
    func generateURL(for path: String) -> String {
        //FIXME(Brett):
        return "https://\(host)\(path)"
    }
}

extension Dictionary where Key: CustomStringConvertible, Value: CustomStringConvertible {
    var vaporHeaders: [HeaderKey: String] {
        var result: [HeaderKey: String] = [:]
        self.forEach {
            result.updateValue($0.value.description, forKey: HeaderKey($0.key.description))
        }
        
        return result
    }
}
