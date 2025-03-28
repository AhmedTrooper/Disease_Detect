import 'dart:typed_data';

import 'package:disease_detect/constants/disease_description.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DiseaseDetector extends StatefulWidget {
  const DiseaseDetector({super.key});
  @override
  State<StatefulWidget> createState() {
    return _DiseaseDetectorState();
  }
}

class _DiseaseDetectorState extends State<DiseaseDetector> {
  final imagePicker = ImagePicker();
  var logger = Logger(printer: PrettyPrinter());
  ImageSource galleryAsSource = ImageSource.gallery;
  ImageSource cameraAsSource = ImageSource.camera;
  String? diseaseName;
  Uint8List imageBytes = Uint8List(0);
  bool isInitialStage = true;

  Future<void> detectImage(ImageSource sourceOfImage) async {
    setState(() {
      imageBytes = Uint8List(0);
      isInitialStage = false;
      diseaseName = null;
    });
    XFile? image = await imagePicker.pickImage(source: sourceOfImage);
    final interpreter = await Interpreter.fromAsset("assets/model.tflite");
    final inputShape = interpreter.getInputTensor(0).shape;
    // logger.d('Input shape: $inputShape');
    final outputShape = interpreter.getOutputTensor(0).shape;
    // logger.d('Output shape: $outputShape');
    // logger.d(interpreter.getInputTensors());
    // logger.d(interpreter.getOutputTensors());
    if (image != null) {
      final bytes = await image.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        // logger.e("Image decoding failed");
        return;
      }

      // Resize image resolution equal to 640x640
      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: 640,
        height: 640,
        interpolation: img.Interpolation.cubic,
      );

      setState(() {
        imageBytes = Uint8List.fromList(img.encodePng(resizedImage));
      });
      // Convert image to Float32List (1, 640, 640, 3), the model's accepted shape....
      final inputTensor = List.generate(
        1,
        (_) => List.generate(
          640,
          (_) => List.generate(640, (_) => List.filled(3, 0.0)),
        ),
      );
      int index = 0;

      for (int y = 0; y < 640; y++) {
        for (int x = 0; x < 640; x++) {
          final pixel = resizedImage.getPixel(x, y);
          num red = pixel.r;
          num green = pixel.g;
          num blue = pixel.b;
          inputTensor[0][y][x][0] = red / 255.0;
          inputTensor[0][y][x][1] = green / 255.0;
          inputTensor[0][y][x][2] = blue / 255.0;
        }
      }

      // Buffer that matches the model's output shape
      List<List<List<double>>> outputBuffer = List.generate(
        1,
        (batch) => List.generate(12, (channel) => List.filled(8400, 0.0)),
      );

      interpreter.run(inputTensor, outputBuffer);
      //Output buffer shape identification
      // logger.f("Model output: ${outputBuffer.length}");
      // logger.f("Model output: ${outputBuffer[0].length}");
      // logger.f("Model output: ${outputBuffer[0][1].length}");
      // logger.f("Model output: ${outputBuffer[0][outputBuffer[0].length-1].length}");
      List<double> flattenedBuffer =
          outputBuffer
              .expand((batch) => batch.expand((channel) => channel))
              .toList();
      double maxValue = flattenedBuffer.reduce((a, b) => a > b ? a : b);
      int maxIndex = flattenedBuffer.indexOf(maxValue);
      List<String> classNames = [
        'anthracnose',
        'red_spot',
        'bird_eye_spot',
        'algal_spot',
        'brown_blight',
        'gray_blight',
        'healthy',
        'white_spot',
      ];
      int classIndex = maxIndex % classNames.length;
      String predictedClass = classNames[classIndex];
      setState(() {
        diseaseName = predictedClass;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: SizedBox(height: 0,),
          backgroundColor: Colors.blueAccent,
          toolbarHeight: 0,
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                toolbarHeight: 80,
                backgroundColor: Colors.blueAccent,
                title: Text(
                  "Detect Disease",
                  style: TextStyle(
                    fontFamily: GoogleFonts.poppins().fontFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                    color: Colors.white,
                  ),
                ),
                scrolledUnderElevation: 0.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  side: BorderSide(
                    width: 0,
                    color: Colors.white,
                    style: BorderStyle.solid,
                  ),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.all(5),
                    child: IconButton(
                      onPressed: () {
                        context.push("/settings");
                      },
                      icon: Icon(Icons.settings, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: SizedBox(height: 50)),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    imageBytes.isNotEmpty
                        ? Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Image.memory(
                            imageBytes,
                            width: 250,
                            height: 250,
                          ),
                        )
                        : Center(
                          child:
                              !isInitialStage
                                  ? CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                  )
                                  : Text(
                                    "Select or Capture an image!",
                                    style: TextStyle(
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color:Colors.blueAccent
                                    ),
                                  ),
                        ),
                    Center(
                      child: Text(
                        diseaseName != null
                            ? diseaseName.toString().toUpperCase()
                            : isInitialStage
                            ? "No image is provided!"
                            : "Loading....",
                        style: TextStyle(
                          fontFamily: GoogleFonts.poppins().fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: diseaseName != null ? 30 : 20,
                          color: diseaseName != null ? Colors.black : Colors.blueAccent,
                        ),
                      ),
                    ),
                    diseaseName == null
                        ? const SizedBox(height: 0)
                        : Builder(
                      builder: (context) {
                        final disease = diseaseDescription.firstWhere(
                              (d) => d["disease_name"] == diseaseName,
                          orElse: () => {},
                        );

                        if (disease.isEmpty) return const SizedBox(height: 0);

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                diseaseName!.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "About:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                disease["disease_description"] ?? "No description available",
                                style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Symptoms:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                disease["disease_symptoms"] ?? "No symptoms available",
                                style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Management:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              if (disease["management"] != null && (disease["management"] as List).isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: (disease["management"] as List)
                                      .map((m) => Text(
                                    "• $m",
                                    style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
                                  ))
                                      .toList(),
                                )
                              else
                                Text(
                                  "Management details will be added soon",
                                  style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.all(15),
          margin: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              width: 0.5,
              color: Colors.indigo,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () async => detectImage(galleryAsSource),
                icon: Icon(Icons.cloud_upload, color: Colors.white, size: 35),
              ),
              IconButton(
                onPressed: () async => detectImage(cameraAsSource),
                icon: Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
