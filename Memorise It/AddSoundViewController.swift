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

class AddSoundViewController: UIViewController
{
    var image: UIImage!
    
    fileprivate var audioRecorder: AVAudioRecorder!
    fileprivate var audioPlayer: AVAudioPlayer!
    fileprivate var recordedAudioPath: URL?
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        navigationItem.hidesBackButton = true
        navigationItem.setLeftBarButton(
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelected(_:))),
            animated: false)
        navigationItem.setRightBarButton(
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneSelected(_:))),
            animated: false)
        imageView.image = image
        
    }
    
    @IBAction func record(_ button: UIButton)
    {
        removePreviousRecording()
        do {
            audioRecorder = try AVAudioRecorder(url: filePath(), settings: [
                AVFormatIDKey               : kAudioFormatMPEG4AAC          as AnyObject,
                AVNumberOfChannelsKey       : 1                             as AnyObject,
                AVSampleRateKey             : 44100.0                       as AnyObject,
                AVEncoderAudioQualityKey    : AVAudioQuality.min.rawValue   as AnyObject,
                AVEncoderBitRateKey         : 65536.0                       as AnyObject
                ])
            audioRecorder.delegate = self
            audioRecorder.isMeteringEnabled = true
            audioRecorder.record()
            recordButton.removeTarget(self, action: #selector(record(_:)), for: .touchUpInside)
            recordButton.addTarget(self, action: #selector(stopRecording(_:)), for: .touchUpInside)
            recordButton.setTitle("Stop", for: .normal)
            playButton.isEnabled = false
        }
        catch let error as NSError {
            NSLog("\(error.description)\n\(error.localizedDescription)")
        }
    }
    
    @IBAction func playAudio(_ sender: UIButton)
    {
        if let recordedAudioPath = recordedAudioPath {
            audioPlayer = try! AVAudioPlayer(contentsOf: recordedAudioPath)
            audioPlayer.play()
            playButton.removeTarget(self, action: #selector(playAudio(_:)), for: .touchUpInside)
            playButton.addTarget(self, action: #selector(stopPlayback(_:)), for: .touchUpInside)
            playButton.setTitle("Stop", for: .normal)
        }
    }
    
    func stopRecording(_ sender: UIButton)
    {
        audioRecorder.stop()
        recordButton.removeTarget(self, action: #selector(stopRecording(_:)), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(record(_:)), for: .touchUpInside)
        recordButton.setTitle("Record", for: .normal)
        playButton.isEnabled = true
    }
    
    func stopPlayback(_ sender: UIButton)
    {
        audioPlayer.stop()
        playButton.removeTarget(self, action: #selector(stopPlayback(_:)), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playAudio(_:)), for: .touchUpInside)
        playButton.setTitle("Play", for: .normal)
    }
    
    func cancelSelected(_ barButton: UIBarButtonItem)
    {
        removePreviousRecording()
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func doneSelected(_ barButton: UIBarButtonItem)
    {
        // save the image and sound to the storage medium.
        navigationController?.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Private Functions
fileprivate extension AddSoundViewController
{
    func filePath() throws -> URL
    {
        if let directory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMddHHmmss"
            let fileName = dateFormatter.string(from: Date()) + ".m4a"
            return URL(fileURLWithPath: directory).appendingPathComponent(fileName)
        }
        throw NSError(domain: kAddSoundViewControllerErrorDomain,
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey :"Could not get a path to the Documents directory for the current user",
            ])
    }
    
    func removePreviousRecording()
    {
        if let recordedAudioPath = recordedAudioPath {
            if FileManager.default.fileExists(atPath: recordedAudioPath.absoluteString) {
                do {
                    try FileManager.default.removeItem(at: recordedAudioPath)
                    self.recordedAudioPath = nil
                }
                catch let error as NSError {
                    NSLog("Unable to delete previous recording.")
                    NSLog("\(error.localizedDescription)\n\(error.description)")
                }
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate Implementation
extension AddSoundViewController: AVAudioRecorderDelegate
{
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool)
    {
        recordedAudioPath = recorder.url
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?)
    {
        if let e = error as? NSError {
            NSLog(e.description)
            NSLog(e.localizedDescription)
        }
        else { NSLog("ERROR!") }
    }
}
