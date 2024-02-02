# This example is from https://www.geeksforgeeks.org/detect-an-object-with-opencv-python/
#
#   This code allow detection of stop sign on image, based on Haar Cascade (https://docs.opencv.org/3.4/db/d28/tutorial_cascade_classifier.html) 
#   For interactive execution, which is result showing in a new window, add an argument (anything).
#   Without argument (default), the resulting image is stored in the assets folder.

import cv2
from matplotlib import pyplot as plt
import sys, getopt
import os

# --------------------------------------
# Folder creation and argument parser
# --------------------------------------

if not os.path.exists("assets/"):
    os.makedirs("assets/")

# There is some arguments
inputpath = ''
interactive_mode = False

usage = "Usage: "+sys.argv[0]+" -i <inputpath> [OPTIONS]\n" + "    -m: interractive mode (default: not interractive)."

try:
    opts, args = getopt.getopt(sys.argv[1:],"hmi:",["input="])
except getopt.GetoptError:
    print(usage)
    sys.exit(2)
for opt, arg in opts:
    print("Opt: "+opt)
    print("Arg: "+arg)
    if opt == '-h':
        print(usage)
        sys.exit()
    elif opt in ("-i", "--input"):
        inputpath = arg
        print("Input path: "+inputpath)
    elif opt == '-m':
        interactive_mode = True
    
# -----------------------
# Opening image
# -----------------------

img = cv2.imread(inputpath)

# OpenCV opens images as BRG
# but we want it as RGB and 
# we also need a grayscale 
# version
img_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

# Creates the environment 
# of the picture and shows it
if interactive_mode:
    plt.subplot(1, 1, 1)
    plt.imshow(img_rgb)
    plt.show()

# -----------------------
# Recognition
# -----------------------

# Use minSize because for not 
# bothering with extra-small 
# dots that would look like STOP signs
stop_data = cv2.CascadeClassifier('stop_data.xml')
found = stop_data.detectMultiScale(img_gray, 
								minSize =(20, 20))
# Don't do anything if there's 
# no sign
amount_found = len(found)


if amount_found != 0:
	
	# There may be more than one
	# sign in the image
	for (x, y, width, height) in found:
		
		# We draw a green rectangle around
		# every recognized sign
		cv2.rectangle(img_rgb, (x, y), 
					(x + height, y + width), 
					(0, 255, 0), 5)

# Creates the environment of 
# the picture and shows it
plt.subplot(1, 1, 1)
plt.imshow(img_rgb)
if interactive_mode:
    plt.show()
else:
    outputname =  (inputpath.split('/')[-1]).split('.')[0] + ".png"
    plt.savefig('assets/'+outputname)