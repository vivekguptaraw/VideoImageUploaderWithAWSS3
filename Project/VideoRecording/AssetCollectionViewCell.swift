//
//  AssetCollectionViewCell.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 05/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import UIKit
import Photos
import AWSS3

protocol AssestUploadProtocol {
    func uploadAsset(urlString: String, indexPath: IndexPath, nsData: Data)
    func pauseClicked(urlString: String, transferId: String, indexPath: IndexPath)
    func resumeClicked(urlString: String, transferId: String, indexPath: IndexPath)
    func cancelClicked(urlString: String, transferId: String, indexPath: IndexPath)
}

class AssetCollectionViewCell: UICollectionViewCell {
    var asset: PHAsset?
//    open let imageView: UIImageView = {
//        let view = UIImageView.newAutoLayout()
//        view.backgroundColor = UIColor(rgbHex: 0xF0F0F0)
//        view.contentMode = .scaleAspectFill
//        view.clipsToBounds = true
//        return view
//    }()
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var resumeButton: UIButton!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var urlLabel: UILabel!
    var assetPathUrl: URL?
    var urlString: String = ""
    var assestUploadDelegate: AssestUploadProtocol?
    var transferId: String = ""
    var indexPath: IndexPath = IndexPath(row: 0, section: 0)
    var timer: Timer?
    var imageDataCount: Int = 0
    var uploadModel: UploadModel?
    var imageData: Data?
    override func awakeFromNib() {
        super.awakeFromNib()
        pauseButton.setTitle("Pause", for: .normal)
        resumeButton.setTitle("Resume", for: .normal)
        // Initialization code
        cancelButton.layer.cornerRadius = 25
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.clear.cgColor
        cancelButton.backgroundColor = UIColor.lightGray.withAlphaComponent(0.8)
        self.progressView.progress = 0.0;
        self.statusLabel.text = "Ready"
        self.imageView.alpha = 0.8
    }
    
    func startTimer() {
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.loop), userInfo: nil, repeats: true)
        }
    }
    
    func stopTimer() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @objc func loop() {
        self.upload()
    }
    
    var dataSize: Int = 0
    private func commonInit() {
    }
    
    func upload(){
        if let data = self.imageData{
            self.dataSize = data.count
            self.urlString = self.assetPathUrl!.absoluteString
            
            self.assestUploadDelegate?.uploadAsset(urlString: self.urlString, indexPath: self.indexPath, nsData: data)
            
        }else{
            //self.startTimer()
        }
    }
    
    func animateButton(btn: UIButton){
        UIView.animate(withDuration: 0.2,
                       animations: {
                        btn.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        },
                       completion: { _ in
                        UIView.animate(withDuration: 0.1) {
                            btn.transform = CGAffineTransform.identity
                        }
        })
    }
    
    @IBAction func cancelClicked(_ sender: UIButton) {
        self.animateButton(btn: sender)
        if self.transferId != ""{
            assestUploadDelegate?.cancelClicked(urlString: self.urlString, transferId: self.transferId, indexPath: self.indexPath)
        }
    }
    
    @IBAction func pauseClicked(_ sender: UIButton) {
        self.animateButton(btn: sender)
        if self.transferId != ""{
            assestUploadDelegate?.pauseClicked(urlString: self.urlString, transferId: self.transferId, indexPath: self.indexPath)
        }
    }
    @IBAction func resumeClicked(_ sender: UIButton) {
        self.animateButton(btn: sender)
        if self.transferId != ""{
            assestUploadDelegate?.resumeClicked(urlString: self.urlString, transferId: self.transferId, indexPath: self.indexPath)
        }
    }
    @IBAction func uploadClicked(_ sender: UIButton) {
        self.animateButton(btn: sender)
        print("simple upload fired \(Date())")
        self.statusLabel.text = "Preparing to upload"
        if let Url = self.assetPathUrl{
                let options: PHVideoRequestOptions = PHVideoRequestOptions()
                options.version = .original
                PHImageManager.default().requestExportSession(forVideo: self.asset!, options: options, exportPreset: AVAssetExportPresetHighestQuality , resultHandler: {[weak self] (session, info) in
                     guard let slf = self else {return}
                   
                        if let dic = info {
                            if let error = dic[PHImageErrorKey] {
                                print(error)
                                return
                            }else {
                                session?.outputURL = Url
                                let resources = PHAssetResource.assetResources(for: slf.asset!)
                                for resource in resources {
                                    session?.outputFileType = AVFileType(rawValue: resource.uniformTypeIdentifier)
                                    if let _ = session?.outputFileType {
                                        break
                                    }
                                }
                                session?.exportAsynchronously(completionHandler: {
                                    do{
                                        var data = try Data(contentsOf: Url, options: [])
                                        slf.imageDataCount = data.count
                                        slf.imageData = data
                                        slf.upload()
                                    }catch{
                                        
                                    }
                                    
                                })
                            }
                        }
                })
        }
    }
    
    func getURL(ofPhotoWith mPhasset: PHAsset, completionHandler : @escaping ((_ responseURL : URL?) -> Void)) {
        
        let res = PHAssetResource.assetResources(for: mPhasset)
        let ogFilename = res[0].originalFilename
        
        
        if mPhasset.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                return true
            }
            mPhasset.requestContentEditingInput(with: options, completionHandler: { (contentEditingInput, info) in
                completionHandler(contentEditingInput!.fullSizeImageURL)
            })
        } else if mPhasset.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .original
            
            PHImageManager.default().requestAVAsset(forVideo: mPhasset, options: options, resultHandler: { (asset, audioMix, info) in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl = urlAsset.url
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        //stopTimer()
        self.imageData = nil
        self.progressView.progress = 0.0
        self.uploadModel = nil
    }
    
}

