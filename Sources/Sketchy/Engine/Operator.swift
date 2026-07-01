//
//  Operator.swift
//  Sketchy
//
//  Created by khoa on 20/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import Foundation

infix operator <-?

public func <-? <T>(root: inout T, value: T?) {
    guard let value = value else { return }
    root = value
}
