//
//  VideoStepViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 14.10.15.
//  Copyright © 2015 Alex Karpov. All rights reserved.
//

import UIKit
import MediaPlayer
import SVProgressHUD
import DownloadButton
import FLKAutoLayout

class VideoStepViewController: UIViewController {

    var moviePlayer : MPMoviePlayerController? = nil
    var video : Video!
    var nItem : UINavigationItem!
    var step: Step!
    var assignment : Assignment?
    var parentNavigationController : UINavigationController?
    
    var nextLessonHandler: (Void->Void)?
    var prevLessonHandler: (Void->Void)?
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    @IBOutlet weak var discussionCountView: DiscussionCountView!
    @IBOutlet weak var discussionCountViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var prevLessonButton: UIButton!
    @IBOutlet weak var nextLessonButton: UIButton!
    @IBOutlet weak var nextLessonButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var prevLessonButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var discussionToPrevDistance: NSLayoutConstraint!
    @IBOutlet weak var discussionToNextDistance: NSLayoutConstraint!
    @IBOutlet weak var prevToBottomDistance: NSLayoutConstraint!
    @IBOutlet weak var nextToBottomDistance: NSLayoutConstraint!
    
    var imageTapHelper : ImageTapHelper!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(VideoStepViewController.updatedStepNotification(_:)), name: StepsViewController.stepUpdatedNotification, object: nil)
    
                
        imageTapHelper = ImageTapHelper(imageView: thumbnailImageView, action: { 
            [weak self]
            recognizer in
            self?.playVideo()
        })
        
        nextLessonButton.setTitle("  \(NSLocalizedString("NextLesson", comment: ""))  ", forState: .Normal)
        prevLessonButton.setTitle("  \(NSLocalizedString("PrevLesson", comment: ""))  ", forState: .Normal)
        
        initialize()
    }
    
    func initialize() {
        thumbnailImageView.sd_setImageWithURL(NSURL(string: video.thumbnailURL), placeholderImage: Images.videoPlaceholder)
        
        if let discussionCount = step.discussionsCount {
            discussionCountView.commentsCount = discussionCount
            discussionCountView.showCommentsHandler = {
                [weak self] in
                self?.showComments()
            }
        } else {
            discussionCountViewHeight.constant = 0
        }
        
        if nextLessonHandler == nil {
            nextLessonButton.hidden = true
        } else {
            nextLessonButton.setStepicWhiteStyle()
        }
        
        if prevLessonHandler == nil {
            prevLessonButton.hidden = true
        } else {
            prevLessonButton.setStepicWhiteStyle()
        }
        
        if nextLessonHandler == nil && prevLessonHandler == nil {
            nextLessonButtonHeight.constant = 0
            prevLessonButtonHeight.constant = 0
            discussionToNextDistance.constant = 0
            discussionToPrevDistance.constant = 0
            prevToBottomDistance.constant = 0
            nextToBottomDistance.constant = 0
        }
    }
    
    func updatedStepNotification(notification: NSNotification) {
        initialize()
    }
    
    private func playVideo() {
        if video.state == VideoState.Cached || (ConnectionHelper.shared.reachability.isReachableViaWiFi() || ConnectionHelper.shared.reachability.isReachableViaWWAN()) {
            let player = StepicVideoPlayerViewController(nibName: "StepicVideoPlayerViewController", bundle: nil)
            player.video = self.video
            self.presentViewController(player, animated: true, completion: {
                print("stepic player successfully presented!")
            })
        } else {
            if let vc = self.parentNavigationController {
                Messages.sharedManager.showConnectionErrorMessage(inController: vc)
            }
        }
    }
    
    @IBAction func playButtonPressed(sender: UIButton) {
        playVideo()
    }
    
    var itemView : VideoDownloadView!
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        itemView = VideoDownloadView(frame: CGRect(x: 0, y: 0, width: 100, height: 30), video: video, buttonDelegate: self, downloadDelegate: self)
        nItem.rightBarButtonItem = UIBarButtonItem(customView: itemView)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        if let a = assignment {
            let cstep = step
            ApiDataDownloader.sharedDownloader.didVisitStepWith(id: step.id, assignment: a.id, success: {
                NSNotificationCenter.defaultCenter().postNotificationName(StepDoneNotificationKey, object: nil, userInfo: ["id" : cstep.id])
                UIThread.performUI{
                    cstep.progress?.isPassed = true
                    CoreDataHelper.instance.save()
                }
            }) 
        }
    }
    
    @IBAction func showCommentsPressed(sender: AnyObject) {
        showComments()
    }
    
    func showComments() {
        if let discussionProxyId = step.discussionProxyId {
            let vc = DiscussionsViewController(nibName: "DiscussionsViewController", bundle: nil) 
            vc.discussionProxyId = discussionProxyId
            vc.target = self.step.id
            navigationController?.pushViewController(vc, animated: true)
        } else {
            //TODO: Load comments here
        }
    }

    @IBAction func prevLessonPressed(sender: UIButton) {
        prevLessonHandler?()
    }
    
    @IBAction func nextLessonPressed(sender: UIButton) {
        nextLessonHandler?()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
}

extension VideoStepViewController : PKDownloadButtonDelegate {
    func downloadButtonTapped(downloadButton: PKDownloadButton!, currentState state: PKDownloadButtonState) {
        switch downloadButton.state {
        case .StartDownload: 
            
            if !ConnectionHelper.shared.isReachable {
                Messages.sharedManager.show3GDownloadErrorMessage(inController: self.navigationController!)
                print("Not reachable to download")
                return
            }
            
            downloadButton.state = .Downloading
            video.store(VideosInfo.videoQuality, progress: {
                prog in
                UIThread.performUI({downloadButton.stopDownloadButton?.progress = CGFloat(prog)})
                }, completion: {
                    completed in
                    if completed {
                        UIThread.performUI({downloadButton.state = .Downloaded})
                    } else {
                        UIThread.performUI({downloadButton.state = .StartDownload})
                    }
                }, error: {
                    error in
                    print("Error while downloading video!!!")
            })
            break
        case .Downloaded:
            if video.removeFromStore() {
                downloadButton.state = .StartDownload
            } 
            break
        case .Downloading:
            if video.cancelStore() {
                downloadButton.state = .StartDownload
            }
            break
        case .Pending:
            break
        }
        itemView.updateButton()
    }
}

extension VideoStepViewController : VideoDownloadDelegate {

    func didDownload(video: Video, cancelled: Bool) {
    }
    
    func didGetError(video: Video) {
        itemView.updateButton()
    }
}
