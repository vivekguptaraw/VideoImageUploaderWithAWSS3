//
//  CallbacksHandler.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 06/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import Foundation
import AWSS3
class CallbacksHandler{
    //Simple upload completion
    var completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
    var progressBlock: AWSS3TransferUtilityProgressBlock?
    //Multipart upload completion
    var multipartProgressBlock: AWSS3TransferUtilityMultiPartProgressBlock?
    var multipartCompletionHandler: AWSS3TransferUtilityMultiPartUploadCompletionHandlerBlock?
    
    init() {
        
    }
}
