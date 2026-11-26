//
//  Item.swift
//  f1
//
//  Created by Ameya Palamwar on 26/11/26.
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
