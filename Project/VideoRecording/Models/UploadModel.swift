//
//  UploadModel.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 06/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import Foundation
let bucktRegion = "YourBucketRegion"
let fileNameUploaded = "<File name that you uploaded>"
class UploadModel{
    var tranferId: String = ""
    var progress: Double = 0.0
    var status: String = ""
    var failed: Bool = false
    var completed: Bool = false
    var inProgess: Bool = false
    var cancelled: Bool = false
    var paused: Bool = false
    var callbackUrlFormat: String =  "https://s3.\(bucktRegion).amazonaws.com/\(UploadManager.sharedInstance.S3BucketName)/\(fileNameUploaded)"
    init(_tranferId: String, _progress: Double, _status: String) {
        self.tranferId = _tranferId
        self.progress = _progress
        self.status = _status
    }
    
    
    init() {
        
    }
}
