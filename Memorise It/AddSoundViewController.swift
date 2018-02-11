//
//  AddSoundViewController.swift
//  Memorise It
//
//  Created by Maarut Chandegra on 06/12/2016.
//  Copyright © 2016 Maarut Chandegra. All rights reserved.
//

import UIKit
import AVFoundation
import CoreAudio

fileprivate let kAddSoundViewControllerErrorDomain = "net.maarut.Memorise-It.AddSoundViewController"
fileprivate let kRecordColour = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
fileprivate let kPlayColour = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)

class AddSoundViewController: UIViewController
{
    var image: UIImage!
    var dataController: DataController!
    
    fileprivate var audioRecorder: AVAudioRecorder!
    fileprivate var audioPlayer: AVAudioPlayer!
    fileprivate var recordedAudioFileName: String?
    fileprivate var documentsDirectory: URL?
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var circleView: UIView!
    fileprivate weak var circleShape: CAShapeLayer!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        imageView.image = image
        setupCircleView()
        setupNavBar()
        setupAudioRecorder()
    }
    
    @IBAction func record(_ button: UIButton)
    {
        removePreviousRecording()
        audioRecorder.record()
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 5.0
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.delegate = self
        circleShape.strokeEnd = 1.0
        circleShape.add(animation, forKey: "strokeEnd")
    }
    
    @IBAction func stopRecording(_ sender: UIButton)
    {
        stopRecording()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        circleShape.strokeEnd = 0.0
        CATransaction.commit()
        recordButton.setTitle("▶", for: .normal)
        recordButton.setTitleColor(kPlayColour, for: .normal)
        recordButton.removeTarget(self, action: #selector(stopRecording(_:)), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(stopPlayback(_:)), for: .touchUpInside)
        recordButton.removeTarget(self, action: #selector(record(_:)), for: .touchDown)
        recordButton.addTarget(self, action: #selector(playAudio(_:)), for: .touchDown)
        circleShape.strokeColor = kPlayColour.cgColor
    }
    
    @IBAction func cancelRecording(_ sender: UIButton)
    {
        audioRecorder.stop()
        removePreviousRecording()
    }
    
    @IBAction func clearAudio(_ button: UIButton)
    {
        removePreviousRecording()
        recordButton.setTitle("●", for: .normal)
        recordButton.setTitleColor(kRecordColour, for: .normal)
        recordButton.removeTarget(self, action: #selector(stopPlayback(_:)), for: .touchUpInside)
        recordButton.removeTarget(self, action: #selector(playAudio(_:)), for: .touchDown)
        recordButton.addTarget(self, action: #selector(stopRecording(_:)), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(record(_:)), for: .touchDown)
        circleShape.strokeColor = kRecordColour.cgColor
    }
}

// MARK: - Dynamic Functions
fileprivate extension AddSoundViewController
{
    @objc func playAudio(_ sender: UIButton)
    {
        guard let recordedAudioFileName = recordedAudioFileName, let documentsDirectory = documentsDirectory else {
            return
        }
        audioPlayer = try! AVAudioPlayer(
            contentsOf: documentsDirectory.appendingPathComponent(recordedAudioFileName))
        audioPlayer.delegate = self
        audioPlayer.play()
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = audioPlayer.duration + 0.01
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.delegate = self
        circleShape.strokeEnd = 1.0
        circleShape.add(animation, forKey: "strokeEnd")
        
    }
    
    @objc func stopPlayback(_ sender: UIButton)
    {
        stopPlayback()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        circleShape.strokeEnd = 0.0
        CATransaction.commit()
    }
    
    @objc func cancelSelected(_ barButton: UIBarButtonItem)
    {
        removePreviousRecording()
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc func doneSelected(_ barButton: UIBarButtonItem)
    {
        // save the image and sound to the storage medium.
        if let imageData = UIImagePNGRepresentation(image),
            let recordedAudioFileName = recordedAudioFileName {
            dataController.addFlashCard(image: imageData, audioFileName: recordedAudioFileName, dateAdded: Date())
            navigationController?.dismiss(animated: true, completion: nil)
        }
        else {
            let alertController = UIAlertController(title: "No Audio Recorded",
                message: "No audio was recorded. Would you like to cancel and go back to the main screen or record some audio and save the flash card?",
                preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Main Screen", style: .default, handler: { _ in
                self.navigationController?.dismiss(animated: true, completion: nil)
            }))
            alertController.addAction(UIAlertAction(title: "Record Audio", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            
        }
        
    }
}

// MARK: - Private Functions
fileprivate extension AddSoundViewController
{
    func setupNavBar()
    {
        navigationItem.hidesBackButton = true
        navigationItem.setLeftBarButton(
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelected(_:))),
            animated: false)
        navigationItem.setRightBarButton(
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneSelected(_:))),
            animated: false)
    }
    
    func setupAudioRecorder()
    {
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        do {
            audioRecorder = try AVAudioRecorder(url: filePath().appendingPathComponent(fileName()), settings: [
                AVFormatIDKey               : kAudioFormatMPEG4AAC          as AnyObject,
                AVNumberOfChannelsKey       : 1                             as AnyObject,
                AVSampleRateKey             : 44100.0                       as AnyObject,
                AVEncoderAudioQualityKey    : AVAudioQuality.min.rawValue   as AnyObject,
                AVEncoderBitRateKey         : 65536.0                       as AnyObject
                ])
            audioRecorder.delegate = self
            audioRecorder.isMeteringEnabled = true
        }
        catch let error as NSError {
            NSLog("\(error.description)\n\(error.localizedDescription)")
        }
    }
    
    func setupCircleView()
    {
        let circleShape = CAShapeLayer()
        let point = CGPoint(x: circleView.frame.width / 2.0, y: circleView.frame.height / 2.0)
        circleShape.path = UIBezierPath(arcCenter: point,
            radius: circleView.frame.width / 2.0 - 5.0,
            startAngle: CGFloat(0.0 - .pi / 2),
            endAngle: CGFloat(2.0 * .pi - .pi / 2),
            clockwise: true).cgPath
        circleShape.lineWidth = 5.0
        circleShape.fillColor = UIColor.clear.cgColor
        circleShape.strokeColor = kRecordColour.cgColor
        circleShape.strokeEnd = 0.0
        circleView.layer.addSublayer(circleShape)
        self.circleShape = circleShape
    }
    
    func fileName() -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYYMMddHHmmss"
        let fileName = dateFormatter.string(from: Date()) + ".m4a"
        return fileName
    }
    
    func filePath() throws -> URL
    {
        if let directory = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask).first {
            documentsDirectory = directory
            return directory
        }
        throw NSError(domain: kAddSoundViewControllerErrorDomain,
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey :"Could not get a path to the Documents directory for the current user",
            ])
    }
    
    func removePreviousRecording()
    {
        guard recordedAudioFileName != nil else { return }
        if audioRecorder.deleteRecording() { recordedAudioFileName = nil }
        else { NSLog("Unable to delete previous recording.") }
    }
    
    func stopRecording()
    {
        audioRecorder.stop()
        circleShape.removeAllAnimations()
    }
    
    func stopPlayback()
    {
        audioPlayer.stop()
        audioPlayer.currentTime = 0.0
        circleShape.removeAllAnimations()
        
    }
}

// MARK: - AVAudioPlayerDelegate Implementation
extension AddSoundViewController: AVAudioPlayerDelegate
{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    {
        stopPlayback()
        if !flag { NSLog("Did not successfully play back audio.") }
    }
}

// MARK: - AVAudioRecorderDelegate Implementation
extension AddSoundViewController: AVAudioRecorderDelegate
{
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool)
    {
        assert(recorder.url.deletingLastPathComponent() == documentsDirectory)
        recordedAudioFileName = recorder.url.lastPathComponent
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?)
    {
        if let e = error as NSError? {
            NSLog(e.description)
            NSLog(e.localizedDescription)
        }
        else { NSLog("ERROR!") }
    }
}

extension AddSoundViewController: CAAnimationDelegate
{
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool)
    {
        if flag {
            if audioRecorder.isRecording { stopRecording() }
            else { stopPlayback() }
        }
        
    }
}
