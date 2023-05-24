//
//  File.swift
//  
//
//  Created by Antony Gardiner on 24/05/23.
//

import Foundation

public extension Data {
	
	static func encode<T>(value: T, architecture: Endian) -> Data {
		
		var data = Data(from: value)
		switch architecture {
		case .little:
			break
		case .big:
			data = Data(from: data.reversed())
		}
		return data
	}
	
}
