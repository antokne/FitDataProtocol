//
//  DataEncoderTests.swift
//  
//
//  Created by Antony Gardiner on 24/05/23.
//

import XCTest
import DataDecoder
@testable import FitDataProtocol

final class DataEncoderTests: XCTestCase {
	
	override func setUpWithError() throws {
	}
	
	override func tearDownWithError() throws {
	}
	
	func testEncodeData() throws {
		
		let uint8Value: UInt8 = 255
		var data = Data(from: uint8Value)
		
		var decoder = DecodeData()
		let uint8DecodedValue = decoder.decodeUInt8(data)
		
		XCTAssertEqual(uint8Value, uint8DecodedValue)
		
		let uint16Value: UInt16 = 64000
		data = Data(from: uint16Value)

		decoder = DecodeData()
		let uint16DecodedValue = decoder.decodeUInt16(data)
		
		XCTAssertEqual(uint16Value, uint16DecodedValue)

	}
	
	
	
}
