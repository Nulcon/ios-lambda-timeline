//
//  ImagePostViewController.swift
//  LambdaTimeline
//
//  Created by Spencer Curtis on 10/12/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import UIKit
import Photos

class ImagePostViewController: ShiftableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setImageViewHeight(with: 1.0)
        updateViews()
    }
    
    func updateViews() {
        guard let imageData = imageData,
            let image = UIImage(data: imageData) else {
                title = "New Post"
                return
        }
        
        title = post?.title
        setImageViewHeight(with: image.ratio)
        imageView.image = image
        chooseImageButton.setTitle("", for: [])
    }
    
    private func presentImagePickerController() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            presentInformationalAlertController(title: "Error", message: "The photo library is unavailable")
            return
        }
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func createPost(_ sender: Any) {
        
        view.endEditing(true)
        
        guard let originalImage = originalImage,
            let image = self.image(byFiltering: originalImage) else {
                return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.1),
            let title = titleTextField.text, title != "" else {
                presentInformationalAlertController(title: "Uh-oh", message: "Make sure that you add a photo and a caption before posting.")
                return
        }
        
        postController.createPost(with: title, ofType: .image, mediaData: imageData, ratio: imageView.image?.ratio) { (success) in
            guard success else {
                DispatchQueue.main.async {
                    self.presentInformationalAlertController(title: "Error", message: "Unable to create post. Try again.")
                }
                return
            }
            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    @IBAction func chooseImage(_ sender: Any) {
        
        let authorizationStatus = PHPhotoLibrary.authorizationStatus()
        
        switch authorizationStatus {
        case .authorized:
            presentImagePickerController()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { (status) in
                guard status == .authorized else {
                    NSLog("User did not authorize access to the photo library")
                    self.presentInformationalAlertController(title: "Error", message: "In order to access the photo library, you must allow this application access to it.")
                    return
                }
                
                self.presentImagePickerController()
            }
            
        case .denied:
            self.presentInformationalAlertController(title: "Error", message: "In order to access the photo library, you must allow this application access to it.")
        case .restricted:
            self.presentInformationalAlertController(title: "Error", message: "Unable to access the photo library. Your device's restrictions do not allow access.")
            
        }
        presentImagePickerController()
    }
    
    func setImageViewHeight(with aspectRatio: CGFloat) {
        imageHeightConstraint.constant = imageView.frame.size.width * aspectRatio
        view.layoutSubviews()
    }
    
    @IBAction func changeBrightness(_ sender: UISlider) {
        updateImage()
    }
    
    @IBAction func changeGamma(_ sender: UISlider) {
        updateImage()
    }
    
    @IBAction func reduceNoise(_ sender: UISwitch) {
        updateImage()
    }
    
    @IBAction func hueSlider(_ sender: UISlider) {
        updateImage()
    }
    
    @IBAction func blurSlider(_ sender: UISlider) {
        updateImage()
    }
    
    // MARK: - Private Functions
    private func updateImage() {
        guard let originalImage = originalImage else { return }
        imageView?.image = image(byFiltering: originalImage)
    }
    
    private func image(byFiltering image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        
        ciColorFilter.setValue(ciImage, forKey: kCIInputImageKey)
        ciColorFilter.setValue(brightnessSlider.value, forKey: kCIInputBrightnessKey)
        
        hueFilter.setValue(ciColorFilter.outputImage, forKey: kCIInputImageKey)
        hueFilter.setValue(hueSlider.value, forKey: kCIInputAngleKey)
        
        blurFilter.setValue(hueFilter.outputImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurSlider.value, forKey: kCIInputRadiusKey)
        
        gammaFilter.setValue(blurFilter.outputImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(gammaSlider.value, forKey: "inputPower")
        
        if (noiseReductionToggle.isOn) {
            noiseReducingFilter.setValue(gammaFilter.outputImage, forKey: kCIInputImageKey)
            guard let outputCIImage = noiseReducingFilter.outputImage,
                let outputCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
                    return nil
            }
            return UIImage(cgImage: outputCGImage)
        }
        
        guard let outputCIImage = gammaFilter.outputImage,
            let outputCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
                return nil
        }
        return UIImage(cgImage: outputCGImage)
    }
    
    // MARK: - Properties
    var postController: PostController!
    var post: Post?
    var imageData: Data?
    var originalImage: UIImage? {
        didSet {
            updateImage()
        }
    }
    // MARK: - Filters
    private let ciColorFilter = CIFilter(name: "CIColorControls")!
    private let gammaFilter = CIFilter(name: "CIGammaAdjust")!
    private let noiseReducingFilter = CIFilter(name: "CIMedianFilter")!
    private let hueFilter = CIFilter(name: "CIHueAdjust")!
    private let blurFilter = CIFilter(name: "CIGaussianBlur")!
    private let context = CIContext(options: nil)
    
    @IBOutlet var noiseReductionToggle: UISwitch!
    @IBOutlet var gammaSlider: UISlider!
    @IBOutlet var brightnessSlider: UISlider!
    @IBOutlet var hueSlider: UISlider!
    @IBOutlet var blurSlider: UISlider!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var chooseImageButton: UIButton!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var postButton: UIBarButtonItem!
}

extension ImagePostViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        chooseImageButton.setTitle("", for: [])
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
        
        originalImage = image
        gammaSlider.isEnabled = true
        brightnessSlider.isEnabled = true
        hueSlider.isEnabled = true
        blurSlider.isEnabled = true
        noiseReductionToggle.isEnabled = true
        
        setImageViewHeight(with: image.ratio)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
