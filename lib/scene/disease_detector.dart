import 'dart:io';
import 'dart:typed_data';

import 'package:disease_detect/constants/disease_description.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

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
  String? selectedName;


  void handleSave() async {


    logger.f("Function is called!");

    if (imageBytes.isEmpty) {
      logger.f("No image");
      return;
    }

    // Request storage permission
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      logger.f("Denied");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Storage permission denied."),
          ),
        );
      }
      return;
    }

    // Get downloads directory path
    final directory = Directory(
      '/storage/emulated/0/Download',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath =
        '${directory.path}/disease_image${diseaseName}_$timestamp.png';

    final file = File(filePath);
    await file.writeAsBytes(imageBytes);


    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image saved to Downloads!")),
      );
    }


  }

  Future<void> detectImage(ImageSource sourceOfImage) async {
    setState(() {
      imageBytes = Uint8List(0);
      isInitialStage = false;
      diseaseName = null;
      selectedName = null;
    });
    XFile? image = await imagePicker.pickImage(source: sourceOfImage);
    final interpreter = await Interpreter.fromAsset("assets/keras.tflite");
    final inputShape = interpreter.getInputTensor(0).shape;
    logger.d('Input shape: $inputShape');
    final outputShape = interpreter.getOutputTensor(0).shape;
    logger.d('Output shape: $outputShape');
    logger.d(interpreter.getInputTensors());
    logger.d(interpreter.getOutputTensors());
    if (image != null) {
      final bytes = await image.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return;
      }
      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.cubic,
      );
      setState(() {
        imageBytes = Uint8List.fromList(img.encodePng(resizedImage));
      });

      final inputTensor = List.generate(
        1,
        (_) => List.generate(
          224,
          (_) => List.generate(224, (_) => List.filled(3, 0.0)),
        ),
      );

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          inputTensor[0][y][x][0] = pixel.r / 255.0;
          inputTensor[0][y][x][1] = pixel.g / 255.0;
          inputTensor[0][y][x][2] = pixel.b / 255.0;
        }
      }

      List<List<double>> outputBuffer = List.generate(
        1,
        (_) => List.filled(8, 0.0),
      );
      interpreter.run(inputTensor, outputBuffer);

      List<double> predictions = outputBuffer[0];
      double maxValue = predictions.reduce((a, b) => a > b ? a : b);
      int classIndex = predictions.indexOf(maxValue);

      logger.d(classIndex);
      List<String> classNames = [
        'algal_spot',
        'anthracnose',
        'bird_eye_spot',
        'brown_blight',
        'gray_blight',
        'healthy',
        'red_spot',
        'white_spot',
      ];
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
          title: const SizedBox(height: 0),
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
                shape: const RoundedRectangleBorder(
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
                    padding: const EdgeInsets.all(5),
                    child: IconButton(
                      onPressed: () {
                        context.push("/settings");
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    imageBytes.isNotEmpty
                        ? Container(
                          padding: const EdgeInsets.all(20),
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
                                  ? const CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                  )
                                  : Text(
                                    "Select or Capture an image!",
                                    style: TextStyle(
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.blueAccent,
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
                          color:
                              diseaseName != null
                                  ? Colors.black
                                  : Colors.blueAccent,
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

                            if (disease.isEmpty) {
                              return const SizedBox(height: 0);
                            }

                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    diseaseName!
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "About:",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                  Text(
                                    disease["disease_description"] ??
                                        "No description available",
                                    style: TextStyle(
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Symptoms:",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                  Text(
                                    disease["disease_symptoms"] ??
                                        "No symptoms available",
                                    style: TextStyle(
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Management:",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                  if (disease["management"] != null &&
                                      (disease["management"] as List)
                                          .isNotEmpty)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children:
                                          (disease["management"] as List)
                                              .map(
                                                (m) => Text(
                                                  "• $m",
                                                  style: TextStyle(
                                                    fontFamily:
                                                        GoogleFonts.poppins()
                                                            .fontFamily,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                    )
                                  else
                                    Text(
                                      "Management details will be added soon",
                                      style: TextStyle(
                                        fontFamily:
                                            GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                  const SizedBox(height: 20),

                                  // Dropdown for name selection
                                  Center(
                                    child: DropdownButton<String>(
                                      hint: const Text("Select a name"),
                                      value: selectedName,
                                      items:
                                      ['Ahmed', 'Raisul', 'Usama'].map((
                                          String value,
                                          ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: TextStyle(
                                              fontFamily:
                                              GoogleFonts.poppins()
                                                  .fontFamily,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          selectedName = newValue;
                                        });
                                      },
                                    ),
                                  ),
                                  if (selectedName != null)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          "Tested by: Dr. $selectedName",
                                          style: TextStyle(
                                            fontFamily:
                                            GoogleFonts.poppins().fontFamily,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: diseaseName == null ? SizedBox(height: 0,width: 0,) :Padding(
                  padding: EdgeInsets.all(30),
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Colors.blueAccent,
                      ),
                    ),
                    onPressed: handleSave,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        "Send & Save",
                        style: TextStyle(
                          color: Colors.white,

                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(15),
          margin: const EdgeInsets.all(20),
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
                icon: const Icon(
                  Icons.cloud_upload,
                  color: Colors.white,
                  size: 35,
                ),
              ),
              IconButton(
                onPressed: () async => detectImage(cameraAsSource),
                icon: const Icon(
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
