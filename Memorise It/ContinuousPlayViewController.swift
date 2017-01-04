//
//  ContinuousPlayViewController.swift
//  Memorise It
//
//  Created by Maarut Chandegra on 03/01/2017.
//  Copyright © 2017 Maarut Chandegra. All rights reserved.
//

import UIKit
import AVFoundation

private let kContinuousePlayViewControllerErrorDomain = "net.maarut.Memorise-It.ContinuousPlayViewController"
private let kPlayCountThreshold = 3
class ContinuousPlayViewController: UIViewController
{
    var flashCards: [FlashCard]!
    
    @IBOutlet weak var visibleImageView: UIImageView!
    @IBOutlet weak var nextImageView: UIImageView!
    @IBOutlet weak var coverPanel: UIView!
    @IBOutlet weak var dismissButton: UIButton!
    
    fileprivate var currentFlashCardIndex = 0
    fileprivate var audioPlayer: AVAudioPlayer?
    fileprivate var playCount = 0
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        guard flashCards.count > 0 else { return }
        visibleImageView.image = currentImage()
        nextImageView.image = nextImage()
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        startPlayback()
    }
    
    @IBAction func tapRecognised(_ sender: UITapGestureRecognizer)
    {
        UIView.animate(withDuration: 0.3, animations: {
            if self.dismissButton.isHidden {
                self.dismissButton.isHidden = false
                self.dismissButton.alpha = 1.0
            }
            else {
                self.dismissButton.alpha = 0.0
            }
        }, completion: { _ in
            self.dismissButton.isHidden = self.dismissButton.alpha < 0.5
        })
    }
    
    @IBAction func dismissTapped(_ sender: UIButton)
    {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Private Functions
fileprivate extension ContinuousPlayViewController
{
    func startPlayback()
    {
        guard currentFlashCardIndex < flashCards.count else { self.dismiss(animated: true, completion: nil); return }
        setUpAudioPlayerForCurrentFlashCard()
        let time = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + (5 * USEC_PER_SEC) / 2)
        DispatchQueue.main.asyncAfter(deadline: time) { [weak self] in self?.playOnce() }
    }
    
    func setUpAudioPlayerForCurrentFlashCard()
    {
        let flashCard = flashCards[currentFlashCardIndex]
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
    
    func playOnce()
    {
        audioPlayer?.currentTime = 0.0
        audioPlayer?.play()
    }
    
    func pathToAudioFile(_ fileName: String) throws -> URL
    {
        if let directory = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask).first {
            return directory.appendingPathComponent(fileName)
        }
        throw NSError(domain: kContinuousePlayViewControllerErrorDomain,
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey :"Could not get a path to the Documents directory for the current user",
            ])
    }
    
    func moveToNextFlashCard()
    {
        UIView.animate(withDuration: 0.5, animations: {
            self.nextImageView.transform = CGAffineTransform(translationX: -self.nextImageView.frame.width, y: 0)
            self.visibleImageView.transform = CGAffineTransform(translationX: -self.visibleImageView.frame.width, y: 0)
            self.coverPanel.transform = CGAffineTransform(
                translationX: -(self.visibleImageView.frame.width + self.coverPanel.frame.width), y: 0)
        }, completion: { _ in
            self.visibleImageView.image = self.nextImageView.image
            self.nextImageView.image = self.nextImage()
            self.nextImageView.transform = CGAffineTransform.identity
            self.visibleImageView.transform = CGAffineTransform.identity
            self.coverPanel.transform = CGAffineTransform.identity
        })
    }
    
    func currentImage() -> UIImage
    {
        guard flashCards.count > 0 else { return UIImage() }
        if let imageData = flashCards.first?.image as? Data,
            let image = UIImage(data: imageData) {
            return image
        }
        return UIImage()
    }
    
    func nextImage() -> UIImage
    {
        guard flashCards.count > 0 else { return UIImage() }
        let index = (currentFlashCardIndex + 1) < flashCards.count ? currentFlashCardIndex + 1 : 0
        let flashCard = flashCards[index]
        if let imageData = UIImage(data: (flashCard.image! as Data)) {
            return imageData
        }
        return UIImage()
    }
    
    func incrementFlashCardIndex()
    {
        currentFlashCardIndex += 1
        if currentFlashCardIndex == flashCards.count {
            currentFlashCardIndex = 0
        }
    }
    
    func updateFlashCards()
    {
        if playCount == kPlayCountThreshold {
            playCount = 0
            incrementFlashCardIndex()
            setUpAudioPlayerForCurrentFlashCard()
            moveToNextFlashCard()
        }
    }
}

// MARK: - AVAudioPlayerDelegate Implementation
extension ContinuousPlayViewController: AVAudioPlayerDelegate
{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    {
        playCount += 1
        let time = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + (5 * NSEC_PER_SEC) / 2)
        DispatchQueue.main.asyncAfter(deadline: time) { [weak self] in
            self?.updateFlashCards()
            let time = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + (5 * NSEC_PER_SEC) / 2)
            DispatchQueue.main.asyncAfter(deadline: time) { self?.playOnce() }
        }
    }
}
