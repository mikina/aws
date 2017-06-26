//
//  S3File.swift
//  AWS
//
//  Created by Mike Mikina on 6/22/17.
//
//

import Core
import HTTP
import Transport
import AWSSignatureV4
import Vapor
import Foundation
import AEXML

public struct S3File {
  public let path: String
  public let size: UInt64
  public let lastModified: Date
  public let ETag: String
  
  static func createFile(fromItem item: AEXMLElement) -> S3File? {
    
    guard let path = item["Key"].value,
      let size = item["Size"].value,
      let size64 = UInt64(size),
      let lastModified = item["LastModified"].value,
      let ETag = item["ETag"].value
      else {
        return nil
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    
    guard let lastModifiedDate = dateFormatter.date(from: lastModified) else {
      return nil
    }
    
    return S3File(path: path, size: size64, lastModified: lastModifiedDate, ETag: ETag)
  }
}

extension S3File: JSONRepresentable {
  public func makeJSON() throws -> JSON {
    var json = JSON()
    try json.set("path", path)
    try json.set("size", size)
    try json.set("lastModified", lastModified)
    try json.set("ETag", ETag)
    
    return json
  }
}
