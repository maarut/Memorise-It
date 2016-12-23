//
//  PlayFlashCardViewController.swift
//  Memorise It
//
//  Created by Maarut Chandegra on 08/12/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import AVFoundation

fileprivate let kPlayFlashCardViewControllerErrorDomain = "net.maarut.Memorise-It.PlayFlashCardViewController"

class PlayFlashCardViewController: UIViewController
{
    var flashCard: FlashCard?
    
    @IBOutlet weak var informationOverlayContainer: UIView!
    @IBOutlet weak var informationOverlayText: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet var tapGestureRecogniser: UITapGestureRecognizer!
    
    fileprivate var audioPlayer: AVAudioPlayer?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        if let flashCard = flashCard {
            if let imageData = flashCard.image as Data? {
                imageView.image = UIImage(data: imageData)
            }
            do {
                if let audioURLString = flashCard.audioFileName {
                    let audioURL = try pathToAudioFile(audioURLString)
                    audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                    audioPlayer?.delegate = self
                }
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
        let newNavItem = UINavigationItem(title: "Hello")
        newNavItem.backBarButtonItem = UIBarButtonItem(title: "Hello", style: .plain, target: self,
                                                       action: #selector(hello(_:)))
        navigationController?.navigationBar.pushItem(newNavItem, animated: true)
        sender.removeTarget(self, action: #selector(tapRecognised(_:)))
        sender.addTarget(self, action: #selector(stopPlayback(_:)))
        audioPlayer?.currentTime = 0.0
        audioPlayer?.play()
    }
    
    func hello(_ sender: UIBarButtonItem)
    {
        NSLog("tapped")
        let _ = navigationController?.navigationBar.popItem(animated: true)
    }
    
    func stopPlayback(_ sender: UITapGestureRecognizer)
    {
        sender.removeTarget(self, action: #selector(stopPlayback(_:)))
        sender.addTarget(self, action: #selector(tapRecognised(_:)))
        audioPlayer?.stop()
    }
}

// MARK: - AVAudioPlayerDelegate Implementation
extension PlayFlashCardViewController: AVAudioPlayerDelegate
{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    {
        stopPlayback(tapGestureRecogniser)
    }
}

// MARK: - Private Functions
fileprivate extension PlayFlashCardViewController
{
    func pathToAudioFile(_ fileName: String) throws -> URL
    {
        if let directory = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask).first {
            return directory.appendingPathComponent(fileName)
        }
        throw NSError(domain: kPlayFlashCardViewControllerErrorDomain,
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey :"Could not get a path to the Documents directory for the current user",
            ])
    }
}
