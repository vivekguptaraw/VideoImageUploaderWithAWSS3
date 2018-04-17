//
//  MultipleUploadsViewController.swift
//  VideoRecording
//
//  Created by Vivek Gupta on 05/04/18.
//  Copyright © 2018 Vivek Gupta. All rights reserved.
//

import UIKit
import AssetsPickerViewController
import AssetsLibrary
import Photos
import AWSS3

class MultipleUploadsViewController: UIViewController,UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout  {
    
    @IBOutlet weak var collectionView: UICollectionView!
    var assetsArray: [String: PHAsset] = [:]
    let picker = AssetsPickerViewController()
    let reuseIdentifier = "collectionCell"
    @IBOutlet weak var addButton: UIButton!
    let itemsPerRow: CGFloat = 2
    override func viewDidLoad() {
        super.viewDidLoad()
       self.collectionView.register(UINib(nibName: "AssetCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: reuseIdentifier)
        NotificationCenter.default.addObserver(self, selector: #selector(getProgressDataUpdate), name: NSNotification.Name(rawValue: didProgressUpdateNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getCompletionUpdate), name: NSNotification.Name(rawValue: completionNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getFailedUpdate), name: NSNotification.Name(rawValue: failedNotification), object: nil)
         NotificationCenter.default.addObserver(self, selector: #selector(getContinuationUpdate), name: NSNotification.Name(rawValue: continuationNotification), object: nil)
        UploadManager.sharedInstance.dictTaskStatus.removeAll()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addClicked(_ sender: UIButton) {
        picker.pickerDelegate = self
        present(picker, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       return keyUrlArray.count
    }
    
    var keyUrlArray: [URL] = []
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! AssetCollectionViewCell
        
        let key = keyUrlArray[indexPath.row].absoluteString
        cell.assestUploadDelegate = self
        cell.asset = self.assetsArray[key]
        cell.urlLabel.text = "\(key) /\n Duration: \(self.stringFromTimeInterval(timeInterVal: cell.asset!.duration) )"
        cell.urlString = key
        cell.assetPathUrl = keyUrlArray[indexPath.row]
        cell.indexPath = indexPath
        cell.statusLabel.text = readyStatus
        if let model = UploadManager.sharedInstance.dictTaskStatus[key]{
            cell.uploadModel = model
            let progress = Float(model.progress)
            cell.transferId = model.tranferId
            DispatchQueue.main.async {
                cell.progressView.progress = progress
                cell.statusLabel.text = model.status
                
            }
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? AssetCollectionViewCell else  {
            print("Failed to cast UICollectionViewCell.")
            return
        }
        PHImageManager.default().getPhoto(asset: self.assetsArray[cell.urlString]!, size: cell.frame.size) { (image) in
            
            if let properImage = image
            {
                DispatchQueue.main.async {
                    cell.imageView.image = properImage
                }
            }
            else
            {
                cell.imageView.image  = UIImage()
            }
        }
    }
    
    @objc func getContinuationUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String{
                self.setUpdatedData(key: key, status: .InProgress)
            }
        }
    }
    
    @objc func getProgressDataUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String{
                self.setUpdatedData(key: key, status: .InProgress)
            }
        }
    }
    
    @objc func getCompletionUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String{
                self.setUpdatedData(key: key, status: .Success)
            }
        }
    }
    
    @objc func getFailedUpdate(noti : NSNotification){
        print(noti)
        if let userInfo = noti.userInfo{
            if let key = userInfo["taskKey"] as? String{
                self.setUpdatedData(key: key, status: .Failed)
            }
        }
    }
    
    func setUpdatedData(key: String, status: UploadStatus){
        
        for _cell in self.collectionView.visibleCells{
            DispatchQueue.main.async {[weak self] in
                if let cell = _cell as? AssetCollectionViewCell{
                    if key == cell.urlString{
                        if let uploadData =  UploadManager.sharedInstance.dictTaskStatus[key]{
                            cell.transferId = uploadData.tranferId
                            let progress = Float(uploadData.progress)
                            cell.progressView.progress = progress
                            cell.statusLabel.text = status.rawValue
                            cell.uploadModel = uploadData
                            if uploadData.inProgess{
                                //cell.uploadButton.isEnabled = false
                            }else {
                                //cell.uploadButton.isEnabled = true
                            }
                            if status == .Success && uploadData.completed && uploadData.progress == 1.0{
                                cell.uploadButton.isEnabled = true
                                print("progress 1.0 \(uploadData.status) \(key)")
                                cell.statusLabel.text = uploadData.status
                                UploadManager.sharedInstance.UpdateTaskDictionary(keyUrl: key)
                            }
                            if status == .Failed{
                                cell.uploadButton.isEnabled = true
                            }
                            
                        }
                        
                    }
                    
                }
            }
        }
        
    }
    
    
    deinit {
        //UploadManager.sharedInstance.dictTaskStatus.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let paddingSpace: CGFloat = 20
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    func updateCell(urlString: String, transferId: String, indexPath: IndexPath, status: UploadStatus){
        
        UploadManager.sharedInstance.reloadTaskDict(transferId: transferId, status: status, urlString: urlString) { (model) in
            if let cell = self.collectionView.cellForItem(at: indexPath) as? AssetCollectionViewCell{
                if let data = model{
                    cell.progressView.progress = Float(data.progress)
                    cell.statusLabel.text = data.status
                    cell.uploadModel = model
                    if status == .Cancelled{
                        cell.progressView.progress = 0.0
                        cell.uploadButton.isEnabled = true
                    }else if status == .Failed{
                        cell.uploadButton.isEnabled = true
                    }
                }else{
                    cell.progressView.progress = 0.0
                    cell.statusLabel.text = readyStatus
                }
            }
        }
        
        
    }
    
    func resetCellToDefaultState(indexPath: IndexPath){
        if let cell = self.collectionView.cellForItem(at: indexPath) as? AssetCollectionViewCell{
            cell.uploadModel = nil
            cell.statusLabel.text = readyStatus
            cell.uploadButton.isEnabled = true
            cell.progressView.progress = 0.0
        }
    }
    
    func stringFromTimeInterval(timeInterVal: TimeInterval) -> String {
        var hours: Int {
            return Int((timeInterVal.truncatingRemainder(dividingBy: 86400)) / 3600)
        }
        
        var minutes: Int {
            return Int((timeInterVal.truncatingRemainder(dividingBy: 3600)) / 60)
        }
        
        var seconds: Int {
            return Int(timeInterVal.truncatingRemainder(dividingBy: 60))
        }
        let (h, m, s) = (hours, minutes, seconds)
        if h > 0 {
            return String(format: "%02d:%02d:%02d", arguments: [h,m,s])
        }
        return String(format: "%02d:%02d", arguments: [m,s])
    }
    
    //////Get URL of Asset
    func getURL(ofPhotoWith mPhasset: PHAsset, completionHandler : @escaping ((_ responseURL : URL?) -> Void)) {
        
        let res = PHAssetResource.assetResources(for: mPhasset)
        _ = res[0].originalFilename
        
        
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
    
}

extension MultipleUploadsViewController: AssestUploadProtocol{
    
    func uploadAsset(urlString: String,indexPath: IndexPath, nsData: Data) {
        UploadManager.sharedInstance.uploadFile(with: nsData, name: urlString, contentType: .Video)
    }
    
    func pauseClicked(urlString: String, transferId: String, indexPath: IndexPath) {
        if let model = UploadManager.sharedInstance.dictTaskStatus[urlString]{
            if model.inProgess {
                self.updateCell(urlString: urlString, transferId: transferId, indexPath: indexPath, status: .Pause)
            }
        }
    }
    
    func cancelClicked(urlString: String, transferId: String, indexPath: IndexPath) {
        if let model = UploadManager.sharedInstance.dictTaskStatus[urlString]{
            if model.inProgess || model.paused || model.failed {
                self.updateCell(urlString: urlString, transferId: transferId, indexPath: indexPath, status: .Cancelled )
                
            }
        }
        self.resetCellToDefaultState(indexPath: indexPath)
        UploadManager.sharedInstance.removeCustomTaskModel(urlString: urlString)
    }
    
    func resumeClicked(urlString: String, transferId: String, indexPath: IndexPath) {
        if let model = UploadManager.sharedInstance.dictTaskStatus[urlString]{
            if model.paused {
                self.updateCell(urlString: urlString, transferId: transferId, indexPath: indexPath, status: .Resume )
            }
        }
    }
}

extension MultipleUploadsViewController: AssetsPickerViewControllerDelegate {
    
    func assetsPickerCannotAccessPhotoLibrary(controller: AssetsPickerViewController) {}
    func assetsPickerDidCancel(controller: AssetsPickerViewController) {}
    func assetsPicker(controller: AssetsPickerViewController, selected assets: [PHAsset]) {
        // do your job with selected assets
        self.assetsArray.removeAll()
        self.keyUrlArray.removeAll()
        let act = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        act.center = self.view.center
        act.startAnimating()
        act.hidesWhenStopped = true
        self.view.addSubview(act)
        let callback = {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                act.stopAnimating()
            }
        }
        for i in 0..<assets.count{
            self.getURL(ofPhotoWith: assets[i]) { (_url) in
                if let Url = _url{
                    let str = Url.absoluteString
                    self.assetsArray[str] = assets[i]
                    self.keyUrlArray.append(Url)
                    if assets.count == self.keyUrlArray.count{
                        callback()
                    }
                }
            }
        }
    }
    func assetsPicker(controller: AssetsPickerViewController, shouldSelect asset: PHAsset, at indexPath: IndexPath) -> Bool {
        if controller.selectedAssets.count > 10{
            return false
        }
        return true
    }
    func assetsPicker(controller: AssetsPickerViewController, didSelect asset: PHAsset, at indexPath: IndexPath) {}
    func assetsPicker(controller: AssetsPickerViewController, shouldDeselect asset: PHAsset, at indexPath: IndexPath) -> Bool {
        return true
    }
    func assetsPicker(controller: AssetsPickerViewController, didDeselect asset: PHAsset, at indexPath: IndexPath) {}
}

extension PHImageManager
{
    func getPhoto( asset : PHAsset, size : CGSize, completion : @escaping (_ image : UIImage?) -> ())
    {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = PHImageRequestOptionsResizeMode.exact
        options.deliveryMode = PHImageRequestOptionsDeliveryMode.highQualityFormat
        
        _ = self.requestImage(for: asset, targetSize: size, contentMode: PHImageContentMode.aspectFit, options: options, resultHandler: {
            
            result , _ in
            
            if let resultValue  = result as UIImage?
            {
                completion(resultValue)
            }
            else
            {
                completion(nil)
            }
        })
    }
}
