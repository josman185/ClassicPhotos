//
//  PhotoOperations.swift
//  ClassicPhotos
//
//  Created by jos on 1/19/17.
//  Copyright © 2017 raywenderlich. All rights reserved.
//

import Foundation
import UIKit

// This enums contain all the  possible states a photo record can be in
enum PhotoRecordState {
    case New, Downloaded, Filtered, Failed
}


class PhotoRecord {
    let name: String
    let url:NSURL
    var state = PhotoRecordState.New
    var image = UIImage(named: "Placeholder")
    
    init(name:String, url:NSURL) {
        self.name = name
        self.url = url
    }
}

class PendingOperations{
    
    lazy var downloadsInProgress = [NSIndexPath:Operation]()
    lazy var downloadQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    lazy var filtrationsInProgress = [NSIndexPath:Operation]()
    lazy var filtrationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Image Filtration queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

}

class ImageDownloader: Operation {

    //1 Add a constant reference to the PhotoRecord object related to the operation.
    let photoRecord : PhotoRecord
    
    //2 Create a designated initializer allowing the photo record to be passed in.
    init(photoRecord: PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    //3 main is the method you override in NSOperation subclasses to actually perform work.
    override func main(){
        
        //4 Check for cancellation before starting. Operations should regularly check if they have been cancelled before attempting long or intensive work.
        if self.isCancelled{
            return
        }
        //5 Download the image data.
        let imageData = NSData(contentsOf: self.photoRecord.url as URL)
        
        //6 Check again for cancellation.
        if self.isCancelled {
            return
        }
        
        //7 If there is data, create an image object and add it to the record, and move the state along. If there is no data, mark the record as failed and set the appropriate image.
        if (imageData?.length)! > 0 {
            self.photoRecord.image = UIImage(data: imageData! as Data)
            self.photoRecord.state = .Downloaded
        }
        else
        {
            self.photoRecord.state = .Failed
            self.photoRecord.image = UIImage(named: "Failed")
        }
    }
}


class ImageFiltration: Operation {
    let photoRecord: PhotoRecord
    
    init(photoRecord: PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    override func main() {
        if self.isCancelled{
            return
        }
        
        if self.photoRecord.state != .Downloaded {
            return
        }
        
        if let filteredImage = self.applySepiaFilter(image: self.photoRecord.image!) {
            self.photoRecord.image = filteredImage
            self.photoRecord.state = .Filtered
        }
    }
    
    func applySepiaFilter(image:UIImage) -> UIImage? {
        let inputImage = CIImage(data: UIImagePNGRepresentation(image)!)
        
        if self.isCancelled{
            return nil
        }
        let context = CIContext(options: nil)
        let filter = CIFilter(name: "CISepiaTone")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(0.8, forKey: "inputIntensity")
        let outputImage = filter?.outputImage
        
        if self.isCancelled{
            return nil
        }
        
        let outImage = context.createCGImage(outputImage!, from: (outputImage?.extent)!)
        let returnImage = UIImage(cgImage: outImage!)
        return returnImage
    }
}





