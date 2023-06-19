//
//  FieldDescriptionMessage.swift
//  AntMessageProtocol
//
//  Created by Kevin Hoogheem on 10/26/19.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import DataDecoder
import FitnessUnits

/// FIT Field Description Message
///
/// For use with Developer Defined Data
@available(swift 4.2)
@available(iOS 10.0, tvOS 10.0, watchOS 3.0, OSX 10.12, *)
open class FieldDescriptionMessage: FitMessage {
    
    /// FIT Message Global Number
    public override class func globalMessageNumber() -> UInt16 { return 206 }
    
    /// Developer Data Index
    @FitField(base: BaseTypeData(type: .uint8, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 0)
    private(set) public var dataIndex: UInt8?
    
    /// Developer Field Definition Number
    @FitField(base: BaseTypeData(type: .uint8, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 1)
    private(set) public var definitionNumber: UInt8?
    
    @FitField(base: BaseTypeData(type: .enumtype, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 2)
    private var baseTypeId: BaseType?
    
    /// Field name
    @FitField(base: BaseTypeData(type: .string, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 3)
    private(set) public var fieldName: String?
    
    @FitField(base: BaseTypeData(type: .uint8, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 6)
    private var scale: UInt8?
    
    @FitField(base: BaseTypeData(type: .sint8, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 7)
    private var offset: Int8?
    
    /// Base Unit Type Information
    private(set) public var baseInfo: BaseTypeData? {
        get {
            let base = self.baseTypeId ?? .unknown
            let scale = self.scale ?? 1
            let offset = self.offset ?? 0
            
            return BaseTypeData(type: base,
                                resolution: Resolution(scale: Double(scale),
                                                       offset: Double(offset)))
        }
        set {
            self.baseTypeId = newValue?.type
            if let res = newValue?.resolution {
                self.scale = UInt8(res.scale)
                self.offset = Int8(res.offset)
            }
        }
    }
    
    /// Units name
    @FitField(base: BaseTypeData(type: .string, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 8)
    private(set) public var units: String?
    
    /// Base Units
    @FitField(base: BaseTypeData(type: .uint16, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 13)
    private(set) public var baseUnits: BaseUnitType?
    
    /// Message Number
    ///
    /// This will match up with the FitMessage.globalMessageNumber()
    @FitField(base: BaseTypeData(type: .uint16, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 14)
    private(set) public var messageNumber: UInt16?
    
    /// The Native Field Number
    @FitField(base: BaseTypeData(type: .uint8, resolution: Resolution(scale: 1.0, offset: 0.0)),
              fieldNumber: 15)
    private(set) public var fieldNumber: UInt8?
    
    public required init() {
        super.init()
        
        self.$dataIndex.owner = self
        self.$definitionNumber.owner = self
        self.$baseTypeId.owner = self
        self.$fieldName.owner = self
        self.$scale.owner = self
        self.$offset.owner = self
        self.$units.owner = self
        self.$baseUnits.owner = self
        self.$messageNumber.owner = self
        self.$fieldNumber.owner = self
    }
    
    public convenience init(dataIndex: UInt8?,
                            definitionNumber: UInt8?,
                            fieldName: String?,
                            baseInfo: BaseTypeData?,
                            units: String?,
                            baseUnits: BaseUnitType?,
                            messageNumber: UInt16?,
                            fieldNumber: UInt8?) {
        self.init()
        
        self.dataIndex = dataIndex
        self.definitionNumber = definitionNumber
        self.fieldName = fieldName
        self.baseInfo = baseInfo
        self.units = units
        self.baseUnits = baseUnits
        self.messageNumber = messageNumber
        self.fieldNumber = fieldNumber
    }
    
    /// Decode Message Data into FitMessage
    ///
    /// - Parameters:
    ///   - fieldData: FileData
    ///   - definition: Definition Message
    /// - Returns: FitMessage Result
    override func decode<F>(fieldData: FieldData, definition: DefinitionMessage) -> Result<F, FitDecodingError> where F: FitMessage {
        var testDecoder = DecodeData()
        
        var fieldDict: [UInt8: FieldDefinition] = [UInt8: FieldDefinition]()
        var fieldDataDict: [UInt8: Data] = [UInt8: Data]()
        
        for definition in definition.fieldDefinitions {
            let fieldData = testDecoder.decodeData(fieldData.fieldData, length: Int(definition.size))
            
            fieldDict[definition.fieldDefinitionNumber] = definition
            fieldDataDict[definition.fieldDefinitionNumber] = fieldData
        }
        
        let msg = FieldDescriptionMessage(fieldDict: fieldDict,
                                          fieldDataDict: fieldDataDict,
                                          architecture: definition.architecture)
        
        let devData = self.decodeDeveloperData(data: fieldData, definition: definition)
        msg.developerData = devData.isEmpty ? nil : devData
        
        return .success(msg as! F)
    }
	
	/// Encodes the Definition Message for FitMessage
	///
	/// - Parameters:
	///   - fileType: FileType
	///   - dataValidityStrategy: Validity Strategy
	/// - Returns: DefinitionMessage Result
	internal override func encodeDefinitionMessage(fileType: FileType?, dataValidityStrategy: FitFileEncoder.ValidityStrategy) -> Result<DefinitionMessage, FitEncodingError> {
		
		let fields = self.fieldDict.sorted { $0.key < $1.key }.map { $0.value }

		guard fields.isEmpty == false else {
			return.failure(self.encodeNoPropertiesAvailable())
		}
		
		let defMessage = DefinitionMessage(architecture: .little,
										   globalMessageNumber: Self.globalMessageNumber(),
										   fields: UInt8(fields.count),
										   fieldDefinitions: fields,
										   developerFieldDefinitions: devFieldDefinitions)
		
		return.success(defMessage)
	}
	
	/// Encodes the Message into Data
	///
	/// - Parameters:
	///   - localMessageType: Message Number, that matches the defintions header number
	///   - definition: DefinitionMessage
	/// - Returns: Data Result
	internal override func encode(localMessageType: UInt8, definition: DefinitionMessage) -> Result<Data, FitEncodingError> {
		
		guard definition.globalMessageNumber == type(of: self).globalMessageNumber() else  {
			return.failure(self.encodeWrongDefinitionMessage())
		}
		
		return self.encodeMessageFields(localMessageType: localMessageType)
	}
}

internal extension FieldDescriptionMessage {
    
    func decodeDeveloperDataType(developerData: DeveloperDataType) -> DeveloperDataBox? {
        guard developerData.dataIndex == self.dataIndex else { return nil }
        
        if let fieldNumber = self.definitionNumber {
            guard developerData.fieldNumber == fieldNumber else { return nil }
        }
        
        if let baseInfo = self.baseInfo {
            var decoder = DecodeData()
            
            guard developerData.data.isValidForBaseType(baseInfo.type) else { return nil }
			
			// If we do not match the sizes then we possibly need to decode an array of data.
			if baseInfo.type.size != -1, developerData.data.count / baseInfo.type.size > 1 {
				return decodeArrayDeveloperDataType(developerData: developerData, baseInfo: baseInfo)
			}
            
            switch baseInfo.type {
            case .enumtype, .uint8, .uint8z, .byte:
                let value = decoder.decodeUInt8(developerData.data)
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .sint8:
                let value = decoder.decodeInt8(developerData.data)
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .sint16:
                let value = developerData.architecture == .little ? decoder.decodeInt16(developerData.data).littleEndian : decoder.decodeInt16(developerData.data).bigEndian
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .uint16, .uint16z:
                let value = developerData.architecture == .little ? decoder.decodeUInt16(developerData.data).littleEndian : decoder.decodeUInt16(developerData.data).bigEndian
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .sint32:
                let value = developerData.architecture == .little ? decoder.decodeInt32(developerData.data).littleEndian : decoder.decodeInt32(developerData.data).bigEndian
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .float32:
                let value = decoder.decodeFloat32(developerData.data)
                
                if value.isNaN {
                    return nil
                }
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .uint32, .uint32z:
                let value = developerData.architecture == .little ? decoder.decodeUInt32(developerData.data).littleEndian : decoder.decodeUInt32(developerData.data).bigEndian
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .string:
                let stringData = decoder.decodeData(developerData.data, length: developerData.data.count)
                if stringData.count != 0 {
                    return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: stringData.smartString)
                }
                
            case .sint64:
                let value = developerData.architecture == .little ? decoder.decodeInt64(developerData.data).littleEndian : decoder.decodeInt64(developerData.data).bigEndian
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .float64:
                let value = decoder.decodeFloat64(developerData.data)
                if value.isNaN {
                    return nil
                }
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .uint64, .uint64z:
                let value = developerData.architecture == .little ? decoder.decodeUInt64(developerData.data).littleEndian : decoder.decodeUInt64(developerData.data).bigEndian
                let resValue = value.resolution(.removing, resolution: baseInfo.resolution)
                
                return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: resValue)
                
            case .unknown:
                return nil
            }
        }
        return nil
    }
}


internal extension FieldDescriptionMessage {
	
	// decode developer data for arrays...
	func decodeArrayDeveloperDataType(developerData: DeveloperDataType, baseInfo: BaseTypeData) -> DeveloperDataBox? {
		
		let data = developerData.data
		var decoder = DecodeData()

		switch baseInfo.type {
		case .enumtype, .uint8, .uint8z, .byte:
			var uInt8Array: [UInt8] = []
			for byte in data {
				let value = UInt8(byte)
				uInt8Array.append(value)
			}
			return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: uInt8Array)
		case .sint8:
			break
		case .sint16:
			var sInt16Array: [Int16] = []
			while decoder.index < data.count {
				let value = decoder.decodeInt16(developerData.data)
				sInt16Array.append(value)
			}
			return DeveloperDataValue(fieldName: self.fieldName, units: self.units, value: sInt16Array)
		case .uint16, .uint16z:
			break
		case .sint32:
			break
		case .uint32, .uint32z:
			break
		case .string:
			break
		case .float32:
			break
		case .float64:
			break
		case .sint64:
			break
		case .uint64, .uint64z:
			break
		case .unknown:
			break
		}
		return nil
	}
}

public extension FieldDescriptionMessage {
	
	func encode<T>(value: T) -> Data? {
		
		guard let baseInfo = self.baseInfo else {
			return nil
		}
		
		// Do we have an array>
		if value as? Array<Any> != nil {
			return dataForArrayValue(value: value, type: baseInfo.type)
		}
		else {
			return dataForValue(value: value, type: baseInfo.type, architecture: architecture)
		}
	}
	
	// TODO: - Test the living daylights out of this
	func dataForValue<T>(value: T, type: BaseType, architecture: Endian) -> Data? {
		switch type {
		case .uint8:
			if let value: UInt8 = value as? UInt8 {
				return Data(from: value)
			}
		case .enumtype, .uint8z, .byte, .sint8:
			return Data(from: value)
		case .sint16, .uint16z:
			if let value: Int16 = value as? Int16 {
				return Data(from: value)
			}
		case .uint16:
			if let value: UInt16 = value as? UInt16 {
				return Data(from: value)
			}
		case .uint32, .uint32z, .sint32:
			return Data.encode(value: value, architecture: architecture)
		case .string:
			return Data(from: value)
		case .float32:
			return Data(from: value)
		case .float64:
			return Data(from: value)
		case .sint64, .uint64, .uint64z:
			return Data.encode(value: value, architecture: architecture)
		case .unknown:
			return nil
		}
		return nil
	}

	// TODO: - Test the living daylights out of this
	func dataForArrayValue<T>(value: T, type: BaseType) -> Data? {
		var data = Data()
		switch type {
		case .enumtype, .uint8, .uint8z, .byte, .sint8:
			if let array = value as? [UInt8] {
				for uint8 in array {
					data.append(Data(from: uint8))
				}
			}
		case .sint16:
			if let array = value as? [Int16] {
				for int16 in array {
					data.append(Data(from: int16))
				}
			}
		case .uint16, .uint16z:
			return Data.encode(value: value, architecture: architecture)
		case .uint32, .uint32z, .sint32:
			return Data.encode(value: value, architecture: architecture)
		case .string:
			return Data(from: value)
		case .float32:
			return Data(from: value)
		case .float64:
			return Data(from: value)
		case .sint64, .uint64, .uint64z:
			return Data.encode(value: value, architecture: architecture)
		case .unknown:
			return nil
		}
		return data
	}
}
