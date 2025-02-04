//
//  ViewController.swift
//  fruits-classification
//
//  Created by Anup Saud on 2024-10-25.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            // Create model configuration for CPU only
            let config = MLModelConfiguration()
            #if targetEnvironment(simulator)
                config.computeUnits = .cpuOnly
            #endif
            
            // Initialize the model with configuration
            let model = try VNCoreMLModel(for: ImageClassificationModel(configuration: config).model)
            
            let request = VNCoreMLRequest(model: model) { request, error in
                self.processClassifications(for: request, error: error)
            }
            request.imageCropAndScaleOption = .centerCrop
            
            return request
        } catch {
            fatalError("Failed to load Core ML Model: \(error)")
        }
    }()
    
    func processClassifications(for request: VNRequest, error: Error?) {
        guard let classifications = request.results as? [VNClassificationObservation] else {
            self.classificationLabel.text = "Unable to classify image.\n\(error?.localizedDescription ?? "Error")"
            return
        }
        
        if classifications.isEmpty {
            self.classificationLabel.text = "Nothing recognized.\nPlease try again."
        } else {
            let topClassifications = classifications.prefix(4)
            let descriptions = topClassifications.map { classification in
                return String(format: "%.2f", classification.confidence * 100) + "% - " + classification.identifier
            }
            self.classificationLabel.text = "Classification:\n" + descriptions.joined(separator: "\n")
        }
    }
    
    func updateClassifications(for image: UIImage) {
        classificationLabel.text = "Classifying..."
        
        guard let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)),
              let ciImage = CIImage(image: image) else {
            print("Something went wrong...\nPlease try again")
            return
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
        do {
            try handler.perform([classificationRequest])
        } catch {
            print("Failed to perform classification: \(error.localizedDescription)")
            classificationLabel.text = "Classification failed.\nPlease try again."
        }
    }
    
    @IBAction func cameraButtonPressed(_ sender: Any) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(sourceType: .photoLibrary)
            return
        }
        
        let photoSourcePicker = UIAlertController()
        let takePhotoAction = UIAlertAction(title: "Take Photo", style: .default) { _ in
            self.presentPhotoPicker(sourceType: .camera)
        }
        let choosePhotoAction = UIAlertAction(title: "Choose Photo", style: .default) { _ in
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        
        photoSourcePicker.addAction(takePhotoAction)
        photoSourcePicker.addAction(choosePhotoAction)
        photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(photoSourcePicker, animated: true)
    }
    
    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
        imageView.image = image
        updateClassifications(for: image)
    }
}
