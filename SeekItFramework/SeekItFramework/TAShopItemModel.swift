//
//  TAShopItemModel.swift
//  PanasonicTracker
//
//  Created by admin on 31/01/19.
//  Copyright © 2019 Wavenet Solutions. All rights reserved.
//

import Foundation

public class TAShopItemModel {
    
    public var image: String
    public var title: String
    public var description: String
    public var url: String
    
    public init (image: String, title: String, description: String, url: String) {
        self.image = image
        self.title = title
        self.description = description
        self.url = url
    }
}
