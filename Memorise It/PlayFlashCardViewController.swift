//
//  PlayFlashCardViewController.swift
//  Memorise It
//
//  Created by Maarut Chandegra on 08/12/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import AVFoundation

class PlayFlashCardViewController: UIViewController
{
    var flashCard: FlashCard?
    
    @IBOutlet weak var informationOverlayContainer: UIView!
    @IBOutlet weak var informationOverlayText: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    fileprivate var audioPlayer: AVAudioPlayer?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        if let flashCard = flashCard {
            imageView.image = flashCard.image
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: flashCard.audio.url)
            }
            catch let error as NSError {
                NSLog("\(error.description)\n\(error.localizedDescription)")
            }
        }
        informationOverlayContainer.layer.cornerRadius = 10
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.isHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3, delay: 5.0, animations: {
            self.informationOverlayContainer.alpha = 0.0
            self.informationOverlayText.alpha = 0.0
        }, completion: { _ in
            self.informationOverlayText.isHidden = true
            self.informationOverlayContainer.isHidden = true
        })
    }
    
    @IBAction func tapRecognised(_ sender: UITapGestureRecognizer)
    {
        sender.removeTarget(self, action: #selector(tapRecognised(_:)))
        sender.addTarget(self, action: #selector(stopPlayback(_:)))
        audioPlayer?.play()
    }
    
    func stopPlayback(_ sender: UITapGestureRecognizer)
    {
        sender.removeTarget(self, action: #selector(stopPlayback(_:)))
        sender.addTarget(self, action: #selector(tapRecognised(_:)))
        audioPlayer?.stop()
    }
}

private class ProxyUIGestureRecogniserDelegate: NSObject, UIGestureRecognizerDelegate
{
    var target: UIGestureRecognizerDelegate
    
    init(target: UIGestureRecognizerDelegate)
    {
        self.target = target
        super.init()
    }
    
    override func forwardingTarget(for aSelector: Selector!) -> Any?
    {
        return target
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    {
        return true
    }
}
