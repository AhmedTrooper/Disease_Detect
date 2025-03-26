import 'package:flutter/material.dart';
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
  String? diseaseName;
  Future<void> detectImage() async {
    XFile? image = await imagePicker.pickImage(source: ImageSource.gallery);
    final interpreter = await Interpreter.fromAsset("assets/model.tflite");
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
        logger.e("Image decoding failed");
        return;
      }
      // Resize image resolution equal to 640x640
      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: 640,
        height: 640,
        interpolation: img.Interpolation.cubic,
      );
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
        body: CustomScrollView(
          slivers: [
            SliverAppBar(title: Text("Detect Disease")),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: IconButton(
                  onPressed: detectImage,
                  icon: Icon(Icons.upload_file),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Text(
                diseaseName != null
                    ? diseaseName.toString()
                    : "Disease is not detected!",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
