//
//  Query.swift
//  AWS
//
//  Created by Mike Mikina on 6/5/17.
//
//

import Foundation

public struct Query {
    var elements: [String: String] = [:]
    
    public func toString() -> String {
        
        let sortedQuery = alphabetize(self.elements)
        return sortedQuery.map { "\($0.key.lowercased())=\($0.value)" }.joined(separator: "&")
    }
    
    private func alphabetize(_ dict: [String : String]) -> [(key: String, value: String)] {
        return dict.sorted(by: { $0.0.lowercased() < $1.0.lowercased() })
    }
}
