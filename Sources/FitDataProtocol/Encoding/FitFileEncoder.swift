//
//  FitFileEncoder.swift
//  FitDataProtocol
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

/// FIT File Encoder
@available(swift 4.2)
@available(iOS 10.0, tvOS 10.0, watchOS 3.0, OSX 10.12, *)
public struct FitFileEncoder {

    /// Options for Validity Strategy
    public enum ValidityStrategy {
        /// The default strategy assumes you know what type of Messages should be
        /// included with each type of file.
        case none
        /// File Type Checking
        ///
        /// This will check to make sure you have the correct Messages include for
        /// the file type indicated in the FileIdMessage.
        case fileType
        /// Garmin Connect Activity
        ///
        /// Garmin Connect reqiures some extra Messages in the Activity file type
        /// in order for it to be uploaded.
        case garminConnect
    }

    /// The strategy to use for Data Validity Strategy. Defaults to `.none`.
    public var dataValidityStrategy: ValidityStrategy

    /// Init FitFileEncoder
    ///
    /// - Parameter dataValidityStrategy: Validity Strategy
    public init(dataValidityStrategy: ValidityStrategy = .none) {
        self.dataValidityStrategy = dataValidityStrategy
    }
}

public extension FitFileEncoder {
	
	/// Encode FITFile
	///
	/// - Parameters:
	///   - filedIdMessage: FileID Message
	///   - messages: Array of other FitMessages
	///   - developerDataIDs: Need a developer data messages with field decriptions.
	///   - fieldDescriptions: list of developer field description messages to encode dev data with
	/// - Returns: Data Result
    func encode(fileIdMessage: FileIdMessage,
				messages: [FitMessage],
				developerDataIDs: [DeveloperDataIdMessage] = [],
				fieldDescriptions: [FieldDescriptionMessage] = []) -> Result<Data, FitEncodingError> {

        guard messages.count > 0 else {
            return.failure(FitEncodingError.noMessages)
        }

        var msgData = Data()

        let validator = EncoderValidator.validate(fildIdMessage: fileIdMessage, messages: messages, dataValidityStrategy: dataValidityStrategy)
        switch validator {
        case .success(_):
            break
        case .failure(let error):
            return.failure(error)
        }
		
		// encode file id message
		switch encodeDefintionAndMessage(message: fileIdMessage, fileType: fileIdMessage.fileType) {
		case .success(let data):
			msgData.append(data)
		case .failure(let error):
			return .failure(error)
		}
		
		// encode develoepr data ids messages, if any.
		for developerDataID in developerDataIDs {
			switch encodeDefintionAndMessage(message: developerDataID, fileType: fileIdMessage.fileType) {
			case .success(let data):
				msgData.append(data)
			case .failure(let error):
				return .failure(error)
			}
		}
		
		// encode field Description messages, if any.
		for fieldDescription in fieldDescriptions {
			switch encodeDefintionAndMessage(message: fieldDescription, fileType: fileIdMessage.fileType) {
			case .success(let data):
				msgData.append(data)
			case .failure(let error):
				return .failure(error)
			}
		}
		
		var lastDefinition: DefinitionMessage!

        for message in messages {

            if message is FileIdMessage {
                return.failure(FitEncodingError.multipleFileIdMessage)
            }

            // Endocde the Definition
            let def = message.encodeDefinitionMessage(fileType: fileIdMessage.fileType, dataValidityStrategy: dataValidityStrategy)
            switch def {
            case .success(let definition):
                if lastDefinition != definition {
                    lastDefinition = definition
                    msgData.append(encodeDefHeader(index: 0, definition: lastDefinition))
                }
                
            case .failure(let error):
                return.failure(error)
            }

            // Endode the Message
            switch message.encode(localMessageType: 0, definition: lastDefinition) {
            case .success(let data):
                msgData.append(data)
				
				// Encode the developer data fields if there are any for this message.
				msgData.append(message.encodeDeveloperData(fieldDescriptions: fieldDescriptions))
				
            case .failure(let error):
                return.failure(error)
            }
        }

        if msgData.count > UInt32.max {
            return.failure(FitEncodingError.tooManyMessages)
        }

        let header = FileHeader(dataSize: UInt32(msgData.count))

        let dataCrc = CRC16(data: msgData).crc
        msgData.append(Data(from:dataCrc.littleEndian))

        var fileData = Data()
        fileData.append(header.encodedData)
        fileData.append(msgData)

        return.success(fileData)
    }
	
	private func encodeDefintionAndMessage(message: FitMessage, fileType: FileType?) -> Result<Data, FitEncodingError> {
		
		var definitionMessage: DefinitionMessage?
		
		switch message.encodeDefinitionMessage(fileType: fileType, dataValidityStrategy: dataValidityStrategy) {
		case .success(let definition):
			definitionMessage = definition
		case .failure(let error):
			return.failure(error)
		}
		
		guard let definitionMessage else {
			return .failure(FitEncodingError.wrongDefinitionMessage("Unable to generate definition message for \(message)"))
		}
		
		var msgData = Data()
		msgData.append(encodeDefHeader(index: 0, definition: definitionMessage))
		
		switch message.encode(localMessageType: 0, definition: definitionMessage) {
		case .success(let data):
			msgData.append(data)
		case .failure(let error):
			return.failure(error)
		}
		return.success(msgData)
	}
	
	private func encodeDefHeader(index: UInt8, definition: DefinitionMessage) -> Data {
		var msgData = Data()
		
		let hasDeveloperData = definition.developerFieldDefinitions.count > 0
		let defHeader = RecordHeader(localMessageType: index, isDataMessage: false, developerData: hasDeveloperData)
		msgData.append(defHeader.normalHeader)
		msgData.append(definition.encode())
		
		return msgData
	}

}
