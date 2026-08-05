//
//  Item.swift
//  MiniBill
//
//  Created by Yokin Zhu on 2026/8/5.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
