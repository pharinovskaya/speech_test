//
//  ViewController.swift
//  speech_test
//
//  Created by user on 17.06.2020.
//  Copyright © 2020 user. All rights reserved.
//

import UIKit
import Speech
import AVKit

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var detectedTextLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var micImage: UIImageView!
    @IBOutlet weak var answerView: UIView!
    @IBOutlet weak var answerLabel: UILabel!
    
    private var bestString: String?
    private let controller = AVPlayerViewController()
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    // let speechRecognizer: SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    private let request = SFSpeechAudioBufferRecognitionRequest()
    // If the audio was pre-recorded and stored in memory - SFSpeechURLRecognitionRequest instead
    private var recognitionTask: SFSpeechRecognitionTask?  // to manage, cancel, or stop the current recognition task
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        detectedTextLabel.text = ""
        answerView.isHidden = true
        requestSpeechAuthorization()
    }
    
    @IBAction func buttonIsPressing(_ sender: UIButton) {
        recordAndRecognizeSpeech()
        answerView.isHidden = true
        micImage.image = UIImage(named: "micro")
    }
    
    @IBAction func strartButtonPressed(_ sender: UIButton) {
        detectedTextLabel.text = ""
        micImage.image = nil
        stopSpeechRecognition()
    }
    
    @IBAction func play(_ sender: UIButton) {
        guard let path = Bundle.main.path(forResource: "cat", ofType: "mp4") else {
            return
        }
        let videoURL = NSURL(fileURLWithPath: path)

        let player = AVPlayer(url: videoURL as URL)
        controller.player = player
        present(controller, animated: true) {
            player.play()
        }
        
        controller.removeFromParent()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fileComplete),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    @objc func fileComplete() {
        self.controller.dismiss(animated: true, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func stopSpeechRecognition() {
        if self.bestString == "Pink" {
            self.answerView.isHidden = false
            self.answerView.backgroundColor = UIColor.green
            self.answerLabel.text = "Correct!"
        } else {
            self.answerView.backgroundColor = UIColor.red
            self.answerLabel.text = "Oops! You're wrong :("
            self.answerView.isHidden = false
        }
        
    
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        
        
        self.request.endAudio()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        
    }
    
    private func recordAndRecognizeSpeech() {
        let node = audioEngine.inputNode
        let outputBus = 0
        let recordingFormat = node.outputFormat(forBus: outputBus)
        
        node.installTap(onBus: outputBus, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.request.append(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch  {
            return print(error)
        }
        
        guard let myRecognizer = speechRecognizer else {
            // recognizer is not support for current locale
            return
        }
        
        if !myRecognizer.isAvailable {
            // recognizer is not available now
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { (result, error) in
            if let result = result {
                print(result.bestTranscription.segments.last?.substring)
                
                self.bestString = result.bestTranscription.formattedString
                self.detectedTextLabel.text = self.bestString
                
            } else if let error = error {
                print(error)
            }
        })
    }


    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.startButton.isEnabled = true
                case .denied:
                    self.startButton.isEnabled = false
                    self.startButton.setTitle("User denied access to speech recognition", for: .disabled)

                case .restricted:
                    self.startButton.isEnabled = false
                    self.startButton.setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    self.startButton.isEnabled = false
                    self.startButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
}

