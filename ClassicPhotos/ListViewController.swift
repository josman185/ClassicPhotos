//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by Richard Turton on 03/07/2014.
//  Copyright (c) 2014 raywenderlich. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = URL(string:"http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController {
  
  //lazy var photos = NSDictionary(contentsOf:dataSourceURL!)!
    var photos = [PhotoRecord]()
    let pendingOperations = PendingOperations()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Classic Photos"
    fetchPhotoDetails()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // #pragma mark - Table view data source
  
  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath) 
    
    //1 To provide feedback to the user, create a UIActivityIndicatorView and set it as the cell’s accessory view.
    if cell.accessoryView == nil {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        cell.accessoryView = indicator
    }
    let indicator = cell.accessoryView as! UIActivityIndicatorView
    
    //2 The data source contains instances of PhotoRecord. Fetch the right one based on the current row’s indexPath.
    let photoDetails = photos[indexPath.row]
    
    //3
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    //4 Inspect the record. Set up the activity indicator and text as appropriate, and kick off the operations (not yet implemented)
    
    switch (photoDetails.state){
    case .Filtered:
        indicator.stopAnimating()
    case .Failed:
        indicator.stopAnimating()
        cell.textLabel?.text = "Failed to load"
    case .New, .Downloaded:
        indicator.startAnimating()
        
        // tell the table view to start operation only if the tableView is not scrolling.
        if (!tableView.isDragging && !tableView.isDecelerating){
            self.startOperationsForPhotoRecord(photoDetails: photoDetails,indexPath:indexPath as NSIndexPath)
        }
    }
    
    return cell
    }
    
    // UIScrillView delegate methods
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        //1 As soon as the user starts scrolling, you will want to suspend all operations
        suspendAllOperations()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //2 If the value of decelerate is false, that means the user stopped dragging the table view.
        if !decelerate {
            loadImagesForOnscreenCells()
            resumeAllOperations()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        //3 This delegate method tells you that table view stopped scrolling, so you will do the same as in #2.
        loadImagesForOnscreenCells()
        resumeAllOperations()
    }
    
    func suspendAllOperations() {
        pendingOperations.downloadQueue.isSuspended = true
        pendingOperations.filtrationQueue.isSuspended = true
    }
    
    func resumeAllOperations() {
        pendingOperations.downloadQueue.isSuspended = false
        pendingOperations.filtrationQueue.isSuspended = false
    }
    
    func loadImagesForOnscreenCells() {
        //1 Start with an array containing index paths of all the currently visible rows in the table view.
        if let pathsArray = tableView.indexPathsForVisibleRows{
            //2 Construct a set of all pending operations by combining all the downloads in progress + all the filters in progress. *** UNION Doesn't work ***
            let allPendingOperations = Set(pendingOperations.downloadsInProgress.keys)
            //allPendingOperations.union(pendingOperations.filtrationsInProgress.keys)
            
            //3 Construct a set of all index paths with operations to be cancelled. Start with all operations, and then remove the index paths of the visible rows. This will leave the set of operations involving off-screen rows.
            var toBeCancelled = allPendingOperations
            let visiblePaths = Set(pathsArray)
            toBeCancelled.subtract(visiblePaths as Set<NSIndexPath>)
            
            //4 Construct a set of index paths that need their operations started. Start with index paths all visible rows, and then remove the ones where operations are already pending.
            var toBeStarted = visiblePaths
            //toBeStarted.substract(allPendingOperations)
            toBeStarted.subtract(allPendingOperations as Set<IndexPath>)
            
            //5 Loop through those to be cancelled, cancel them, and remove their reference from PendingOperations.
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
                    pendingDownload.cancel()
                }
                pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
                if let pendingFiltration = pendingOperations.filtrationsInProgress[indexPath] {
                    pendingFiltration.cancel()
                }
                pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
            }
            
            //6 Loop through those to be started, and call startOperationsForPhotoRecord for each.
            for indexPath in toBeStarted {
                let indexPath = indexPath as NSIndexPath
                let recordToProcess = self.photos[indexPath.row]
                startOperationsForPhotoRecord(photoDetails: recordToProcess, indexPath: indexPath)
            }
        }
    }
    
    func startOperationsForPhotoRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
        switch (photoDetails.state) {
        case .New:
            startDownloadForRecord(photoDetails: photoDetails, indexPath: indexPath)
        case .Downloaded:
            startFiltrationForRecord(photoDetails: photoDetails, indexPath: indexPath)
        default:
            NSLog("do nothing")
        }
    }
    
    func startDownloadForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
        //1 First, check for the particular indexPath to see if there is already an operation in downloadsInProgress for it. If so, ignore it.
        if pendingOperations.downloadsInProgress[indexPath] != nil {
            return
        }
        
        //2 If not, create an instance of ImageDownloader by using the designated initializer.
        let downloader = ImageDownloader(photoRecord: photoDetails)
        //3 Add a completion block which will be executed when the operation is completed.
        downloader.completionBlock = {
            if downloader.isCancelled {
                return
            }
            DispatchQueue.main.async(execute: {
                self.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath as IndexPath], with: .fade)
            })
        }
        //4 Add the operation to downloadsInProgress to help keep track of things.
        pendingOperations.downloadsInProgress[indexPath] = downloader
        //5 Add the operation to the download queue.
        pendingOperations.downloadQueue.addOperation(downloader)
    }
    
    func startFiltrationForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
        if pendingOperations.filtrationsInProgress[indexPath] != nil{
            return
        }
        
        let filterer = ImageFiltration(photoRecord: photoDetails)
        filterer.completionBlock = {
            if filterer.isCancelled {
                return
            }
            DispatchQueue.main.async(execute: {
                self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath as IndexPath], with: .fade)
            })
        }
        pendingOperations.filtrationsInProgress[indexPath] = filterer
        pendingOperations.filtrationQueue.addOperation(filterer)
    }
    
    // method to download the phpto property list
    func fetchPhotoDetails() {
        let request = NSURLRequest(url:dataSourceURL!)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: OperationQueue.main) {response,data,error in
            
            //if data != nil <--- instead of this we use: Do try Catch
            do {
                let datasourceDictionary = try PropertyListSerialization.propertyList(from: data!, options: PropertyListSerialization.ReadOptions(rawValue: UInt(Int(PropertyListSerialization.MutabilityOptions.mutableContainers.rawValue))), format: nil) as! NSDictionary
                
                for (key,value) in datasourceDictionary {
                    let name = key as? String
                    let url = NSURL(string:value as? String ?? "")
                    if name != nil && url != nil {
                        let photoRecord = PhotoRecord(name:name!, url:url!)
                        self.photos.append(photoRecord)
                    }
                }
                
                self.tableView.reloadData()
            } catch let error as NSError {
                let alert = UIAlertView(title:"Oops!",message:error.localizedDescription, delegate:nil, cancelButtonTitle:"OK")
                alert.show()
            }
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
  
}
