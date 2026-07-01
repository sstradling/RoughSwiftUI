//
//  OperationType.swift
//  Sketchy
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import Foundation

public enum OperationType: String {
    case move
    case bezierCurveTo = "bcurveTo"
    case lineTo
    case quadraticCurveTo = "qcurveTo"
    case close
}
