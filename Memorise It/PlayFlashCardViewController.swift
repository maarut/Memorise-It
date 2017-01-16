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
fileprivate let kCoverPanelWidth: CGFloat = 44.0

enum Position
{
    case next
    case current
    case previous
}

protocol PlayFlashCardViewControllerDelegate: NSObjectProtocol
{
    func didPan(to position: Position)
    func dismissContentTo(in view: UIView) -> CGRect
    func zoomContentFrom(in view: UIView) -> CGRect
    func willZoomContent()
    func didDismissContent()
    func flashCard(for position: Position) -> FlashCard
}

class PlayFlashCardViewController: UIViewController
{
    weak var delegate: PlayFlashCardViewControllerDelegate?
    
    @IBOutlet weak var informationOverlayContainer: UIView!
    @IBOutlet weak var informationOverlayText: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet var tapGestureRecogniser: UITapGestureRecognizer!
    @IBOutlet var panGestureRecogniser: UIPanGestureRecognizer!
    
    fileprivate var audioPlayer: AVAudioPlayer?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        informationOverlayContainer.layer.cornerRadius = 10
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        guard let flashCard = delegate?.flashCard(for: .current), let imageData = flashCard.image as Data? else {
            return
        }
        let iv = UIImageView(image: UIImage(data: imageData))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.frame = delegate?.zoomContentFrom(in: view) ?? CGRect.zero
        view.addSubview(iv)
        imageView = iv
        delegate?.willZoomContent()
        UIView.animate(withDuration: 0.3) {
            self.view.backgroundColor = UIColor(white: 0.0, alpha: 0.999)
            self.imageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
            self.imageView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
            self.imageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
            self.imageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
            self.view.layoutIfNeeded()
        }
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
        do {
            if let audioURLString = delegate?.flashCard(for: .current).audioFileName {
                let audioURL = try pathToAudioFile(audioURLString)
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.delegate = self
            }
        }
        catch let error as NSError {
            NSLog("\(error.description)\n\(error.localizedDescription)")
        }
        sender.removeTarget(self, action: #selector(tapRecognised(_:)))
        sender.addTarget(self, action: #selector(stopPlayback(_:)))
        audioPlayer?.currentTime = 0.0
        audioPlayer?.play()
    }
    
    @IBAction func panRecognised(_ sender: UIPanGestureRecognizer)
    {
        guard let direction = determinePanDirection(sender.translation(in: self.view)) else { return }
        let selector: Selector
        switch direction {
        case UISwipeGestureRecognizerDirection.up,
             UISwipeGestureRecognizerDirection.down:    selector = #selector(panToDismiss(using:))
        case UISwipeGestureRecognizerDirection.left,
             UISwipeGestureRecognizerDirection.right:   selector = #selector(panToNextImage(using:))
        default:                                        return
        }
        perform(selector, with: sender)
        sender.removeTarget(self, action: nil)
        sender.addTarget(self, action: selector)
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
        guard let tapGestureRecogniser = tapGestureRecogniser else { return }
        stopPlayback(tapGestureRecogniser)
    }
}

// MARK: - Private Functions
fileprivate extension PlayFlashCardViewController
{
    dynamic func panToNextImage(using sender: UIPanGestureRecognizer)
    {
        guard let previousFlashCard = delegate?.flashCard(for: .previous),
            let nextFlashCard = delegate?.flashCard(for: .next) else {
            return
        }
        let translation = sender.translation(in: view)
        let animationDuration = animationDurationForPan(in: sender.state)
        switch sender.state {
        case .began, .changed:
            let imageViews = setUpAdjacentImageViews(previousImageData: previousFlashCard.image! as Data,
                nextImageData: nextFlashCard.image! as Data)
            let coverViews = view.subviews.filter { $0.frame.width.isRoughlyEqualTo(kCoverPanelWidth) }
            let coverViewOffset = kCoverPanelWidth * (translation.x / view.frame.width)
            UIView.animate(withDuration: animationDuration) {
                for view in imageViews { view.transform = CGAffineTransform(translationX: translation.x, y: 0) }
                for view in coverViews {
                    view.transform = CGAffineTransform(translationX: translation.x + coverViewOffset, y: 0)
                }
            }
        case .ended:
            let width = view.frame.width
            let newOriginMagnitude = (width / 2) < abs(translation.x) ? (width) : 0
            let newOriginVector = translation.x > 0 ? newOriginMagnitude : -newOriginMagnitude
            let imageViews = view.subviews.filter { $0 is UIImageView }
            let coverViews = view.subviews.filter { $0.frame.width.isRoughlyEqualTo(kCoverPanelWidth) }
            let panPosition = newPosition(newOriginVector)
            let translationX = finalCoverPanelTranslation(panPosition, vector: newOriginVector)
            
            UIView.animate(withDuration: animationDuration, animations: {
                for view in imageViews {
                    view.transform = CGAffineTransform(translationX: newOriginVector, y: 0)
                }
                for view in coverViews { view.transform = CGAffineTransform(translationX: translationX, y: 0) }
            }, completion: { _ in
                if let image = self.delegate?.flashCard(for: .current).image as? Data {
                    self.imageView.image = UIImage(data: image)
                }
                for view in imageViews {
                    view.transform = CGAffineTransform.identity
                    if self.shouldRemove(view: view) { view.removeFromSuperview() }
                }
                for view in coverViews { view.removeFromSuperview() }
            })
            revertTargetAction(for: sender)
            delegate?.didPan(to: panPosition)
            break
        default:
            return
        }
    }
    
    dynamic func panToDismiss(using sender: UIPanGestureRecognizer)
    {
        let translation = sender.translation(in: self.view)
        let magnitude = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
        switch sender.state {
        case .changed:
            let center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            let ratio = imageViewShrinkRatio(motionMagnitude: magnitude)
            imageView.center = center
            imageView.frame.size = CGSize(width: view.frame.width * ratio, height: view.frame.height * ratio)
            view.backgroundColor = UIColor(white: 0, alpha: alphaRatio(motionMagnitude: magnitude))
            break
        case .ended:
            if shouldDismiss(given: magnitude) {
                dismiss(to: delegate?.dismissContentTo(in: self.view) ?? CGRect.zero)
            }
            else {
                UIView.animate(withDuration: 0.3) {
                    self.view.backgroundColor = UIColor.black
                    self.imageView.frame = self.view.frame
                }
            }
            revertTargetAction(for: sender)
            break
        default:
            return
        }
    }
    
    func dismiss(to rect: CGRect)
    {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.backgroundColor = UIColor.clear
            self.imageView.frame = rect
        }, completion: { _ in
            self.delegate?.didDismissContent()
        })
    }
    
    func revertTargetAction(for gesture: UIPanGestureRecognizer)
    {
        gesture.removeTarget(self, action: nil)
        gesture.addTarget(self, action: #selector(panRecognised(_:)))
    }
    
    func determinePanDirection(_ point: CGPoint) -> UISwipeGestureRecognizerDirection?
    {
        switch (point.x, point.y) {
        case let (x, y) where x < y && y <= 0:  return UISwipeGestureRecognizerDirection.left
        case let (x, y) where x > y && y >= 0:  return UISwipeGestureRecognizerDirection.right
        case let (x, y) where y < x && x <= 0:  return UISwipeGestureRecognizerDirection.up
        case let (x, y) where y > x && x >= 0:  return UISwipeGestureRecognizerDirection.down
        default:                                return nil
        }
    }
    
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
    
    func newPosition(_ vector: CGFloat) -> Position
    {
        switch vector {
        case let x where x < 0: return .next
        case let x where x > 0: return .previous
        default:                return .current
        }
    }
    
    func finalCoverPanelTranslation(_ position: Position, vector: CGFloat) -> CGFloat
    {
        switch position {
        case .previous: return vector + kCoverPanelWidth
        case .next:     return vector - kCoverPanelWidth
        case .current:  return 0
        }
    }
    
    func setUpAdjacentImageViews(previousImageData: Data, nextImageData: Data) -> [UIImageView]
    {
        let imageViews = view.subviews.flatMap { $0 as? UIImageView }
        guard imageViews.count == 1 else { return imageViews }
        let prevImage = UIImageView(frame: view.frame)
        prevImage.frame.origin.x -= (prevImage.frame.width)
        prevImage.contentMode = .scaleAspectFit
        prevImage.image = UIImage(data: previousImageData)
        let nextImage = UIImageView(frame: view.frame)
        nextImage.frame.origin.x += (nextImage.frame.width)
        nextImage.contentMode = .scaleAspectFit
        nextImage.image = UIImage(data: nextImageData as Data)
        let nextCoverView = UIView(frame: CGRect(origin: CGPoint(x: nextImage.frame.width, y: 0),
            size: CGSize(width: kCoverPanelWidth, height: view.frame.height)))
        nextCoverView.backgroundColor = view.backgroundColor
        let prevCoverView = UIView(frame: CGRect(origin: CGPoint(x: -kCoverPanelWidth, y: 0),
            size: CGSize(width: kCoverPanelWidth, height: view.frame.height)))
        prevCoverView.backgroundColor = view.backgroundColor
        view.addSubview(prevImage)
        view.addSubview(nextImage)
        view.addSubview(nextCoverView)
        view.addSubview(prevCoverView)
        view.bringSubview(toFront: informationOverlayContainer)
        view.bringSubview(toFront: informationOverlayText)
        return imageViews + [prevImage, nextImage]
    }
    
    func imageViewShrinkRatio(motionMagnitude: CGFloat) -> CGFloat
    {
        return max(1.0 - (motionMagnitude / 400), 0.6)
    }
    
    func alphaRatio(motionMagnitude:CGFloat) -> CGFloat
    {
        return 1.0 - (motionMagnitude / 200.0)
    }
    
    func shouldDismiss(given magnitude: CGFloat) -> Bool
    {
        return magnitude > 25
    }
    
    func shouldRemove(view: UIView) -> Bool
    {
        return !self.view.point(inside: view.convert(view.center, to: self.view), with: nil)
    }
    
    func animationDurationForPan(in state: UIGestureRecognizerState) -> TimeInterval
    {
        switch state {
        case .began, .ended:    return 0.3
        default:                return 0.01
        }
    }
}

fileprivate extension CGFloat
{
    func isRoughlyEqualTo(_ rhs: CGFloat) -> Bool
    {
        return self > (rhs * 0.99) && self < (rhs * 1.01)
    }
}
