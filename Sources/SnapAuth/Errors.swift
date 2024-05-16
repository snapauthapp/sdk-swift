//
//  File.swift
//  
//
//  Created by Eric Stern on 5/15/24.
//

//import Foundation

public enum AuthenticationError: Error {
    /// The user canceled
    case canceled
    /// There was a network interruption
    case networkDisrupted

    case asAuthorizationError
    // ...
}
