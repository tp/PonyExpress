//
//  File.swift
//  
//
//  Created by Adam Wulf on 10/1/22.
//

import Foundation

public struct Package<T>: Letter {
    public let contents: T
}