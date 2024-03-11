from flask import Flask, request, jsonify
import subprocess
import os

app = Flask(__name__)

@app.route('/', methods=['GET'])
def hello():
    return 'Hello, World!\n'

@app.route('/', methods=['POST'])
def process_image():
    try:
        # Receive image from request
        image_file = request.files['image']
        image_path = './tmp/image.bmp'
        image_file.save(image_path)

        # Define command to execute
        command = ['./tflite/label_image',
                   '-m', 'tflite/mobilenet_v1_1.0_224.tflite',
                   '-i', image_path,
                   '-l', 'tflite/labels.txt']

        # Execute the command
        script_response = subprocess.run(command, capture_output=True, text=True)

        # Return script response to client
        return jsonify({'result': script_response.stderr}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Ensure the 'tmp' directory exists
    if not os.path.exists('./tmp'):
        os.makedirs('./tmp')
        
    app.run(host='192.168.88.4', port=5000)
