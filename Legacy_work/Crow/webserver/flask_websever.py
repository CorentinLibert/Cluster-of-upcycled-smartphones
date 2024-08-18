from flask import Flask, request, jsonify, send_file
import os
import time

app = Flask(__name__)

def handle_image(request, file):
    start = time.time_ns()
    try:
        image_file = request.files['image']
        image_file.save(file)
        end = time.time_ns()
        duration = end - start
        print("flask,handling," + str(duration))
        return jsonify({}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
def process_image(in_file, out_file):
    start = time.time_ns()
    input = open(in_file, "rb")
    output = open(out_file, "wb")

    data = input.read()
    while(data):
        output.write(data)
        data = input.read()
    
    input.close()
    output.close()

    end = time.time_ns()
    duration = end - start
    print("flask,processing," + str(duration))

    return jsonify({}), 200

def send_image(file):
    start = time.time_ns()
    if os.path.exists(file):
        res = send_file(file, mimetype='application/octet-stream')
        end = time.time_ns()
        duration = end - start
        print("flask,sending," + str(duration))
        return res 
    else:
        # Handle the case where the image file is not found
        return jsonify({'error': 'Image not found'}), 500



@app.route('/', methods=['GET'])
def hello():
    return 'Hello, World!\n'

@app.route('/object_detection', methods=['POST'])
def object_detection():
    in_file = "data_bitmap.bmp"
    out_file = "res_bitmap.bmp"
    j, code = handle_image(request, in_file)
    if code != 200:
        return j, code
    j, code = process_image(in_file, out_file)
    if code != 200:
        return j, code
    return send_image(out_file)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=18080)
